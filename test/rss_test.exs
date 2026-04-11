defmodule StaticBlog.RssTest do
  use ExUnit.Case, async: true

  alias StaticBlog.{Post, Rss}

  @site [
    title: "Localize",
    tagline: "Tagline",
    description: "The blog",
    author: "Kip Cole",
    base_url: "https://blog.localize.dev",
    language: "en"
  ]

  defp post do
    %Post{
      id: "hello",
      slug: "hello",
      date: ~D[2026-04-09],
      title: "Hello <world>",
      author: "Kip Cole",
      body: "<p>Body & stuff</p>",
      description: nil,
      tags: [],
      summary: "A summary with <tags> & ampersands",
      status: :published,
      published_at: ~U[2026-04-09 12:00:00Z],
      updated_at: ~U[2026-04-09 12:00:00Z]
    }
  end

  test "produces valid-looking RSS 2.0 with escaping" do
    xml = Rss.feed([post()], @site)

    assert xml =~ ~s|<?xml version="1.0"|
    assert xml =~ "<rss version=\"2.0\""
    assert xml =~ "<channel>"
    assert xml =~ "<title>Localize</title>"
    assert xml =~ "<atom:link"
    assert xml =~ "<item>"
    assert xml =~ "Hello &lt;world&gt;"
    assert xml =~ "A summary with &lt;tags&gt; &amp; ampersands"
    assert xml =~ "https://blog.localize.dev/posts/hello/"
    assert xml =~ "<![CDATA[<p>Body & stuff</p>]]>"
  end
end
