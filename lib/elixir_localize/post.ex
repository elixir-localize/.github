defmodule ElixirLocalize.Post do
  @moduledoc """
  A blog post parsed by `NimblePublisher` from a markdown file in `priv/posts/`.

  The filename must follow the pattern `YYYY-MM-DD-slug.md`. The date and slug
  are derived from the filename; all other fields come from the `%{…}`
  frontmatter map and the markdown body.
  """

  @enforce_keys [:id, :author, :title, :body, :description, :tags, :date, :slug, :summary]
  defstruct [:id, :author, :title, :body, :description, :tags, :date, :slug, :summary]

  @type t :: %__MODULE__{
          id: String.t(),
          author: String.t(),
          title: String.t(),
          body: String.t(),
          description: String.t() | nil,
          tags: [String.t()],
          date: Date.t(),
          slug: String.t(),
          summary: String.t()
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

    %__MODULE__{
      id: slug,
      slug: slug,
      date: date,
      title: Map.fetch!(attrs, :title),
      author: Map.get(attrs, :author, "Kip Cole"),
      description: Map.get(attrs, :description),
      tags: Map.get(attrs, :tags, []),
      body: body,
      summary: extract_summary(attrs, body)
    }
  end

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
