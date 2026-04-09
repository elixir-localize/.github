defmodule ElixirLocalize.Sitemap do
  @moduledoc """
  Generates a `sitemap.xml` document listing every public URL on the
  blog: the home page, the colophon, every published post, and every
  category landing page.

  The file format follows the [Sitemaps 0.9 spec](https://www.sitemaps.org/protocol.html).
  `<lastmod>` dates come from each post's `:updated_at` (or the most
  recent post for aggregate pages like the home and category pages).
  """

  alias ElixirLocalize.Post

  @doc """
  Build a sitemap XML document for the given published posts.

  ### Arguments

  * `posts` is the list of published posts to include.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the complete sitemap XML document.

  """
  @spec generate([Post.t()], keyword()) :: binary()
  def generate(posts, site) do
    base_url = String.trim_trailing(site[:base_url], "/")

    latest_updated_at =
      posts
      |> Enum.map(& &1.updated_at)
      |> Enum.max(DateTime, fn -> DateTime.utc_now() end)

    urls =
      [
        url_entry(base_url <> "/", latest_updated_at, "daily", "1.0"),
        url_entry(base_url <> "/colophon/", latest_updated_at, "yearly", "0.3")
      ] ++
        post_entries(posts, base_url) ++
        category_entries(posts, base_url)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.join(urls, "\n")}
    </urlset>
    """
  end

  defp post_entries(posts, base_url) do
    Enum.map(posts, fn post ->
      url_entry(
        base_url <> "/posts/" <> post.slug <> "/",
        post.updated_at,
        "monthly",
        "0.8"
      )
    end)
  end

  defp category_entries(posts, base_url) do
    posts
    |> Enum.flat_map(fn post -> Enum.map(post.tags, &{&1, post.updated_at}) end)
    |> Enum.group_by(
      fn {tag, _updated_at} -> Post.tag_slug(tag) end,
      fn {_tag, updated_at} -> updated_at end
    )
    |> Enum.reject(fn {slug, _} -> slug == "" end)
    |> Enum.map(fn {slug, updated_ats} ->
      lastmod = Enum.max(updated_ats, DateTime, fn -> DateTime.utc_now() end)
      url_entry(base_url <> "/categories/" <> slug <> "/", lastmod, "weekly", "0.5")
    end)
  end

  defp url_entry(loc, %DateTime{} = lastmod, changefreq, priority) do
    """
      <url>
        <loc>#{escape(loc)}</loc>
        <lastmod>#{Date.to_iso8601(DateTime.to_date(lastmod))}</lastmod>
        <changefreq>#{changefreq}</changefreq>
        <priority>#{priority}</priority>
      </url>\
    """
  end

  defp escape(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
