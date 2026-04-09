defmodule ElixirLocalize.Web.Router do
  @moduledoc """
  HTTP router for the Micropub editing server.

  Exposes:

  * `GET /micropub` — Micropub query endpoint (`?q=config`, `?q=source`).
  * `POST /micropub` — Micropub create / update / delete endpoint.
  * `GET /` — a tiny status page so humans hitting the URL get useful output.

  All `/micropub` routes require bearer-token authentication through
  `ElixirLocalize.Web.Auth`. The status page is unauthenticated.

  Static site preview is still provided by the separate `mix blog.serve`
  task; this server is dedicated to editing.
  """

  use Plug.Router

  alias ElixirLocalize.{Generator, Micropub, RuntimePosts}

  plug(Plug.Logger, log: :info)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: 16_000_000
  )

  plug(:match)
  plug(:dispatch)

  # ------------------------------------------------------------------
  # Status page
  # ------------------------------------------------------------------

  get "/favicon.svg" do
    send_favicon(conn, "image/svg+xml")
  end

  get "/favicon.ico" do
    send_favicon(conn, "image/svg+xml")
  end

  get "/" do
    send_discovery_page(conn)
  end

  # MarsEdit and other clients sometimes probe well-known paths. Answer
  # them all with the same discovery page so the `<link rel="micropub">`
  # and `Link` header are always findable.
  get "/index.html" do
    send_discovery_page(conn)
  end

  # ------------------------------------------------------------------
  # Micropub query endpoint
  # ------------------------------------------------------------------

  get "/micropub" do
    with_auth(conn, fn authed ->
      case authed.params["q"] do
        "config" ->
          json(authed, 200, %{"syndicate-to" => []})

        "source" ->
          handle_source(authed)

        _ ->
          json(authed, 400, %{"error" => "invalid_request"})
      end
    end)
  end

  # ------------------------------------------------------------------
  # Micropub create / update / delete
  # ------------------------------------------------------------------

  post "/micropub" do
    if xml_rpc?(conn) do
      handle_xmlrpc(conn)
    else
      with_auth(conn, fn authed ->
        case authed.params do
          %{"action" => "delete", "url" => url} ->
            handle_delete(authed, url)

          %{"action" => "update"} = params ->
            handle_update(authed, params)

          _ ->
            handle_create(authed, authed.params)
        end
      end)
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  # ------------------------------------------------------------------
  # Handlers
  # ------------------------------------------------------------------

  defp handle_create(conn, params) do
    properties = Micropub.properties_from_params(params)

    case Micropub.create(properties) do
      {:ok, url} ->
        rebuild!()

        conn
        |> put_resp_header("location", url)
        |> send_resp(201, "")

      {:error, :title_required} ->
        json(conn, 400, %{"error" => "invalid_request", "error_description" => "name is required"})

      {:error, :content_required} ->
        json(conn, 400, %{
          "error" => "invalid_request",
          "error_description" => "content is required"
        })
    end
  end

  defp handle_update(conn, params) do
    url = params["url"]
    replace = Map.get(params, "replace", %{}) |> ensure_map()
    add = Map.get(params, "add", %{}) |> ensure_map()
    delete_properties = Map.get(params, "delete", %{})

    case Micropub.update(url, replace, add, delete_properties) do
      {:ok, updated_url} ->
        rebuild!()

        conn
        |> put_resp_header("location", updated_url)
        |> send_resp(200, "")

      {:error, :not_found} ->
        json(conn, 404, %{"error" => "not_found"})

      {:error, :invalid_url} ->
        json(conn, 400, %{"error" => "invalid_request", "error_description" => "bad url"})
    end
  end

  defp handle_delete(conn, url) do
    case Micropub.delete(url) do
      :ok ->
        rebuild!()
        send_resp(conn, 204, "")

      {:error, :not_found} ->
        json(conn, 404, %{"error" => "not_found"})

      {:error, :invalid_url} ->
        json(conn, 400, %{"error" => "invalid_request"})
    end
  end

  defp handle_source(conn) do
    url = conn.params["url"]
    requested = List.wrap(conn.params["properties"])

    case Micropub.source(url, requested) do
      {:ok, mf2} -> json(conn, 200, mf2)
      {:error, :not_found} -> json(conn, 404, %{"error" => "not_found"})
      {:error, :invalid_url} -> json(conn, 400, %{"error" => "invalid_request"})
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  # ------------------------------------------------------------------
  # XML-RPC (MarsEdit read path)
  # ------------------------------------------------------------------

  defp xml_rpc?(conn) do
    case get_req_header(conn, "content-type") do
      [content_type | _] ->
        content_type = String.downcase(content_type)

        String.starts_with?(content_type, "text/xml") or
          String.starts_with?(content_type, "application/xml")

      _ ->
        false
    end
  end

  defp handle_xmlrpc(conn) do
    case check_basic_auth(conn) do
      :ok ->
        {:ok, body, conn} = Plug.Conn.read_body(conn, length: 16_000_000)

        case XMLRPC.decode(body) do
          {:ok, %XMLRPC.MethodCall{method_name: method, params: params}} ->
            send_xmlrpc_response(conn, ElixirLocalize.Web.XmlRpc.dispatch(method, params))

          {:error, reason} ->
            send_xmlrpc_fault(conn, -32700, "Parse error: #{inspect(reason)}")
        end

      :unauthorized ->
        conn
        |> put_resp_header("www-authenticate", ~s(Basic realm="Localize Blog"))
        |> send_resp(401, "Unauthorized")
    end
  end

  defp send_xmlrpc_response(conn, {:ok, value}) do
    xml = XMLRPC.encode!(%XMLRPC.MethodResponse{param: value})

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, xml)
  end

  defp send_xmlrpc_response(conn, {:fault, code, message}) do
    send_xmlrpc_fault(conn, code, message)
  end

  defp send_xmlrpc_fault(conn, code, message) do
    xml = XMLRPC.encode!(%XMLRPC.Fault{fault_code: code, fault_string: message})

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, xml)
  end

  defp check_basic_auth(conn) do
    expected = System.get_env("LOCALIZE_BLOG_TOKEN")

    with ["Basic " <> encoded | _] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         [_username, password] <- String.split(decoded, ":", parts: 2),
         true <- is_binary(expected) and expected != "" and password == expected do
      :ok
    else
      _ -> :unauthorized
    end
  end

  defp send_discovery_page(conn) do
    site = ElixirLocalize.site_config()
    base = request_base_url(conn)
    micropub_url = base <> "/micropub"

    html = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>#{site[:title]} — Micropub editing server</title>
        <meta name="description" content="Micropub editing endpoint for the #{site[:title]} blog." />
        <link rel="micropub" href="#{micropub_url}" />
        <link rel="alternate" type="application/rss+xml" title="#{site[:title]} — RSS" href="#{site[:base_url]}/feed.xml" />
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
      </head>
      <body>
        <h1>#{site[:title]} — Micropub editing server</h1>
        <p>This server exposes a <a href="https://micropub.spec.indieweb.org/">Micropub</a> endpoint for editing the <strong>#{site[:title]}</strong> blog from clients such as MarsEdit and micro.blog.</p>
        <h2>Endpoint</h2>
        <p><code>#{micropub_url}</code></p>
        <h2>Authentication</h2>
        <p>Bearer token in the <code>Authorization</code> header. The expected token is the value of the <code>LOCALIZE_BLOG_TOKEN</code> environment variable on the server.</p>
        <h2>Autodiscovery</h2>
        <p>This page advertises the Micropub endpoint via a <code>&lt;link rel="micropub"&gt;</code> element and an <code>HTTP Link</code> header. Point MarsEdit (or any other Micropub client) at this URL and it should detect the endpoint automatically.</p>
      </body>
    </html>
    """

    conn
    |> put_resp_header("link", ~s(<#{micropub_url}>; rel="micropub"))
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp request_base_url(conn) do
    scheme = to_string(conn.scheme)

    host =
      case Plug.Conn.get_req_header(conn, "host") do
        [value | _] -> value
        _ -> "#{conn.host}:#{conn.port}"
      end

    "#{scheme}://#{host}"
  end

  defp send_favicon(conn, content_type) do
    path = Application.app_dir(:elixir_localize, "priv/static/favicon.svg")

    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> send_file(200, path)
  end

  defp with_auth(conn, continuation) do
    authed = ElixirLocalize.Web.Auth.call(conn, [])
    if authed.halted, do: authed, else: continuation.(authed)
  end

  defp rebuild! do
    posts = RuntimePosts.all()
    output = Path.expand("_site")
    {:ok, _} = Generator.build(output, posts)
    :ok
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode_to_iodata!(body))
  end

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}
end
