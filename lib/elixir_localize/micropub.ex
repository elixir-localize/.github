defmodule ElixirLocalize.Micropub do
  @moduledoc """
  Business logic for the Micropub endpoint.

  Handles the three directions the protocol needs to flow:

  * `properties_from_params/1` — parse an incoming create request (either a
    JSON Micropub object or a form-encoded payload) into a normalized map of
    post properties.
  * `create/1` — turn normalized properties into a markdown file on disk,
    returning the canonical URL of the new post.
  * `update/3` and `delete/1` — mutate an existing post addressed by its URL.
  * `source/2` — serialise a post back into MF2 JSON for editing clients.

  File I/O happens in `ElixirLocalize.RuntimePosts`. The controller is
  responsible for authentication, response encoding, and triggering a rebuild.
  """

  alias ElixirLocalize.RuntimePosts

  @type properties :: %{
          optional(:title) => String.t(),
          optional(:content) => String.t(),
          optional(:tags) => [String.t()],
          optional(:date) => Date.t(),
          optional(:slug) => String.t(),
          optional(:author) => String.t(),
          optional(:description) => String.t()
        }

  # ------------------------------------------------------------------
  # Parsing
  # ------------------------------------------------------------------

  @doc """
  Normalize an incoming create request into a `t:properties/0` map.

  Handles both JSON-encoded Micropub payloads (where properties live under a
  `"properties"` key and values are arrays) and form-encoded payloads (where
  values are scalars or repeated keys).

  ### Arguments

  * `params` is the decoded request body as a map.

  ### Returns

  * A normalized `t:properties/0` map.

  """
  @spec properties_from_params(map()) :: properties()
  def properties_from_params(%{"properties" => properties} = _json) when is_map(properties) do
    %{}
    |> put_if(:title, first(properties["name"]))
    |> put_if(:content, content_from_json(properties["content"]))
    |> put_if(:tags, list_of_strings(properties["category"]))
    |> put_if(:date, parse_date(first(properties["published"])))
    |> put_if(:slug, first(properties["mp-slug"]) || first(properties["slug"]))
    |> put_if(:author, first(properties["author"]))
    |> put_if(:description, first(properties["summary"]))
    |> put_if(:status, parse_status(first(properties["post-status"])))
  end

  def properties_from_params(form) when is_map(form) do
    %{}
    |> put_if(:title, form["name"])
    |> put_if(:content, form["content"])
    |> put_if(:tags, list_of_strings(form["category"] || form["category[]"]))
    |> put_if(:date, parse_date(form["published"]))
    |> put_if(:slug, form["mp-slug"] || form["slug"])
    |> put_if(:author, form["author"])
    |> put_if(:description, form["summary"])
    |> put_if(:status, parse_status(form["post-status"]))
  end

  defp parse_status("draft"), do: :draft
  defp parse_status("published"), do: :published
  defp parse_status("publish"), do: :published
  defp parse_status(_), do: nil

  # ------------------------------------------------------------------
  # Create / Update / Delete
  # ------------------------------------------------------------------

  @doc """
  Create a new post from a normalized `t:properties/0` map.

  Generates a slug from the title if none was provided, and uses today's date
  if no `:date` is given. Writes a markdown file to `priv/posts/` and returns
  the canonical public URL of the new post.

  ### Arguments

  * `properties` is the normalized property map from `properties_from_params/1`.

  ### Returns

  * `{:ok, url}` where `url` is the canonical URL on the configured site.

  * `{:error, reason}` if required fields are missing.

  """
  @spec create(properties()) :: {:ok, String.t()} | {:error, atom()}
  def create(properties) do
    with {:ok, content} <- fetch(properties, :content, :content_required) do
      title = Map.get(properties, :title) || title_from_content(content)
      date = Map.get(properties, :date, Date.utc_today())
      slug = Map.get(properties, :slug) || slugify(title)

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      published_at = Map.get(properties, :published_at, now)
      updated_at = Map.get(properties, :updated_at, published_at)

      attrs = %{
        title: title,
        author: Map.get(properties, :author, default_author()),
        tags: Map.get(properties, :tags, []),
        description: Map.get(properties, :description),
        status: Map.get(properties, :status, :published),
        published_at: published_at,
        updated_at: updated_at
      }

      path = file_path(date, slug)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, serialize(attrs, content))

      {:ok, url_for(slug)}
    end
  end

  @doc """
  Update an existing post, identified by its canonical URL.

  Applies the `replace`, `add`, and `delete` actions from a Micropub update
  request. Only the `name`, `content`, `category`, and `summary` properties are
  supported — other properties are silently ignored.

  ### Arguments

  * `url` is the canonical URL of the post to edit.

  * `replace` is a map of property → replacement values.

  * `add` is a map of property → values to append to the existing list.

  * `delete_properties` is either a list of property names to clear entirely,
    or a map of property → values to remove from the existing list.

  ### Returns

  * `{:ok, url}` on success.

  * `{:error, :not_found}` if no post exists at that URL.

  """
  @spec update(String.t(), map(), map(), list() | map()) ::
          {:ok, String.t()} | {:error, atom()}
  def update(url, replace \\ %{}, add \\ %{}, delete_properties \\ %{}) do
    with {:ok, slug} <- slug_from_url(url),
         {:ok, path} <- path_for_slug(slug),
         {:ok, attrs, body} <- read_source(path) do
      {attrs, body} =
        {attrs, body}
        |> apply_replace(replace)
        |> apply_add(add)
        |> apply_delete(delete_properties)

      attrs = Map.put(attrs, :updated_at, DateTime.utc_now() |> DateTime.truncate(:second))

      File.write!(path, serialize(attrs, body))
      {:ok, url_for(slug)}
    end
  end

  @doc """
  Delete the post at the given canonical URL.

  ### Arguments

  * `url` is the canonical URL of the post to remove.

  ### Returns

  * `:ok` on success.

  * `{:error, :not_found}` if no post exists at that URL.

  """
  @spec delete(String.t()) :: :ok | {:error, atom()}
  def delete(url) do
    with {:ok, slug} <- slug_from_url(url),
         {:ok, path} <- path_for_slug(slug) do
      File.rm!(path)
      :ok
    end
  end

  @doc """
  Return the MF2 JSON representation of a post for a Micropub source query.

  ### Arguments

  * `url` is the canonical URL of the post to fetch.

  * `requested_properties` is an optional list of property names to include.
    When empty, all known properties are returned.

  ### Returns

  * `{:ok, mf2}` on success where `mf2` is a map ready to be encoded as JSON.

  * `{:error, :not_found}` if no post exists at that URL.

  """
  @spec source(String.t(), [String.t()]) :: {:ok, map()} | {:error, atom()}
  def source(url, requested_properties \\ []) do
    with {:ok, slug} <- slug_from_url(url),
         {:ok, path} <- path_for_slug(slug),
         {:ok, attrs, body} <- read_source(path) do
      all = %{
        "name" => [attrs.title],
        "content" => [body],
        "category" => attrs[:tags] || [],
        "published" => [Date.to_iso8601(date_from_path(path))],
        "author" => [attrs[:author] || default_author()],
        "summary" => maybe_list(attrs[:description]),
        "url" => [url_for(slug)]
      }

      properties =
        case requested_properties do
          [] -> all
          requested -> Map.take(all, requested)
        end

      {:ok, %{"type" => ["h-entry"], "properties" => properties}}
    end
  end

  # ------------------------------------------------------------------
  # URL / slug helpers
  # ------------------------------------------------------------------

  @doc """
  Extract the blog post slug from a canonical post URL.

  ### Arguments

  * `url` is a URL of the form `<base>/posts/<slug>/` (trailing slash optional).

  ### Returns

  * `{:ok, slug}` if the URL matches the expected shape.

  * `{:error, :invalid_url}` otherwise.

  """
  @spec slug_from_url(String.t()) :: {:ok, String.t()} | {:error, :invalid_url}
  def slug_from_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) ->
        case Regex.run(~r|/posts/([^/]+)/?$|, path) do
          [_, slug] -> {:ok, slug}
          _ -> {:error, :invalid_url}
        end

      _ ->
        {:error, :invalid_url}
    end
  end

  def slug_from_url(_), do: {:error, :invalid_url}

  @doc """
  Build the canonical URL for a post slug using the configured base URL.

  ### Arguments

  * `slug` is the post slug.

  ### Returns

  * The absolute URL string.

  """
  @spec url_for(String.t()) :: String.t()
  def url_for(slug) do
    base = ElixirLocalize.site_config()[:base_url] |> String.trim_trailing("/")
    base <> "/posts/" <> slug <> "/"
  end

  @doc """
  Convert a title into a URL-safe slug.

  ### Arguments

  * `title` is the post title.

  ### Returns

  * A lowercase, dash-separated slug string.

  """
  @spec slugify(String.t()) :: String.t()
  def slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "post-#{System.system_time(:second)}"
      other -> other
    end
  end

  # ------------------------------------------------------------------
  # Serialization
  # ------------------------------------------------------------------

  @doc """
  Serialize post attributes and body back to the `%{...}---body` file format
  that `NimblePublisher` and `RuntimePosts` parse.

  ### Arguments

  * `attrs` is a map with `:title`, `:author`, `:tags`, and `:description`.

  * `body` is the markdown body string.

  ### Returns

  * A binary ready to be written to disk.

  """
  @spec serialize(map(), String.t()) :: String.t()
  def serialize(attrs, body) do
    status_line =
      case attrs[:status] do
        :draft -> ",\n  status: \"draft\""
        "draft" -> ",\n  status: \"draft\""
        _ -> ""
      end

    published_line =
      case attrs[:published_at] do
        %DateTime{} = dt -> ",\n  published: #{inspect(DateTime.to_iso8601(dt))}"
        _ -> ""
      end

    updated_line =
      case attrs[:updated_at] do
        %DateTime{} = dt -> ",\n  updated: #{inspect(DateTime.to_iso8601(dt))}"
        _ -> ""
      end

    meta = """
    %{
      title: #{inspect(attrs.title)},
      author: #{inspect(attrs[:author] || default_author())},
      tags: #{inspect(attrs[:tags] || [])},
      description: #{inspect(attrs[:description])}#{status_line}#{published_line}#{updated_line}
    }
    """

    meta <> "---\n" <> ensure_trailing_newline(body)
  end

  defp ensure_trailing_newline(body) do
    if String.ends_with?(body, "\n"), do: body, else: body <> "\n"
  end

  # ------------------------------------------------------------------
  # Private helpers
  # ------------------------------------------------------------------

  defp read_source(path) do
    source = File.read!(path)

    case String.split(source, ~r/\n---\n/, parts: 2) do
      [meta_string, body] ->
        {raw_attrs, _binding} = Code.eval_string(meta_string)
        {:ok, normalize_attrs(raw_attrs), body}

      _ ->
        {:error, :corrupt_post}
    end
  end

  # The frontmatter uses short keys (`published`, `updated`) but the
  # serializer writes from long keys (`published_at`, `updated_at`), which
  # is also the internal representation on the `Post` struct. Normalize
  # here so the rest of the update pipeline only has to deal with one
  # form. Any unrecognized keys pass through unchanged.
  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.put_new_lazy(:published_at, fn -> lift_datetime(attrs, :published) end)
    |> Map.put_new_lazy(:updated_at, fn -> lift_datetime(attrs, :updated) end)
    |> Map.drop([:published, :updated])
  end

  defp lift_datetime(attrs, key) do
    case Map.get(attrs, key) do
      nil ->
        nil

      value ->
        case ElixirLocalize.Post.parse_datetime(value) do
          {:ok, datetime} -> datetime
          :error -> nil
        end
    end
  end

  defp path_for_slug(slug) do
    case RuntimePosts.path_for_slug(slug) do
      nil -> {:error, :not_found}
      path -> {:ok, path}
    end
  end

  defp file_path(date, slug) do
    filename = "#{Date.to_iso8601(date)}-#{slug}.md"
    Path.join(RuntimePosts.posts_dir(), filename)
  end

  defp date_from_path(path) do
    base = Path.basename(path, ".md")
    [_, date_string, _] = Regex.run(~r/^(\d{4}-\d{2}-\d{2})-(.+)$/, base)
    Date.from_iso8601!(date_string)
  end

  # ------------------------------------------------------------------
  # Update helpers
  # ------------------------------------------------------------------

  @property_to_attr %{
    "name" => :title,
    "summary" => :description,
    "category" => :tags,
    "author" => :author
  }

  defp apply_replace({attrs, body}, replace) when is_map(replace) do
    Enum.reduce(replace, {attrs, body}, fn
      {"content", values}, {a, _b} -> {a, content_from_json(values)}
      {"post-status", values}, {a, b} -> {put_status(a, first(values)), b}
      {"published", values}, {a, b} -> {put_published_at(a, first(values)), b}
      {property, values}, {a, b} -> {put_attr(a, property, values), b}
    end)
  end

  defp apply_replace(state, _), do: state

  defp put_published_at(attrs, nil), do: attrs

  defp put_published_at(attrs, value) do
    case ElixirLocalize.Post.parse_datetime(value) do
      {:ok, datetime} -> Map.put(attrs, :published_at, datetime)
      :error -> attrs
    end
  end

  defp put_status(attrs, "draft"), do: Map.put(attrs, :status, :draft)
  defp put_status(attrs, "published"), do: Map.put(attrs, :status, :published)
  defp put_status(attrs, "publish"), do: Map.put(attrs, :status, :published)
  defp put_status(attrs, _), do: attrs

  defp apply_add({attrs, body}, add) when is_map(add) do
    Enum.reduce(add, {attrs, body}, fn
      {"category", values}, {a, b} ->
        existing = a[:tags] || []
        {Map.put(a, :tags, existing ++ list_of_strings(values)), b}

      _, state ->
        state
    end)
  end

  defp apply_add(state, _), do: state

  defp apply_delete({attrs, body}, delete_properties) when is_list(delete_properties) do
    attrs =
      Enum.reduce(delete_properties, attrs, fn property, acc ->
        case Map.fetch(@property_to_attr, property) do
          {:ok, attr} -> Map.put(acc, attr, empty_value(attr))
          :error -> acc
        end
      end)

    {attrs, body}
  end

  defp apply_delete({attrs, body}, delete_properties) when is_map(delete_properties) do
    attrs =
      Enum.reduce(delete_properties, attrs, fn
        {"category", values}, acc ->
          existing = acc[:tags] || []
          Map.put(acc, :tags, existing -- list_of_strings(values))

        _, acc ->
          acc
      end)

    {attrs, body}
  end

  defp apply_delete(state, _), do: state

  defp put_attr(attrs, property, values) do
    case Map.fetch(@property_to_attr, property) do
      {:ok, :tags} -> Map.put(attrs, :tags, list_of_strings(values))
      {:ok, attr} -> Map.put(attrs, attr, first(values))
      :error -> attrs
    end
  end

  defp empty_value(:tags), do: []
  defp empty_value(_), do: nil

  # ------------------------------------------------------------------
  # Coercion helpers
  # ------------------------------------------------------------------

  defp first(nil), do: nil
  defp first([]), do: nil
  defp first([first | _]), do: first
  defp first(other) when is_binary(other), do: other
  defp first(_), do: nil

  defp list_of_strings(nil), do: []
  defp list_of_strings(value) when is_binary(value), do: [value]

  defp list_of_strings(values) when is_list(values),
    do: Enum.filter(values, &is_binary/1)

  defp list_of_strings(_), do: []

  defp content_from_json(nil), do: nil
  defp content_from_json(value) when is_binary(value), do: value
  defp content_from_json([first | _]), do: content_from_json(first)
  defp content_from_json(%{"markdown" => markdown}) when is_binary(markdown), do: markdown
  defp content_from_json(%{"html" => html}) when is_binary(html), do: html
  defp content_from_json(_), do: nil

  defp parse_date(nil), do: nil

  defp parse_date(string) when is_binary(string) do
    case Date.from_iso8601(string) do
      {:ok, date} ->
        date

      _ ->
        case DateTime.from_iso8601(string) do
          {:ok, dt, _} -> DateTime.to_date(dt)
          _ -> nil
        end
    end
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, _key, []), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp fetch(map, key, error) do
    case Map.fetch(map, key) do
      {:ok, value} when value != nil -> {:ok, value}
      _ -> {:error, error}
    end
  end

  defp maybe_list(nil), do: []
  defp maybe_list(value), do: [value]

  defp title_from_content(content) when is_binary(content) do
    content
    |> String.replace(~r/[#*`\[\]]+/, "")
    |> String.split(~r/[\n.!?]/, parts: 2, trim: true)
    |> List.first("")
    |> String.trim()
    |> String.slice(0, 80)
    |> case do
      "" -> "Post #{Date.to_iso8601(Date.utc_today())}"
      title -> title
    end
  end

  defp default_author do
    ElixirLocalize.site_config()[:author] || "Kip Cole"
  end
end
