defmodule ElixirLocalize.Generator do
  @moduledoc """
  Static site generator. Walks the compiled list of posts and writes a
  self-contained website into the output directory (defaults to `_site/`).
  """

  alias ElixirLocalize.{Rss, Sitemap, Templates}

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
  @spec build(Path.t(), [ElixirLocalize.Post.t()] | nil) :: {:ok, map()}
  def build(output_dir \\ @default_output, posts \\ nil) do
    output_dir = Path.expand(output_dir)
    site = site_config_with_micropub()

    # Drafts stay in `priv/posts/` and are visible to editing clients via
    # the XML-RPC / Micropub endpoints, but they are never rendered into
    # the published site.
    published =
      (posts || ElixirLocalize.all_posts())
      |> Enum.filter(&(&1.status == :published))

    reset_output!(output_dir)
    written_static = copy_static(output_dir)
    written_index = write(output_dir, "index.html", Templates.index(published, site))
    written_posts = Enum.map(published, &write_post(output_dir, site, &1))
    written_categories = write_category_pages(output_dir, site, published)
    written_colophon = write(output_dir, "colophon/index.html", Templates.colophon(site))
    written_404 = write(output_dir, "404.html", Templates.not_found(site))
    written_feed = write(output_dir, "feed.xml", Rss.feed(published, site))
    written_sitemap = write(output_dir, "sitemap.xml", Sitemap.generate(published, site))
    written_robots = write(output_dir, "robots.txt", robots_txt(site))

    all =
      [
        written_index,
        written_colophon,
        written_404,
        written_feed,
        written_sitemap,
        written_robots
      ] ++ written_posts ++ written_categories ++ written_static

    {:ok,
     %{
       output: output_dir,
       files: length(all),
       bytes: Enum.sum(Enum.map(all, fn {_path, bytes} -> bytes end))
     }}
  end

  defp site_config_with_micropub do
    site = ElixirLocalize.site_config()
    default = String.trim_trailing(site[:base_url], "/") <> "/micropub"
    micropub_url = Application.get_env(:elixir_localize, :micropub_url, default)
    Keyword.put(site, :micropub_url, micropub_url)
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

  # Collect every distinct tag used across published posts and render a
  # category page per tag at `_site/categories/<slug>/index.html`. Each
  # page lists the posts in that category, newest-first. Tags that map to
  # the same slug (e.g. "ex_cldr" and "ex-cldr") are merged; the display
  # name used on the page is the one that comes first alphabetically, for
  # determinism.
  defp write_category_pages(output_dir, site, posts) do
    posts
    |> Enum.flat_map(fn post -> Enum.map(post.tags, &{&1, post}) end)
    |> Enum.group_by(
      fn {tag, _post} -> ElixirLocalize.Post.tag_slug(tag) end,
      fn {tag, post} -> {tag, post} end
    )
    |> Enum.reject(fn {slug, _entries} -> slug == "" end)
    |> Enum.map(fn {slug, entries} ->
      display_tag =
        entries |> Enum.map(fn {tag, _post} -> tag end) |> Enum.sort() |> List.first()

      tagged_posts =
        entries
        |> Enum.map(fn {_tag, post} -> post end)
        |> Enum.uniq_by(& &1.slug)
        |> Enum.sort_by(& &1.date, {:desc, Date})

      rel = Path.join(["categories", slug, "index.html"])
      write(output_dir, rel, Templates.category(display_tag, tagged_posts, site))
    end)
  end

  defp write(output_dir, relative, content) do
    path = Path.join(output_dir, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    {path, byte_size(content)}
  end

  defp robots_txt(site) do
    base_url = String.trim_trailing(site[:base_url], "/")

    """
    User-agent: *
    Allow: /

    Sitemap: #{base_url}/sitemap.xml
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
