defmodule ElixirLocalize.Post do
  @moduledoc """
  A blog post parsed by `NimblePublisher` from a markdown file in `priv/posts/`.

  The filename must follow the pattern `YYYY-MM-DD-slug.md`. The date and slug
  are derived from the filename; all other fields come from the `%{…}`
  frontmatter map and the markdown body.
  """

  @enforce_keys [
    :id,
    :author,
    :title,
    :body,
    :description,
    :tags,
    :date,
    :slug,
    :summary,
    :status,
    :published_at,
    :updated_at
  ]
  defstruct [
    :id,
    :author,
    :title,
    :body,
    :description,
    :tags,
    :date,
    :slug,
    :summary,
    :status,
    :published_at,
    :updated_at
  ]

  @type status :: :published | :draft

  @type t :: %__MODULE__{
          id: String.t(),
          author: String.t(),
          title: String.t(),
          body: String.t(),
          description: String.t() | nil,
          tags: [String.t()],
          date: Date.t(),
          slug: String.t(),
          summary: String.t(),
          status: status(),
          published_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Build a post struct from a filename and parsed `NimblePublisher` attributes.

  ### Arguments

  * `filename` is the absolute path to the markdown file.

  * `attrs` is a map of the frontmatter attributes extracted by
    `NimblePublisher`.

  * `body` is the HTML body rendered from the markdown source.

  ### Returns

  * An `%ElixirLocalize.Post{}` struct.

  """
  def build(filename, attrs, body) do
    {date, slug} = parse_filename(filename)

    published_at =
      case Map.get(attrs, :published) do
        nil -> default_published(date)
        value -> parse_datetime!(value)
      end

    updated_at =
      case Map.get(attrs, :updated) do
        nil -> published_at
        value -> parse_datetime!(value)
      end

    %__MODULE__{
      id: slug,
      slug: slug,
      date: date,
      title: Map.fetch!(attrs, :title),
      author: Map.get(attrs, :author, "Kip Cole"),
      description: Map.get(attrs, :description),
      tags: Map.get(attrs, :tags, []),
      body: body,
      summary: extract_summary(attrs, body),
      status: normalize_status(Map.get(attrs, :status)),
      published_at: published_at,
      updated_at: updated_at
    }
  end

  defp default_published(date) do
    {:ok, datetime} = DateTime.new(date, ~T[12:00:00], "Etc/UTC")
    datetime
  end

  @doc """
  Parse an ISO 8601 datetime string or pass through an existing
  `DateTime`. Returns `{:ok, DateTime.t()}` on success, `:error`
  on unparseable input.
  """
  @spec parse_datetime(String.t() | DateTime.t()) :: {:ok, DateTime.t()} | :error
  def parse_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  def parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      _ ->
        case Date.from_iso8601(string) do
          {:ok, date} ->
            {:ok, datetime} = DateTime.new(date, ~T[12:00:00], "Etc/UTC")
            {:ok, datetime}

          _ ->
            :error
        end
    end
  end

  def parse_datetime(_), do: :error

  @doc """
  Like `parse_datetime/1` but raises `ArgumentError` on invalid input.
  """
  @spec parse_datetime!(String.t() | DateTime.t()) :: DateTime.t()
  def parse_datetime!(value) do
    case parse_datetime(value) do
      {:ok, datetime} -> datetime
      :error -> raise ArgumentError, "Cannot parse datetime: #{inspect(value)}"
    end
  end

  @doc """
  Return a URL-safe slug for a tag name. Used to build category page URLs.

  ### Arguments

  * `tag` is the raw tag string as it appears in frontmatter.

  ### Returns

  * A lowercase, dash-separated slug suitable for a URL path segment.

  ### Examples

      iex> ElixirLocalize.Post.tag_slug("localize")
      "localize"

      iex> ElixirLocalize.Post.tag_slug("ex_cldr")
      "ex-cldr"

      iex> ElixirLocalize.Post.tag_slug("Release Notes!")
      "release-notes"

  """
  @spec tag_slug(String.t()) :: String.t()
  def tag_slug(tag) when is_binary(tag) do
    tag
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  @doc """
  Normalize a free-form status value into one of the two atoms
  `:published` or `:draft`.

  Accepts atoms, binaries, and `nil`. Any value other than a recognized
  draft marker is treated as `:published`.
  """
  @spec normalize_status(any()) :: status()
  def normalize_status(:draft), do: :draft
  def normalize_status("draft"), do: :draft
  def normalize_status(:published), do: :published
  def normalize_status("published"), do: :published
  def normalize_status("publish"), do: :published
  def normalize_status(nil), do: :published
  def normalize_status(_), do: :published

  defp parse_filename(filename) do
    base = Path.basename(filename, ".md")

    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})-(.+)$/, base) do
      [_, date_string, slug] ->
        {Date.from_iso8601!(date_string), slug}

      _ ->
        raise ArgumentError,
              "Post filename #{inspect(base)} must match YYYY-MM-DD-slug.md"
    end
  end

  @doc false
  def extract_summary(attrs, body) do
    cond do
      summary = Map.get(attrs, :description) -> summary
      true -> first_paragraph_text(body)
    end
  end

  defp first_paragraph_text(html) do
    case Regex.run(~r/<p>(.*?)<\/p>/s, html) do
      [_, inner] -> inner |> strip_tags() |> collapse_whitespace()
      _ -> ""
    end
  end

  defp strip_tags(html), do: Regex.replace(~r/<[^>]+>/, html, "")

  defp collapse_whitespace(string) do
    string
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
