defmodule ElixirLocalize.RuntimePosts do
  @moduledoc """
  Reads blog posts from disk at runtime.

  The compile-time `ElixirLocalize` module loads posts through `NimblePublisher`,
  which is the right choice for the static build (`mix blog.build`). When posts
  are created, updated, or deleted through the Micropub endpoint, the process
  is long-running and needs to see file-system changes immediately.

  This module reads `priv/posts/**/*.md` from disk on every call, parses the
  frontmatter map and markdown body, and returns a list of
  `ElixirLocalize.Post` structs. There is no cache — each call re-reads.
  """

  alias ElixirLocalize.Post

  @doc """
  Return all posts found under `priv/posts/`, sorted newest-first.

  ### Returns

  * A list of `t:ElixirLocalize.Post.t/0` structs sorted by `:date` descending.

  """
  @spec all() :: [Post.t()]
  def all do
    posts_dir()
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.map(&read_post!/1)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  @doc """
  Load a single post by its slug.

  ### Arguments

  * `slug` is the URL slug portion of the post filename.

  ### Returns

  * The matching `t:ElixirLocalize.Post.t/0`, or `nil` if no post has that slug.

  """
  @spec by_slug(String.t()) :: Post.t() | nil
  def by_slug(slug) do
    case find_file_for_slug(slug) do
      nil -> nil
      path -> read_post!(path)
    end
  end

  @doc """
  Return the absolute path to the markdown file backing a given slug, or `nil`.

  ### Arguments

  * `slug` is the URL slug portion of the post filename.

  ### Returns

  * An absolute path string, or `nil` if no file exists for that slug.

  """
  @spec path_for_slug(String.t()) :: Path.t() | nil
  def path_for_slug(slug), do: find_file_for_slug(slug)

  @doc """
  Return the raw markdown body of the post with the given slug, without
  frontmatter.

  ### Arguments

  * `slug` is the URL slug portion of the post filename.

  ### Returns

  * The markdown body as a string, or `nil` if no post has that slug.

  """
  @spec markdown_body(String.t()) :: String.t() | nil
  def markdown_body(slug) do
    with path when is_binary(path) <- find_file_for_slug(slug),
         {:ok, source} <- File.read(path),
         [_meta, body] <- String.split(source, ~r/\n---\n/, parts: 2) do
      body
    else
      _ -> nil
    end
  end

  @doc """
  Return the absolute path to the `priv/posts/` directory.

  ### Returns

  * An absolute path string.

  """
  @spec posts_dir() :: Path.t()
  def posts_dir do
    Application.app_dir(:elixir_localize, "priv/posts")
  end

  defp find_file_for_slug(slug) do
    posts_dir()
    |> Path.join("**/*-#{slug}.md")
    |> Path.wildcard()
    |> List.first()
  end

  defp read_post!(path) do
    source = File.read!(path)
    {attrs, markdown} = split_frontmatter!(source, path)

    html =
      markdown
      |> Earmark.as_html!(compact_output: true)
      |> NimblePublisher.Highlighter.highlight()
      |> strip_nondeterministic_attrs()

    Post.build(path, attrs, html)
  end

  # Makeup stamps each bracket pair with a random `data-group-id` so that
  # hover-to-match can pair them up in a browser. The value is regenerated
  # on every call, which makes the rendered body non-deterministic — a
  # problem for clients like MarsEdit that compare response bodies to
  # dedupe posts across refreshes. We do not use the hover behaviour, so
  # the safest fix is to strip the attribute entirely.
  defp strip_nondeterministic_attrs(html) do
    String.replace(html, ~r/ data-group-id="[^"]*"/, "")
  end

  defp split_frontmatter!(source, path) do
    case String.split(source, ~r/\n---\n/, parts: 2) do
      [meta_string, body] ->
        {attrs, _binding} = Code.eval_string(meta_string)

        unless is_map(attrs) do
          raise "Frontmatter in #{path} did not evaluate to a map"
        end

        {attrs, body}

      _ ->
        raise "Post file #{path} is missing a `---` frontmatter separator"
    end
  end
end
