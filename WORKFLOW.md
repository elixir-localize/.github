# Blog Workflow

This document describes how the Localize blog is authored, previewed, edited from MarsEdit, built to static HTML, and published to Cloudflare R2.

## The big picture

The blog is a static-site generator written in Elixir. The source of truth is a directory of markdown files at `priv/posts/`. A set of Mix tasks read those files, render them through HEEx templates into a `_site/` directory, and optionally upload the result to an R2 bucket. A long-running HTTP server (Bandit + Plug) exposes a Micropub/XML-RPC endpoint so MarsEdit can edit posts directly against the live filesystem.

```
                  +---------------------------+
                  |   priv/posts/*.md         |   <- source of truth
                  +---------------------------+
                          |            ^
                          |            | write (on save)
               read (on build/refresh) |
                          v            |
  +------------------+----+----+---+---+------------+
  |  mix blog.build  | mix blog. |  mix blog.server |
  |  (static site)   |  serve    |  (MarsEdit API)  |
  +---------+--------+-----+-----+------+-----------+
            |              |            |
            v              v            v
       _site/        http://localhost  http://localhost
       (HTML +      :4000 (preview)    :4010/micropub
        css +                          (XML-RPC + Micropub)
        feed.xml)
            |
            v
  +-------------------+
  |  mix blog.publish |   -> R2 bucket "blog"
  +-------------------+
```

## Prerequisites

* Elixir 1.17+ and Erlang/OTP 26+
* For publishing: Cloudflare R2 credentials in the environment
* For MarsEdit editing: MarsEdit 5+ and a bearer token in the environment

## Environment variables

| Variable | Purpose | When needed |
|---|---|---|
| `LOCALIZE_BLOG_TOKEN` | Bearer token (Micropub) + Basic Auth password (XML-RPC) for MarsEdit | `mix blog.server` |
| `R2_ACCOUNT_ID` | Cloudflare account id | `mix blog.publish` |
| `R2_ACCESS_KEY_ID` | R2 S3-compatible access key | `mix blog.publish` |
| `R2_SECRET_ACCESS_KEY` | R2 S3-compatible secret | `mix blog.publish` |

A sensible development setup:

```sh
export LOCALIZE_BLOG_TOKEN=$(openssl rand -hex 32)
export R2_ACCOUNT_ID=...
export R2_ACCESS_KEY_ID=...
export R2_SECRET_ACCESS_KEY=...
```

## Writing a post by hand

Create a new file `priv/posts/YYYY-MM-DD-slug.md`:

```markdown
%{
  title: "Post title",
  author: "Kip Cole",
  tags: ["localize", "release"],
  description: "A short summary that appears in the index and RSS feed."
}
---
The body goes here as markdown.

## Sections work

```elixir
def example, do: "Syntax-highlighted code blocks are supported."
```
```

Optional frontmatter fields:

* `status: "draft"` — keeps the post visible to editing clients but excludes it from the rendered `_site/` and the RSS feed.
* `published: "2026-04-09T14:30:00Z"` — explicit publish datetime. Defaults to `<filename-date>T12:00:00Z` if absent.
* `updated: "2026-04-09T18:00:00Z"` — last edit datetime. Defaults to `published_at`. MarsEdit and the Micropub endpoint bump this automatically on every save.

## Building the static site

```sh
mix blog.build
```

Reads every file in `priv/posts/`, filters out drafts, runs each post through `Earmark` and `Makeup` for syntax highlighting, and renders everything into `_site/` via the HEEx templates in `lib/elixir_localize/components.ex` and `templates.ex`. Also writes `_site/feed.xml` (RSS 2.0), `_site/css/site.css`, `_site/favicon.svg`, `_site/robots.txt`, and `_site/colophon/index.html`.

Run this any time you want to eyeball the output, or before publishing.

### Optional: build into a different directory

```sh
mix blog.build --output /tmp/preview
```

## Previewing locally

Two servers are available, on different ports, for different purposes.

### `mix blog.serve` — port 4000, for browser preview

```sh
mix blog.serve
```

A tiny Erlang `inets` server that serves the contents of `_site/` as static files on `http://localhost:4000/`. No authentication, no editing API, no markdown parsing — just files off disk.

Use this to read the blog in a browser exactly as readers will see it after publishing. Especially useful for:

* Verifying the layout works at various screen sizes
* Checking the colophon page
* Testing dark mode toggle
* Validating the RSS feed in a feed reader

This server does not watch for file changes. When you edit markdown, run `mix blog.build` again and refresh the browser.

### `mix blog.server` — port 4010, for MarsEdit editing

```sh
mix blog.server
```

A Bandit + Plug.Router server exposing the Micropub (`POST /micropub`) and XML-RPC (same path, different Content-Type) endpoints so MarsEdit can list, create, edit, and delete posts.

This server:

1. Refuses to start without `LOCALIZE_BLOG_TOKEN` in the environment.
2. Runs `mix blog.build` on startup so `_site/` is fresh.
3. Rebuilds `_site/` after every successful create / update / delete.
4. Overrides the `<link rel="micropub">` URL in the built HTML to point at `http://localhost:4010/micropub` (so MarsEdit autodetection from port 4000 discovers the editing endpoint on port 4010).

`mix blog.publish` run later from a fresh shell will rebuild with the production URL so nothing from local dev leaks into what ships.

Typical editing loop:

1. `mix blog.serve &` (preview on :4000)
2. `mix blog.server` (editing on :4010)
3. Open `http://localhost:4000/` in a browser — see the blog as it exists today.
4. Open MarsEdit — list, edit, save posts.
5. Every save triggers a rebuild, so refreshing the browser tab shows the new version.
6. When you're happy, run `mix blog.publish` to push.

## Editing from MarsEdit

One-time setup:

1. **File → New Blog**
2. For **System**, pick **Micropub** (or **Micro.blog** if your MarsEdit version doesn't list Micropub separately — they use the same XML-RPC shim).
3. **Endpoint URL:** `http://localhost:4010/micropub`
4. **Access Token:** paste your `LOCALIZE_BLOG_TOKEN` value.
5. MarsEdit may also prompt for **HTTP Username** and **HTTP Password**. Username can be anything (`admin`, `kip`, `x`); password must be the same `LOCALIZE_BLOG_TOKEN` value.
6. **Blog Name** is a local label; put whatever you like.
7. **IMPORTANT:** Set MarsEdit's editor mode to **Plain Text** (not Rich Text) in the blog's preferences. The server returns post bodies as raw markdown, and saving from rich-text mode would send HTML back and corrupt the source.

Running servers:

```sh
export LOCALIZE_BLOG_TOKEN=$(openssl rand -hex 32)
mix blog.server    # must be running before you refresh in MarsEdit
```

From MarsEdit you can then:

* **Refresh** — populates the post list
* **Edit** a post — loads the markdown into the editor
* **Save** — writes back to `priv/posts/` and triggers a rebuild; `updated:` frontmatter is bumped to now
* **Publish status → Draft** — writes `status: "draft"` into the frontmatter; the post disappears from the rendered site but stays in MarsEdit
* **Delete** — removes the markdown file entirely

MarsEdit's published date and edited date *columns* in the list view do not populate. This is a known limitation; see `TODO.md`. The data is present in the post detail view and in the underlying frontmatter.

## Publishing to Cloudflare R2

```sh
mix blog.publish
```

This:

1. Runs `mix blog.build` from scratch (with no local dev overrides, so URLs use `https://blog.localize.dev/...`).
2. Walks `_site/` and computes the MD5 of every file.
3. Calls `ListObjectsV2` on the R2 bucket (`blog`) to build a manifest.
4. PUTs any file that's missing remotely or whose MD5 differs from the remote ETag.
5. DELETEs any remote object that no longer exists locally.
6. Prints a summary of uploaded / skipped / deleted counts.

The upload is SigV4-signed using the `aws_signature` library and transported by `Req`. R2's S3-compatible endpoint is `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com/blog`.

### Skipping the rebuild

If you just ran `mix blog.build` manually and don't want to rebuild again:

```sh
mix blog.publish --skip-build
```

## Common flows

### "I want to write a quick post in my editor and publish it"

```sh
$EDITOR priv/posts/$(date +%Y-%m-%d)-my-slug.md
# write frontmatter + body
mix blog.publish
```

### "I want to iterate on a post with live preview"

```sh
# Terminal 1 — preview
mix blog.build
mix blog.serve

# Edit priv/posts/... in your editor
mix blog.build   # re-run after each save
# Refresh browser at http://localhost:4000/
```

### "I want to edit from MarsEdit"

```sh
# Terminal 1 — preview
mix blog.build
mix blog.serve &

# Terminal 2 — editing endpoint
export LOCALIZE_BLOG_TOKEN=$(cat ~/.localize-blog-token)
mix blog.server

# MarsEdit — refresh, edit, save
# Preview at http://localhost:4000/ stays current after every save
```

### "I want to take a post offline without deleting it"

Add `status: "draft"` to the frontmatter. Rebuild + publish. The file stays in `priv/posts/`, MarsEdit can still see and edit it, but it's gone from the public site and the RSS feed.

### "I want to restore a post I accidentally corrupted in MarsEdit"

```sh
git checkout priv/posts/YYYY-MM-DD-slug.md
mix blog.build
# If the blog.server is running, the rebuild happens automatically on next edit
```

## Files and directories

```
elixir-localize/
├── mix.exs
├── config/config.exs            # site title, author, base_url, R2 bucket
├── lib/
│   ├── elixir_localize.ex       # NimblePublisher compile-time post index
│   ├── elixir_localize/
│   │   ├── post.ex              # Post struct + frontmatter parser
│   │   ├── runtime_posts.ex     # Runtime FS post reader (for the server)
│   │   ├── micropub.ex          # Create / update / delete logic
│   │   ├── generator.ex         # Renders priv/posts/ into _site/
│   │   ├── templates.ex         # HEEx page templates
│   │   ├── components.ex        # HEEx layout + theme toggle
│   │   ├── rss.ex               # RSS 2.0 feed builder
│   │   ├── publisher.ex         # R2 upload via Req + SigV4
│   │   └── web/
│   │       ├── router.ex        # Plug.Router — /micropub, /favicon, /
│   │       ├── auth.ex          # Bearer token plug
│   │       ├── xml_rpc.ex       # microblog.* / metaWeblog.* / blogger.*
│   │       └── server.ex        # Bandit child spec
│   └── mix/tasks/
│       ├── blog.build.ex
│       ├── blog.serve.ex        # inets preview server
│       ├── blog.server.ex       # Bandit Micropub / XML-RPC server
│       └── blog.publish.ex
├── priv/
│   ├── posts/                   # <- source of truth, markdown files
│   └── static/
│       ├── css/site.css         # DF-inspired stylesheet, light + dark
│       └── favicon.svg
├── _site/                       # generated, gitignored
├── test/
├── README.md
├── TODO.md                      # follow-up items and known limitations
└── WORKFLOW.md                  # this file
```

## Ports at a glance

| Port  | Server              | Use                                  | Auth               |
|------:|---------------------|--------------------------------------|--------------------|
| 4000  | `mix blog.serve`    | Static preview of `_site/`           | none               |
| 4010  | `mix blog.server`   | Micropub + XML-RPC for MarsEdit      | Bearer token / Basic Auth |
