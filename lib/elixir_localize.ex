defmodule ElixirLocalize do
  @moduledoc """
  The Localize blog.

  Uses `NimblePublisher` to parse markdown files from `priv/posts/` at compile
  time into a list of `ElixirLocalize.Post` structs, sorted newest-first.

  The primary public API is `all_posts/0`, `post_by_slug/1`, and
  `site_config/0`, which feed the static site generator.
  """

  alias ElixirLocalize.Post

  use NimblePublisher,
    build: Post,
    from: Application.app_dir(:elixir_localize, "priv/posts/**/*.md"),
    as: :posts,
    highlighters: [:makeup_elixir, :makeup_erlang]

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  @doc """
  Returns all posts, newest first.

  ### Returns

  * A list of `t:ElixirLocalize.Post.t/0` structs sorted by `:date` descending.

  """
  @spec all_posts() :: [Post.t()]
  def all_posts, do: @posts

  @doc """
  Look up a post by its slug.

  ### Arguments

  * `slug` is the URL slug portion of the post filename.

  ### Returns

  * The matching `t:ElixirLocalize.Post.t/0`, or `nil` if no post has that slug.

  """
  @spec post_by_slug(String.t()) :: Post.t() | nil
  def post_by_slug(slug), do: Enum.find(@posts, &(&1.slug == slug))

  @doc """
  Returns the site configuration map.

  ### Returns

  * A keyword list of site-wide settings from `config :elixir_localize, :site`.

  """
  def site_config, do: Application.fetch_env!(:elixir_localize, :site)
end
