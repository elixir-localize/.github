defmodule ElixirLocalize.Publisher do
  @moduledoc """
  Publishes the built static site to a Cloudflare R2 bucket.

  Uses `Req` as the HTTP transport and `:aws_signature` to generate AWS
  Signature V4 `Authorization` headers. Credentials are read from environment
  variables at call time:

  * `R2_ACCOUNT_ID` — Cloudflare account id (endpoint host prefix)
  * `R2_ACCESS_KEY_ID` — R2 S3-compatible access key
  * `R2_SECRET_ACCESS_KEY` — R2 S3-compatible secret

  The bucket name is configured via `config :elixir_localize, :r2, bucket: …`.

  The sync strategy is:

  1. Walk the local `_site/` tree to build a list of objects.
  2. `ListObjectsV2` on the bucket to build the remote manifest.
  3. PUT any file that is missing remotely or whose content has changed
     (ETag vs local MD5).
  4. DELETE any remote object that no longer exists locally.
  """

  @service "s3"

  @doc """
  Sync `site_dir` to the configured R2 bucket.

  ### Arguments

  * `site_dir` is the directory whose tree will be uploaded. Defaults to
    `"_site"`.

  ### Returns

  * `{:ok, %{uploaded: n, skipped: n, deleted: n}}` on success.

  * `{:error, reason}` if credentials are missing or a request fails.

  """
  @spec sync(Path.t()) :: {:ok, map()} | {:error, term()}
  def sync(site_dir \\ "_site") do
    with {:ok, creds} <- credentials(),
         :ok <- ensure_dir(site_dir),
         {:ok, remote} <- list_remote(creds),
         local = build_local(site_dir) do
      do_sync(creds, site_dir, local, remote)
    end
  end

  defp do_sync(creds, site_dir, local, remote) do
    {to_upload, skipped} =
      Enum.split_with(local, fn {key, path} ->
        case Map.get(remote, key) do
          nil -> true
          etag -> etag != local_etag(path)
        end
      end)

    to_delete =
      remote
      |> Map.keys()
      |> Enum.reject(fn key -> Enum.any?(local, fn {k, _} -> k == key end) end)

    Enum.each(to_upload, fn {key, path} ->
      put_object(creds, key, File.read!(path), content_type(path))
    end)

    Enum.each(to_delete, fn key -> delete_object(creds, key) end)

    local_keys = MapSet.new(local, &elem(&1, 0))
    site_dir_abs = Path.expand(site_dir)

    IO.puts("Published #{length(local)} files from #{site_dir_abs}")

    {:ok,
     %{
       uploaded: length(to_upload),
       skipped: length(skipped),
       deleted: length(to_delete),
       total: MapSet.size(local_keys)
     }}
  end

  # ----- Local tree -------------------------------------------------------

  defp build_local(site_dir) do
    site_dir = Path.expand(site_dir)

    site_dir
    |> ElixirLocalize.Generator.walk_files()
    |> Enum.map(fn path ->
      key = path |> Path.relative_to(site_dir) |> String.replace("\\", "/")
      {key, path}
    end)
  end

  defp local_etag(path) do
    :crypto.hash(:md5, File.read!(path)) |> Base.encode16(case: :lower)
  end

  # ----- Remote manifest --------------------------------------------------

  defp list_remote(creds, continuation_token \\ nil, acc \\ %{}) do
    params =
      [{"list-type", "2"}] ++
        if continuation_token, do: [{"continuation-token", continuation_token}], else: []

    query = URI.encode_query(params)
    url = "#{endpoint(creds)}/?#{query}"

    case signed_request(creds, :get, url, "") do
      {:ok, %{status: 200, body: body}} ->
        {keys, next} = parse_list_v2(body)

        acc =
          Enum.reduce(keys, acc, fn {key, etag}, a -> Map.put(a, key, etag) end)

        case next do
          nil -> {:ok, acc}
          token -> list_remote(creds, token, acc)
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "ListObjectsV2 failed: HTTP #{status} #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_list_v2(body) when is_binary(body) do
    keys =
      Regex.scan(
        ~r|<Contents>.*?<Key>(.*?)</Key>.*?<ETag>"?([^"<]+)"?</ETag>.*?</Contents>|s,
        body
      )
      |> Enum.map(fn [_, k, e] -> {k, String.trim(e, ~s("))} end)

    next =
      case Regex.run(~r|<NextContinuationToken>(.*?)</NextContinuationToken>|, body) do
        [_, token] -> token
        _ -> nil
      end

    {keys, next}
  end

  # ----- Object operations -----------------------------------------------

  defp put_object(creds, key, body, content_type) do
    url = "#{endpoint(creds)}/#{uri_encode_key(key)}"

    case signed_request(creds, :put, url, body, [{"content-type", content_type}]) do
      {:ok, %{status: s}} when s in 200..299 ->
        :ok

      {:ok, %{status: s, body: b}} ->
        raise "PutObject #{key} failed: HTTP #{s} #{b}"

      {:error, reason} ->
        raise "PutObject #{key} failed: #{inspect(reason)}"
    end
  end

  defp delete_object(creds, key) do
    url = "#{endpoint(creds)}/#{uri_encode_key(key)}"

    case signed_request(creds, :delete, url, "") do
      {:ok, %{status: s}} when s in 200..299 ->
        :ok

      {:ok, %{status: s, body: b}} ->
        raise "DeleteObject #{key} failed: HTTP #{s} #{b}"

      {:error, reason} ->
        raise "DeleteObject #{key} failed: #{inspect(reason)}"
    end
  end

  # ----- Signed request ---------------------------------------------------

  defp signed_request(creds, method, url, body, extra_headers \\ []) do
    uri = URI.parse(url)
    host = uri.host

    base_headers =
      [{"host", host}, {"x-amz-content-sha256", sha256_hex(body)}] ++ extra_headers

    method_bin = method |> Atom.to_string() |> String.upcase()

    signed =
      :aws_signature.sign_v4(
        creds.access_key_id,
        creds.secret_access_key,
        creds.region,
        @service,
        :calendar.universal_time(),
        method_bin,
        url,
        Enum.map(base_headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end),
        body,
        []
      )

    headers =
      Enum.map(signed, fn {k, v} ->
        {to_string(k), to_string(v)}
      end)

    Req.request(
      method: method,
      url: url,
      headers: headers,
      body: body,
      decode_body: false,
      retry: false
    )
  end

  defp sha256_hex(body),
    do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)

  defp uri_encode_key(key) do
    key
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end

  # ----- Config -----------------------------------------------------------

  defp credentials do
    r2 = Application.fetch_env!(:elixir_localize, :r2)

    with {:ok, account} <- fetch_env("R2_ACCOUNT_ID"),
         {:ok, access} <- fetch_env("R2_ACCESS_KEY_ID"),
         {:ok, secret} <- fetch_env("R2_SECRET_ACCESS_KEY") do
      {:ok,
       %{
         account_id: account,
         access_key_id: access,
         secret_access_key: secret,
         bucket: Keyword.fetch!(r2, :bucket),
         region: Keyword.get(r2, :region, "auto")
       }}
    end
  end

  defp fetch_env(name) do
    case System.get_env(name) do
      nil -> {:error, "Environment variable #{name} is not set"}
      "" -> {:error, "Environment variable #{name} is empty"}
      value -> {:ok, value}
    end
  end

  defp endpoint(creds) do
    "https://#{creds.account_id}.r2.cloudflarestorage.com/#{creds.bucket}"
  end

  defp ensure_dir(dir) do
    if File.dir?(dir), do: :ok, else: {:error, "#{dir} does not exist — run mix blog.build first"}
  end

  # ----- Content type lookup ---------------------------------------------

  @content_types %{
    ".html" => "text/html; charset=utf-8",
    ".htm" => "text/html; charset=utf-8",
    ".css" => "text/css; charset=utf-8",
    ".js" => "application/javascript; charset=utf-8",
    ".json" => "application/json",
    ".xml" => "application/rss+xml; charset=utf-8",
    ".txt" => "text/plain; charset=utf-8",
    ".svg" => "image/svg+xml",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".webp" => "image/webp",
    ".ico" => "image/x-icon",
    ".woff" => "font/woff",
    ".woff2" => "font/woff2"
  }

  @doc false
  def content_type(path) do
    ext = path |> Path.extname() |> String.downcase()
    Map.get(@content_types, ext, "application/octet-stream")
  end
end
