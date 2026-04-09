defmodule ElixirLocalize.Templates do
  @moduledoc """
  Renders complete HTML documents for the blog home page and individual post
  pages. Templates return binary HTML ready to be written to disk.
  """

  use Phoenix.Component

  alias ElixirLocalize.Components
  alias ElixirLocalize.Post

  @doc """
  Render the blog index page listing all posts.

  ### Arguments

  * `posts` is the list of `t:ElixirLocalize.Post.t/0` structs to display,
    already sorted newest-first.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the full HTML document.

  """
  @spec index([Post.t()], keyword()) :: binary()
  def index(posts, site) do
    assigns = %{posts: posts, site: site}

    render(~H"""
    <Components.layout
      title={@site[:title]}
      description={@site[:description]}
      canonical={@site[:base_url] <> "/"}
      site={@site}
      page_kind={:index}
    >
      <ol class="post-list" aria-label="Blog posts">
        <li :for={post <- @posts} class="post-list-item">
          <article>
            <h2 class="post-list-title">
              <a href={"/posts/" <> post.slug <> "/"}>{post.title}</a>
            </h2>
            <p class="post-meta">
              <time datetime={Date.to_iso8601(post.date)}>{format_date(post.date)}</time>
            </p>
            <p class="post-summary">{post.summary}</p>
            <.post_tags tags={post.tags} />
          </article>
        </li>
      </ol>
    </Components.layout>
    """)
  end

  attr :tags, :list, required: true

  defp post_tags(%{tags: []} = assigns), do: ~H""

  defp post_tags(assigns) do
    ~H"""
    <p class="post-tags" aria-label="Categories">
      <span class="post-tags-label">Filed under:</span>
      <%= for {tag, index} <- Enum.with_index(@tags) do %><%= if index > 0 do %><span class="post-tags-sep" aria-hidden="true">, </span><% end %><a class="post-tag" href={"/categories/" <> ElixirLocalize.Post.tag_slug(tag) <> "/"}>{tag}</a><% end %>
    </p>
    """
  end

  @doc """
  Render a single post page.

  ### Arguments

  * `post` is the `t:ElixirLocalize.Post.t/0` to render.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the full HTML document.

  """
  @spec post(Post.t(), keyword()) :: binary()
  def post(post, site) do
    assigns = %{post: post, site: site}

    render(~H"""
    <Components.layout
      title={@post.title <> " — " <> @site[:title]}
      description={@post.description || @post.summary}
      canonical={@site[:base_url] <> "/posts/" <> @post.slug <> "/"}
      site={@site}
      page_kind={:post}
    >
      <article class="post">
        <header class="post-header">
          <h1 class="post-title">{@post.title}</h1>
          <p class="post-meta">
            <time datetime={Date.to_iso8601(@post.date)}>{format_date(@post.date)}</time>
          </p>
        </header>
        <div class="post-body">
          {Phoenix.HTML.raw(@post.body)}
        </div>
        <.post_tags tags={@post.tags} />
        <hr />
        <p class="post-nav"><a href="/">← Back to home</a></p>
      </article>
    </Components.layout>
    """)
  end

  @doc """
  Render a category page listing every published post tagged with a given
  tag.

  ### Arguments

  * `tag` is the original (non-slugified) tag string.

  * `posts` is the list of posts to render, already filtered to this tag and
    sorted newest-first.

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the full HTML document.

  """
  @spec category(String.t(), [Post.t()], keyword()) :: binary()
  def category(tag, posts, site) do
    slug = ElixirLocalize.Post.tag_slug(tag)
    assigns = %{tag: tag, posts: posts, site: site, slug: slug}

    render(~H"""
    <Components.layout
      title={"Category: " <> @tag <> " — " <> @site[:title]}
      description={"All posts in the " <> @tag <> " category."}
      canonical={@site[:base_url] <> "/categories/" <> @slug <> "/"}
      site={@site}
      page_kind={:post}
    >
      <header class="category-header">
        <p class="category-eyebrow">Category</p>
        <h1 class="category-title">{@tag}</h1>
        <p class="category-count">
          {length(@posts)} {if length(@posts) == 1, do: "post", else: "posts"}
        </p>
      </header>

      <ol class="post-list" aria-label={"Posts in " <> @tag}>
        <li :for={post <- @posts} class="post-list-item">
          <article>
            <h2 class="post-list-title">
              <a href={"/posts/" <> post.slug <> "/"}>{post.title}</a>
            </h2>
            <p class="post-meta">
              <time datetime={Date.to_iso8601(post.date)}>{format_date(post.date)}</time>
            </p>
            <p class="post-summary">{post.summary}</p>
          </article>
        </li>
      </ol>

      <hr />
      <p class="post-nav"><a href="/">← Back to home</a></p>
    </Components.layout>
    """)
  end

  @doc """
  Render the colophon page describing how the site is built.

  ### Arguments

  * `site` is the site configuration keyword list.

  ### Returns

  * A binary containing the full HTML document.

  """
  @spec colophon(keyword()) :: binary()
  def colophon(site) do
    assigns = %{site: site}

    render(~H"""
    <Components.layout
      title={"Colophon — " <> @site[:title]}
      description={"How the " <> @site[:title] <> " blog is built."}
      canonical={@site[:base_url] <> "/colophon/"}
      site={@site}
      page_kind={:post}
    >
      <article class="post">
        <header class="post-header">
          <h1 class="post-title">Colophon</h1>
          <p class="post-meta">How this site is built.</p>
        </header>
        <div class="post-body">
          <p>
            This blog is a static website generated by a small Elixir program that lives in the same repository as its content. The source is plain markdown; everything else is built from it on demand.
          </p>

          <h2>Build</h2>
          <ul>
            <li>
              <a href="https://elixir-lang.org">Elixir</a> and
              <a href="https://www.erlang.org">Erlang/OTP</a> run the build.
              Mix tasks <code>blog.build</code>, <code>blog.serve</code> and
              <code>blog.publish</code> drive it end to end.
            </li>
            <li>
              <a href="https://hex.pm/packages/nimble_publisher">nimble_publisher</a>
              parses the markdown files in <code>priv/posts/</code> into post
              structs at compile time.
            </li>
            <li>
              <a href="https://hex.pm/packages/makeup_elixir">makeup_elixir</a>
              and <a href="https://hex.pm/packages/makeup_erlang">makeup_erlang</a>
              provide syntax highlighting for fenced code blocks.
            </li>
            <li>
              <a href="https://hex.pm/packages/phoenix_live_view">Phoenix LiveView</a>'s
              component and HEEx compiler are used — at build time only — to render the
              page templates to HTML. There is no server at runtime.
            </li>
          </ul>

          <h2>Design</h2>
          <ul>
            <li>
              Typography and layout are inspired by
              <a href="https://daringfireball.net">Daring Fireball</a>. Body text
              is set in Verdana, titles in Gill Sans, code in SF Mono.
            </li>
            <li>
              The colour palette is shifted away from the canonical Elixir purple
              into a slightly warmer violet. All body-text pairings meet
              WCAG AAA (≥ 7:1).
            </li>
            <li>
              Light and dark themes are switched by a small inline script that
              reads <code>localStorage</code> and <code>prefers-color-scheme</code>.
              There is no JavaScript framework.
            </li>
          </ul>

          <h2>Accessibility</h2>
          <ul>
            <li>Semantic HTML landmarks, a skip-to-content link, and visible focus outlines.</li>
            <li>Theme toggle is a real button with <code>aria-pressed</code>.</li>
            <li><code>prefers-reduced-motion</code> disables all transitions.</li>
            <li>
              Colour contrast verified with the
              <a href="https://github.com/elixir-image/color">Color</a> library's
              WCAG helpers.
            </li>
          </ul>

          <h2>Hosting</h2>
          <p>
            The generated site is uploaded to a
            <a href="https://www.cloudflare.com/developer-platform/r2/">Cloudflare R2</a>
            bucket using an <code>ElixirLocalize.Publisher</code> module that signs
            requests with AWS Signature V4 via
            <a href="https://hex.pm/packages/aws_signature">aws_signature</a>
            and transports them with <a href="https://hex.pm/packages/req">Req</a>.
            The publisher diffs the local tree against the remote manifest so
            subsequent syncs only upload what has changed.
          </p>

          <h2>Source</h2>
          <p>
            The blog's source — including this page — lives alongside Localize
            itself on GitHub. Fixes and typos are welcome as pull requests.
          </p>
        </div>
        <hr />
        <p class="post-nav"><a href="/">← Back to home</a></p>
      </article>
    </Components.layout>
    """)
  end

  defp render(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  @months {"January", "February", "March", "April", "May", "June", "July", "August", "September",
           "October", "November", "December"}

  @doc false
  def format_date(%Date{year: y, month: m, day: d}) do
    "#{elem(@months, m - 1)} #{d}, #{y}"
  end
end
