defmodule ElixirLocalize.Generator do
  @moduledoc """
  Static site generator. Walks the compiled list of posts and writes a
  self-contained website into the output directory (defaults to `_site/`).
  """

  alias ElixirLocalize.{Rss, Templates}

  @default_output "_site"

  @doc """
  Build the static site.

  ### Arguments

  * `output_dir` is the directory to write into. It is deleted and recreated.
    Defaults to `"_site"` in the current working directory.

  ### Returns

  * `{:ok, %{files: non_neg_integer(), bytes: non_neg_integer(), output: Path.t()}}`
    with counts of the files written and their total size.

  """
  @spec build(Path.t()) :: {:ok, map()}
  def build(output_dir \\ @default_output) do
    output_dir = Path.expand(output_dir)
    site = ElixirLocalize.site_config()
    posts = ElixirLocalize.all_posts()

    reset_output!(output_dir)
    written_static = copy_static(output_dir)
    written_index = write(output_dir, "index.html", Templates.index(posts, site))
    written_posts = Enum.map(posts, &write_post(output_dir, site, &1))
    written_colophon = write(output_dir, "colophon/index.html", Templates.colophon(site))
    written_feed = write(output_dir, "feed.xml", Rss.feed(posts, site))
    written_robots = write(output_dir, "robots.txt", robots_txt())

    all =
      [written_index, written_colophon, written_feed, written_robots] ++
        written_posts ++ written_static

    {:ok,
     %{
       output: output_dir,
       files: length(all),
       bytes: Enum.sum(Enum.map(all, fn {_path, bytes} -> bytes end))
     }}
  end

  defp reset_output!(dir) do
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
  end

  defp copy_static(output_dir) do
    source = Application.app_dir(:elixir_localize, "priv/static")

    if File.dir?(source) do
      source
      |> walk_files()
      |> Enum.map(fn path ->
        rel = Path.relative_to(path, source)
        dest = Path.join(output_dir, rel)
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {dest, File.stat!(dest).size}
      end)
    else
      []
    end
  end

  defp write_post(output_dir, site, post) do
    rel = Path.join(["posts", post.slug, "index.html"])
    write(output_dir, rel, Templates.post(post, site))
  end

  defp write(output_dir, relative, content) do
    path = Path.join(output_dir, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    {path, byte_size(content)}
  end

  defp robots_txt do
    """
    User-agent: *
    Allow: /
    """
  end

  @doc false
  def walk_files(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      full = Path.join(dir, entry)

      cond do
        File.dir?(full) -> walk_files(full)
        File.regular?(full) -> [full]
        true -> []
      end
    end)
  end
end
