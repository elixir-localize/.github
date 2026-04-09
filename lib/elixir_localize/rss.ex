defmodule ElixirLocalize.Rss do
  @moduledoc """
  Builds an RSS 2.0 feed document from the blog's posts.
  """

  alias ElixirLocalize.Post

  @doc """
  Build an RSS 2.0 XML feed for the given posts.

  ### Arguments

  * `posts` is the list of `t:ElixirLocalize.Post.t/0` structs to include.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the complete RSS XML document.

  """
  @spec feed([Post.t()], keyword()) :: binary()
  def feed(posts, site) do
    base_url = String.trim_trailing(site[:base_url], "/")
    now = rfc2822(DateTime.utc_now())
    channel_title = escape(site[:title])
    channel_description = escape(site[:description])
    channel_link = escape(base_url <> "/")
    self_link = escape(base_url <> "/feed.xml")
    language = escape(site[:language] || "en")

    items = Enum.map_join(posts, "\n", &item(&1, base_url))

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
         xmlns:atom="http://www.w3.org/2005/Atom"
         xmlns:content="http://purl.org/rss/1.0/modules/content/"
         xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel>
        <title>#{channel_title}</title>
        <link>#{channel_link}</link>
        <description>#{channel_description}</description>
        <language>#{language}</language>
        <lastBuildDate>#{now}</lastBuildDate>
        <atom:link href="#{self_link}" rel="self" type="application/rss+xml" />
    #{items}
      </channel>
    </rss>
    """
  end

  defp item(%Post{} = post, base_url) do
    url = base_url <> "/posts/" <> post.slug <> "/"
    pub_date = post.date |> DateTime.new!(~T[12:00:00]) |> rfc2822()

    """
        <item>
          <title>#{escape(post.title)}</title>
          <link>#{escape(url)}</link>
          <guid isPermaLink="true">#{escape(url)}</guid>
          <pubDate>#{pub_date}</pubDate>
          <dc:creator>#{escape(post.author)}</dc:creator>
          <description>#{escape(post.summary)}</description>
          <content:encoded><![CDATA[#{post.body}]]></content:encoded>
        </item>\
    """
  end

  @days {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
  @months {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

  defp rfc2822(%DateTime{} = dt) do
    day = elem(@days, Date.day_of_week(DateTime.to_date(dt)) |> rem(7))
    month = elem(@months, dt.month - 1)

    :io_lib.format("~s, ~2..0B ~s ~4..0B ~2..0B:~2..0B:~2..0B +0000", [
      day,
      dt.day,
      month,
      dt.year,
      dt.hour,
      dt.minute,
      dt.second
    ])
    |> IO.iodata_to_binary()
  end

  defp escape(nil), do: ""

  defp escape(string) when is_binary(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
