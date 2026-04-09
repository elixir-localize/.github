defmodule ElixirLocalize.PostTest do
  use ExUnit.Case, async: true

  alias ElixirLocalize.Post

  describe "build/3" do
    test "parses date and slug from filename" do
      post =
        Post.build(
          "/abs/path/priv/posts/2026-04-09-hello-localize.md",
          %{title: "Hello", author: "Kip Cole", tags: [], description: nil},
          "<p>First paragraph.</p>"
        )

      assert post.date == ~D[2026-04-09]
      assert post.slug == "hello-localize"
      assert post.id == "hello-localize"
    end

    test "raises when filename is malformed" do
      assert_raise ArgumentError, ~r/must match YYYY-MM-DD/, fn ->
        Post.build("bad-name.md", %{title: "x"}, "")
      end
    end

    test "uses description as summary when present" do
      post =
        Post.build(
          "/abs/2026-01-01-foo.md",
          %{title: "Foo", description: "Hand-written summary."},
          "<p>Body text.</p>"
        )

      assert post.summary == "Hand-written summary."
    end

    test "falls back to first paragraph as summary" do
      post =
        Post.build(
          "/abs/2026-01-01-foo.md",
          %{title: "Foo"},
          "<p>First <em>paragraph</em> with <code>markup</code>.</p><p>Second.</p>"
        )

      assert post.summary == "First paragraph with markup."
    end
  end
end
