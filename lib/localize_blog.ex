defmodule LocalizeBlog do
  @moduledoc """
  The Localize blog.

  Uses `NimblePublisher` to parse markdown files from `priv/posts/` at compile
  time into a list of `StaticBlog.Post` structs, sorted newest-first.

  Configure this module as the blog module so the static site generator
  can use compile-time posts:

      config :static_blog, :blog_module, LocalizeBlog

  """

  alias StaticBlog.Post

  use NimblePublisher,
    build: Post,
    from: Application.app_dir(:localize_blog, "priv/posts/**/*.md"),
    as: :posts,
    highlighters: [:makeup_elixir, :makeup_erlang]

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  @doc """
  Returns all posts, newest first.

  ### Returns

  * A list of `t:StaticBlog.Post.t/0` structs sorted by `:date` descending.

  """
  @spec all_posts() :: [Post.t()]
  def all_posts, do: @posts

  @doc """
  Look up a post by its slug.

  ### Arguments

  * `slug` is the URL slug portion of the post filename.

  ### Returns

  * The matching `t:StaticBlog.Post.t/0`, or `nil` if no post has that slug.

  """
  @spec post_by_slug(String.t()) :: Post.t() | nil
  def post_by_slug(slug), do: Enum.find(@posts, &(&1.slug == slug))
end
