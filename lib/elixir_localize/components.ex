defmodule ElixirLocalize.Components do
  @moduledoc """
  Shared `Phoenix.Component` templates: the site layout, masthead, footer, and
  theme toggle used by both the index and the per-post pages.
  """

  use Phoenix.Component

  @doc """
  Root HTML layout. Renders `<!doctype html>`, the `<head>`, masthead, the
  inner block content, and the footer.

  ### Attributes

  * `:title` is the document title.

  * `:description` is the meta description.

  * `:canonical` is the canonical URL for the current page.

  * `:site` is the site configuration keyword list.

  * `:page_kind` is either `:index` or `:post`, used to toggle the `<h1>`
    treatment in the masthead.

  """
  attr(:title, :string, required: true)
  attr(:description, :string, required: true)
  attr(:canonical, :string, required: true)
  attr(:site, :any, required: true)
  attr(:page_kind, :atom, default: :post)
  attr(:og_type, :string, default: "website")
  attr(:og_image, :string, default: nil)
  attr(:published_at, :any, default: nil)
  attr(:updated_at, :any, default: nil)
  attr(:article_author, :string, default: nil)
  attr(:article_tags, :list, default: [])
  attr(:structured_data, :list, default: [])
  slot(:inner_block, required: true)

  def layout(assigns) do
    assigns =
      assigns
      |> assign_new(:resolved_og_image, fn ->
        assigns.og_image ||
          String.trim_trailing(assigns.site[:base_url], "/") <> "/logo.png"
      end)
      |> assign_new(:structured_data_html, fn ->
        structured_data_tags(assigns.structured_data)
      end)

    ~H"""
    <!DOCTYPE html>
    <html lang={@site[:language]} data-theme="light">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@title}</title>
        <meta name="description" content={@description} />
        <meta name="theme-color" content="#fbfaf7" media="(prefers-color-scheme: light)" />
        <meta name="theme-color" content="#15121a" media="(prefers-color-scheme: dark)" />
        <meta name="author" content={@site[:author]} />
        <meta name="generator" content="ElixirLocalize blog engine" />
        <link rel="canonical" href={@canonical} />
        <link rel="alternate" type="application/rss+xml" title={@site[:title] <> " — RSS"} href="/feed.xml" />
        <link rel="micropub" href={@site[:micropub_url]} />
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
        <link rel="apple-touch-icon" href="/logo.png" />
        <link rel="manifest" href="/manifest.webmanifest" />
        <link rel="stylesheet" href="/css/site.css" />

        <meta property="og:type" content={@og_type} />
        <meta property="og:site_name" content={@site[:title]} />
        <meta property="og:title" content={@title} />
        <meta property="og:description" content={@description} />
        <meta property="og:url" content={@canonical} />
        <meta property="og:locale" content={og_locale(@site[:language])} />
        <meta property="og:image" content={@resolved_og_image} />

        <%= if @og_type == "article" do %>
          <meta
            :if={match?(%DateTime{}, @published_at)}
            property="article:published_time"
            content={DateTime.to_iso8601(@published_at)}
          />
          <meta
            :if={match?(%DateTime{}, @updated_at)}
            property="article:modified_time"
            content={DateTime.to_iso8601(@updated_at)}
          />
          <meta :if={@article_author} property="article:author" content={@article_author} />
          <meta :for={tag <- @article_tags} property="article:tag" content={tag} />
        <% end %>

        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={@title} />
        <meta name="twitter:description" content={@description} />
        <meta name="twitter:image" content={@resolved_og_image} />

        {Phoenix.HTML.raw(@structured_data_html)}

        <script>
          (function () {
            try {
              var stored = localStorage.getItem('theme');
              var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
              var theme = stored || (prefersDark ? 'dark' : 'light');
              document.documentElement.dataset.theme = theme;
            } catch (e) {}
          })();
        </script>
      </head>
      <body>
        <a class="skip-link" href="#main">Skip to content</a>

        <header class="masthead" role="banner">
          <div class="masthead-inner">
            <div class="masthead-heading">
              <a class="site-logo-link" href="/" aria-label={@site[:title] <> " home"}>
                <img class="site-logo" src="/logo.png" alt="" width="160" height="160" />
              </a>
              <div class="masthead-text">
                <.site_title page_kind={@page_kind} site={@site} />
                <p class="tagline">{@site[:tagline]}</p>
              </div>
            </div>
            <nav class="primary-nav" aria-label="Primary">
              <a href="/">Home</a>
              <a href="/feed.xml">RSS</a>
              <button
                type="button"
                id="theme-toggle"
                class="theme-toggle"
                aria-label="Toggle colour scheme"
                aria-pressed="false"
              >
                <span aria-hidden="true" class="theme-icon">◐</span>
                <span class="visually-hidden">Toggle colour scheme</span>
              </button>
            </nav>
          </div>
        </header>

        <div class="layout">
          <aside class="sidebar" aria-label="Related sites">
            <nav aria-labelledby="sidebar-projects-heading">
              <h2 id="sidebar-projects-heading" class="sidebar-heading">Projects</h2>
              <ul class="sidebar-list">
                <li>
                  <a href="https://github.com/elixir-localize" rel="me external">Localize</a>
                  <span class="sidebar-note">Next-generation localization for Elixir</span>
                </li>
                <li>
                  <a href="https://github.com/elixir-image" rel="external">Image processing</a>
                  <span class="sidebar-note">Vix, Image and friends for Elixir</span>
                </li>
              </ul>
            </nav>
            <nav aria-labelledby="sidebar-about-heading">
              <h2 id="sidebar-about-heading" class="sidebar-heading">About</h2>
              <ul class="sidebar-list">
                <li><a href="/colophon/">Colophon</a></li>
                <li><a href="/feed.xml">RSS feed</a></li>
              </ul>
            </nav>
          </aside>

          <main id="main" class="main" tabindex="-1">
            {render_slot(@inner_block)}
          </main>
        </div>

        <footer class="site-footer" role="contentinfo">
          <p>
            © {DateTime.utc_now().year} {@site[:author]}.
            <a href="/feed.xml">Subscribe via RSS</a>.
          </p>
        </footer>

        <div class="visually-hidden" id="theme-announce" aria-live="polite"></div>
        <script>
          (function () {
            var btn = document.getElementById('theme-toggle');
            var announce = document.getElementById('theme-announce');
            if (!btn) return;
            function sync() {
              var t = document.documentElement.dataset.theme;
              btn.setAttribute('aria-pressed', t === 'dark' ? 'true' : 'false');
            }
            sync();
            btn.addEventListener('click', function () {
              var current = document.documentElement.dataset.theme;
              var next = current === 'dark' ? 'light' : 'dark';
              document.documentElement.dataset.theme = next;
              try { localStorage.setItem('theme', next); } catch (e) {}
              sync();
              if (announce) announce.textContent = 'Colour scheme: ' + next;
            });
          })();
        </script>
      </body>
    </html>
    """
  end

  attr(:page_kind, :atom, required: true)
  attr(:site, :any, required: true)

  defp site_title(%{page_kind: :index} = assigns) do
    ~H"""
    <h1 class="site-title"><a href="/">{@site[:title]}</a></h1>
    """
  end

  defp site_title(assigns) do
    ~H"""
    <p class="site-title"><a href="/">{@site[:title]}</a></p>
    """
  end

  # Open Graph locales are formatted as IETF language tags with an
  # underscore separator between language and region. The simple
  # two-letter locale we use in :site[:language] maps to a reasonable
  # default region; edit here if you need something more specific.
  defp og_locale("en"), do: "en_GB"
  defp og_locale("en_GB"), do: "en_GB"
  defp og_locale("en_US"), do: "en_US"
  defp og_locale(other) when is_binary(other), do: String.replace(other, "-", "_")
  defp og_locale(_), do: "en_GB"

  # HEEx treats the body of a <script> element as raw text — {} / <%= %>
  # interpolations inside are not evaluated. To emit JSON-LD we
  # pre-render the full <script>…</script> blocks as a single binary and
  # inject it via Phoenix.HTML.raw/1.
  defp structured_data_tags([]), do: ""

  defp structured_data_tags(payloads) when is_list(payloads) do
    payloads
    |> Enum.map(fn payload ->
      ~s(<script type="application/ld+json">#{payload}</script>)
    end)
    |> Enum.join("\n")
  end
end
