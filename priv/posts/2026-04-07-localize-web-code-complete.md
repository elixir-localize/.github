%{
  title: "localize_web is code-complete",
  author: "Kip Cole",
  tags: ~w(localize localize_web phoenix release),
  description: "The localize_web package, which unifies ex_cldr_plugs, ex_cldr_html and ex_cldr_routes for Phoenix applications, is code-complete. Tests are green. Documentation and validation are next."
}
---

Quick progress note. As of today, **`localize_web` is code-complete** and the full test suite is passing. That includes:

* **`ex_cldr_plugs`** — locale detection from session, cookie, `Accept-Language`, path, query, and host
* **`ex_cldr_routes`** — localized route helpers and path segments
* **`ex_cldr_html`** — locale-aware form helpers (select boxes for languages, territories, currencies, numbers)

All three fold into a single `localize_web` package that depends on `localize` and plugs into any Phoenix 1.7+ application.

## What's left before release

1. **Documentation.** Every public function has a moduledoc and function doc, but the tutorial content and the "getting started" guide need a pass. Same for the migration guide from the three old packages.
2. **Validation on real apps.** I want to upgrade at least three production Phoenix applications — my own and two volunteers — to shake out the edges before tagging a public version.
3. **The Locale Explorer.** A LiveView-based interactive explorer for CLDR data that ships inside `localize_web`. This is partially built; it needs a few more views and a polish pass. It is *not* blocking a first release — I'll ship `localize_web` 0.1 without it and add it in 0.2.

## A taste of the new plug API

The plug used to be configured indirectly through the backend:

```elixir
# Old
plug Cldr.Plug.AcceptLanguage, cldr_backend: MyApp.Cldr
plug Cldr.Plug.SetLocale,
  apps: [:cldr, :gettext],
  cldr: MyApp.Cldr,
  from: [:session, :accept_language]
```

In `localize_web` the plug is direct and backend-free:

```elixir
# New
plug Localize.Plug.SetLocale,
  from: [:session, :path, :cookie, :accept_language, :query, :host],
  gettext: MyAppWeb.Gettext
```

Everything it needs is either in the connection or in `Localize.Locale` itself. There's nothing compile-time, nothing to configure in `config.exs`, and the plug is no longer coupled to the concept of a backend module.

## Routes

The routes DSL keeps its shape but drops the backend:

```elixir
# New
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Localize.Routes

  localize ["en", "fr", "de", "ja"] do
    scope "/", MyAppWeb do
      get "/blog/:slug", BlogController, :show
    end
  end
end
```

Generated path helpers for each locale are available as `~p"/fr/blog/le-post"` and friends. There's a [longer post on routes](#) coming.

## HTML helpers

The HTML helpers look largely the same from a user's perspective:

```elixir
<.form for={@form}>
  <.input field={@form[:language]} type="select"
          options={Localize.HTML.language_options(locale: "en")} />
  <.input field={@form[:currency]} type="select"
          options={Localize.HTML.currency_options(locale: "fr")} />
</.form>
```

What changed is internal: the helpers build their option lists from locale data loaded on demand through Localize rather than from compiled-in tables, so you can switch between thousands of locales at runtime without ever touching a compile-time configuration.

## When can I use it?

The plan is unchanged: `localize`, `calendrical`, and a new major version of `ex_money` (6.0) will all be available for testing before the end of April 2026. `localize_web` will follow in the same window — likely the same weekend.

If you're interested in being one of the volunteer validation apps, [get in touch](https://github.com/elixir-localize/localize_web/issues/new).
