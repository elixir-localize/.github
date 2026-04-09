defmodule ElixirLocalize.SEO do
  @moduledoc """
  Builds [JSON-LD](https://json-ld.org/) structured-data payloads and
  social-meta bundles for each page type. Separated from templates so the
  metadata shape can be tested and reused.

  Google reads `BlogPosting`, `WebSite`, `CollectionPage`, and
  `BreadcrumbList` schemas to render rich results in search. See
  <https://schema.org/BlogPosting>.
  """

  alias ElixirLocalize.Post

  @doc """
  Return the absolute URL of the site's logo image.

  ### Arguments

  * `site` is the site configuration keyword list.

  ### Returns

  * An absolute URL string.

  """
  @spec logo_url(keyword()) :: String.t()
  def logo_url(site) do
    base(site) <> "/logo.png"
  end

  @doc """
  Return a JSON-encoded `WebSite` structured data payload for the home
  page.

  ### Arguments

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the JSON-LD document.

  """
  @spec json_ld_website(keyword()) :: binary()
  def json_ld_website(site) do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => site[:title],
      "description" => site[:description],
      "url" => base(site) <> "/",
      "inLanguage" => site[:language],
      "publisher" => publisher(site)
    }
    |> encode()
  end

  @doc """
  Return a JSON-encoded `BlogPosting` structured data payload for a
  single post.

  ### Arguments

  * `post` is the `t:ElixirLocalize.Post.t/0` to serialize.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the JSON-LD document.

  """
  @spec json_ld_blog_posting(Post.t(), keyword()) :: binary()
  def json_ld_blog_posting(%Post{} = post, site) do
    url = post_url(post, site)
    word_count = word_count(post)

    %{
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => post.title,
      "description" => post.description || post.summary,
      "datePublished" => DateTime.to_iso8601(post.published_at),
      "dateModified" => DateTime.to_iso8601(post.updated_at),
      "author" => %{
        "@type" => "Person",
        "name" => post.author
      },
      "publisher" => publisher(site),
      "mainEntityOfPage" => %{
        "@type" => "WebPage",
        "@id" => url
      },
      "url" => url,
      "image" => logo_url(site),
      "keywords" => Enum.join(post.tags, ","),
      "articleSection" => post.tags,
      "wordCount" => word_count,
      "inLanguage" => site[:language]
    }
    |> encode()
  end

  @doc """
  Return a JSON-encoded `CollectionPage` structured data payload for a
  category landing page.

  ### Arguments

  * `tag` is the human-readable tag name.

  * `posts` is the list of posts in this category.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the JSON-LD document.

  """
  @spec json_ld_collection_page(String.t(), [Post.t()], keyword()) :: binary()
  def json_ld_collection_page(tag, posts, site) do
    slug = Post.tag_slug(tag)
    url = base(site) <> "/categories/" <> slug <> "/"

    %{
      "@context" => "https://schema.org",
      "@type" => "CollectionPage",
      "name" => "Category: " <> tag,
      "description" => "All posts in the " <> tag <> " category.",
      "url" => url,
      "inLanguage" => site[:language],
      "publisher" => publisher(site),
      "mainEntity" => %{
        "@type" => "ItemList",
        "itemListElement" => list_items(posts, site)
      }
    }
    |> encode()
  end

  @doc """
  Return a JSON-encoded `BreadcrumbList` payload for a single post.

  ### Arguments

  * `post` is the `t:ElixirLocalize.Post.t/0` to generate breadcrumbs for.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the JSON-LD document.

  """
  @spec json_ld_breadcrumbs_for_post(Post.t(), keyword()) :: binary()
  def json_ld_breadcrumbs_for_post(%Post{} = post, site) do
    base_url = base(site)

    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => [
        %{"@type" => "ListItem", "position" => 1, "name" => "Home", "item" => base_url <> "/"},
        %{
          "@type" => "ListItem",
          "position" => 2,
          "name" => post.title,
          "item" => post_url(post, site)
        }
      ]
    }
    |> encode()
  end

  @doc """
  Return a JSON-encoded `BreadcrumbList` payload for a category page.

  ### Arguments

  * `tag` is the human-readable tag name.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the JSON-LD document.

  """
  @spec json_ld_breadcrumbs_for_category(String.t(), keyword()) :: binary()
  def json_ld_breadcrumbs_for_category(tag, site) do
    base_url = base(site)
    slug = Post.tag_slug(tag)

    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => [
        %{"@type" => "ListItem", "position" => 1, "name" => "Home", "item" => base_url <> "/"},
        %{
          "@type" => "ListItem",
          "position" => 2,
          "name" => "Category: " <> tag,
          "item" => base_url <> "/categories/" <> slug <> "/"
        }
      ]
    }
    |> encode()
  end

  @doc """
  Count words in a post body by stripping HTML tags and counting
  whitespace-delimited tokens.

  ### Arguments

  * `post` is the post whose body to count.

  ### Returns

  * A non-negative integer word count.

  """
  @spec word_count(Post.t()) :: non_neg_integer()
  def word_count(%Post{body: body}) when is_binary(body) do
    body
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp base(site), do: String.trim_trailing(site[:base_url], "/")

  defp post_url(%Post{slug: slug}, site), do: base(site) <> "/posts/" <> slug <> "/"

  defp publisher(site) do
    %{
      "@type" => "Organization",
      "name" => site[:title],
      "logo" => %{
        "@type" => "ImageObject",
        "url" => logo_url(site)
      }
    }
  end

  defp list_items(posts, site) do
    posts
    |> Enum.with_index(1)
    |> Enum.map(fn {post, position} ->
      %{
        "@type" => "ListItem",
        "position" => position,
        "url" => post_url(post, site),
        "name" => post.title
      }
    end)
  end

  defp encode(data) do
    Jason.encode!(data, escape: :html_safe)
  end
end
