defmodule StaticBlog.MicropubTest do
  use ExUnit.Case, async: false

  alias StaticBlog.Micropub

  describe "properties_from_params/1" do
    test "parses a JSON-style Micropub payload" do
      json = %{
        "type" => ["h-entry"],
        "properties" => %{
          "name" => ["My post"],
          "content" => ["Plain content"],
          "category" => ["elixir", "release"],
          "published" => ["2026-04-09"],
          "mp-slug" => ["custom-slug"],
          "summary" => ["A summary"]
        }
      }

      assert %{
               title: "My post",
               content: "Plain content",
               tags: ["elixir", "release"],
               date: ~D[2026-04-09],
               slug: "custom-slug",
               description: "A summary"
             } = Micropub.properties_from_params(json)
    end

    test "parses a form-encoded payload" do
      form = %{
        "h" => "entry",
        "name" => "Form post",
        "content" => "Body here",
        "category" => ["a", "b"]
      }

      assert %{title: "Form post", content: "Body here", tags: ["a", "b"]} =
               Micropub.properties_from_params(form)
    end

    test "extracts markdown from JSON content object" do
      json = %{
        "properties" => %{
          "name" => ["t"],
          "content" => [%{"markdown" => "# Heading\n\nBody."}]
        }
      }

      assert %{content: "# Heading\n\nBody."} = Micropub.properties_from_params(json)
    end
  end

  describe "slug_from_url/1" do
    test "extracts slug from canonical URL with trailing slash" do
      assert {:ok, "hello-world"} =
               Micropub.slug_from_url("https://blog.localize.dev/posts/hello-world/")
    end

    test "extracts slug without trailing slash" do
      assert {:ok, "hello-world"} =
               Micropub.slug_from_url("https://blog.localize.dev/posts/hello-world")
    end

    test "rejects non-post URLs" do
      assert {:error, :invalid_url} =
               Micropub.slug_from_url("https://blog.localize.dev/about/")
    end
  end

  describe "slugify/1" do
    test "produces lowercase dash-separated slug" do
      assert Micropub.slugify("Hello, World!") == "hello-world"
      assert Micropub.slugify("Why Localize?") == "why-localize"
      assert Micropub.slugify("  Leading/trailing  ") == "leading-trailing"
    end
  end

  describe "serialize/2" do
    test "round-trips through the frontmatter parser" do
      attrs = %{
        title: "Round trip",
        author: "Tester",
        tags: ["a", "b"],
        description: "A test"
      }

      serialized = Micropub.serialize(attrs, "Body content here.\n")
      assert serialized =~ "title: \"Round trip\""
      assert serialized =~ "---\nBody content here."

      [meta_string, body] = String.split(serialized, ~r/\n---\n/, parts: 2)
      {parsed, _} = Code.eval_string(meta_string)
      assert parsed.title == "Round trip"
      assert parsed.tags == ["a", "b"]
      assert body == "Body content here.\n"
    end
  end

  describe "create/1" do
    setup do
      tmp =
        Path.join(System.tmp_dir!(), "localize_blog_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(tmp)

      on_exit(fn ->
        File.rm_rf!(tmp)

        :localize_blog
        |> Application.app_dir("priv/posts")
        |> Path.join("*-test-micropub-*.md")
        |> Path.wildcard()
        |> Enum.each(&File.rm!/1)
      end)

      %{tmp: tmp}
    end

    test "writes a new post file and returns its canonical URL" do
      properties = %{
        title: "Test Micropub #{System.unique_integer([:positive])}",
        content: "Hello from the test suite.",
        tags: ["test"],
        slug: "test-micropub-#{System.unique_integer([:positive])}"
      }

      assert {:ok, url} = Micropub.create(properties)
      assert url =~ "/posts/test-micropub-"
      assert url =~ "/"

      {:ok, slug} = Micropub.slug_from_url(url)
      path = StaticBlog.RuntimePosts.path_for_slug(slug)
      assert path != nil
      assert File.exists?(path)
      assert File.read!(path) =~ "Hello from the test suite."
    end

    test "creates a post without explicit title using generated title" do
      slug = "test-micropub-notitle-#{System.unique_integer([:positive])}"

      assert {:ok, url} =
               Micropub.create(%{content: "Auto-titled post body.", slug: slug})

      assert url =~ "/posts/#{slug}/"

      path = StaticBlog.RuntimePosts.path_for_slug(slug)
      assert path != nil
      source = File.read!(path)
      assert source =~ "Auto-titled post body"
      assert source =~ "title:"
    end

    test "rejects create without content" do
      assert {:error, :content_required} =
               Micropub.create(%{title: "no body", slug: "test-micropub-nobody"})
    end
  end
end
