defmodule ElixirLocalize.PublisherTest do
  use ExUnit.Case, async: true

  alias ElixirLocalize.Publisher

  test "content_type/1 maps extensions" do
    assert Publisher.content_type("a/b/index.html") == "text/html; charset=utf-8"
    assert Publisher.content_type("site.css") == "text/css; charset=utf-8"
    assert Publisher.content_type("feed.xml") == "application/rss+xml; charset=utf-8"
    assert Publisher.content_type("icon.SVG") == "image/svg+xml"
    assert Publisher.content_type("unknown.bin") == "application/octet-stream"
  end
end
