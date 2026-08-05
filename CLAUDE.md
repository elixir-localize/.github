# CLAUDE.md — elixir-localize blog

Project-specific instructions. These override the global standards where they differ.

## What this repository is

This is the content repository for the Localize blog at [blog.localize.dev](https://blog.localize.dev). It holds markdown posts in `priv/posts/`, site configuration in `config/config.exs`, and a single thin module in `lib/localize_blog.ex` that hands those posts to the site generator.

It is not a library and is not published to hex. The blog engine — Mix tasks, templates, feed and sitemap generation, the R2 publisher — lives in the [static_blog](https://hex.pm/packages/static_blog) package and is consumed as an ordinary hex dependency. Engine changes belong in that repository, not this one.

## Definition of done

This project is content-only, so the standard six-gate checklist does not apply. A change here is complete when these pass on the mise-current toolchain:

* `mix format --check-formatted` — exit 0.

* `mix compile --warnings-as-errors` — no project warnings.

* `mix blog.build` — the site builds, and the rendered output in `_site/` is correct.

`mix blog.build` is the meaningful check. It is the only gate that exercises the markdown pipeline end to end, so run it on any change that touches posts, configuration, or dependencies — and look at the generated HTML, not just the exit code.

## No credo, no dialyzer, no test suite

These are intentionally absent and should not be added, nor flagged as missing:

* **No `credo`** and no `.credo.exs`. There is almost no code here to lint.

* **No `dialyzer`**. One module with two functions does not justify a PLT build.

* **No test suite.** `test/` contains only `test_helper.exs`, so `mix test` exits 0 without running anything. Do not treat that green result as evidence a change works — it attests to nothing. Verify with `mix blog.build` and inspect the output instead.

* **No `ex_doc`.** Nothing here is published, so there are no docs to generate. The user-facing documentation of the stack is the colophon in `config/config.exs`; keep it accurate when dependencies change.

If this repository ever grows real logic, revisit this — but the expectation is that it stays text.

## Verifying rendered output

`_site/` is gitignored, so a rebuild cannot be diffed against git. To confirm the markdown pipeline is intact, compare structural counts in the source against the generated HTML — fenced code blocks to `<pre>`, inline code spans to `<code>` — rather than eyeballing the build summary. This is how a silent markdown-engine regression gets caught.
