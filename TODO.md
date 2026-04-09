# TODO

Follow-up work and known limitations for the Localize blog engine.

## Known limitations

### MarsEdit: "Published Date" and "Edited Date" columns are always empty

MarsEdit's Title List view offers "Published Date" and "Edited Date" columns for blogs configured with the **Micropub** / **Micro.blog** system type, but they do not populate for our blog no matter what we put in the XML-RPC response.

The `microblog.getPosts` response we send includes nine different well-formed XML-RPC datetime fields on every post, all sharing the same underlying `published_at` / `updated_at` values:

* `dateCreated`, `date_created_gmt`, `pubDate`
* `dateModified`, `date_modified_gmt`
* `post_date`, `post_date_gmt`
* `post_modified`, `post_modified_gmt`

We tried three serialisation formats for the `<dateTime.iso8601>` payload:

1. `20260409T12:00:00` — XML-RPC basic format, matches WordPress exactly.
2. `2026-04-09T12:00:00` — extended ISO 8601 without timezone.
3. `2026-04-09T12:00:00Z` — extended ISO 8601 with UTC suffix.

None of them caused the columns to populate. MarsEdit's `microblog.editPost` requests echo the post's `postid` as `<string>…</string>`, so we also matched that type and return `<string>` ids now to avoid any parser-bail-out path.

Other fields from the same response (title, post_status including draft → publish roundtrip, categories, mt_keywords, description) do reach the UI correctly, so the response is structurally valid and MarsEdit's struct parser is not crashing on it. The date data is present on the wire and XMLRPC.decode/1 round-trips it cleanly in our own tests.

Tentative conclusion: MarsEdit's list-view columns for the Micro.blog / Micropub blog type probably read dates from a source other than the XML-RPC `microblog.getPosts` response — most likely the micro.blog JSON Feed endpoint or a Micropub `?q=source` query — and are not wired to the XML-RPC date fields at all. This matches the broader observation that MarsEdit's Micro.blog type is a hybrid: XML-RPC for writes, but metadata sources borrowed from elsewhere.

**Workaround:** none needed in day-to-day use. The published/updated timestamps are stored correctly in every post's frontmatter (`published:` and `updated:` ISO 8601 lines in `priv/posts/*.md`), they appear in the rendered static site, they populate the RSS feed's `<pubDate>`, and MarsEdit does see them inside the post editor (just not in the column). All downstream systems have the data.

**Next steps when time allows:**

1. Capture a microblog.getPosts response from a real micro.blog account (using any existing micro.blog test blog) and diff it field-by-field against ours. Look specifically for fields we might be missing and any differences in datetime formatting — e.g. micro.blog might send dates as ISO strings in a `<string>` element rather than `<dateTime.iso8601>`.
2. Alternatively, stand up a minimal Micropub `?q=source&url=…` endpoint on the XML-RPC path to see if MarsEdit falls through to it for date display.
3. Consider opening a support ticket with Red Sweater (MarsEdit's maker) asking which fields the list-view date columns bind to for Micro.blog blogs.

### Post 2026-04-07-localize-web-code-complete.md has HTML where markdown should be

During MarsEdit editing experiments the rich-text-mode save path overwrote the original markdown body of this post with its HTML equivalent. We subsequently fixed the roundtrip (plain-text mode + markdown-body in `description`) so this will not happen to new edits.

**Fix:** `git checkout priv/posts/2026-04-07-localize-web-code-complete.md` to restore the original markdown source from git.

## Feature ideas

* **Pull the compiler warnings from NimblePublisher highlighter.** The compile-time `ElixirLocalize` module emits "Failed to find closing <pre>" warnings when it encounters the HTML-polluted `2026-04-07-localize-web-code-complete.md` post. These will clear up as soon as that file is restored.

* **Media / image uploads.** MarsEdit can send photo attachments via multipart; Micropub's media endpoint spec supports this. We currently have no media endpoint. If this becomes desirable, implement `POST /micropub/media` to accept image uploads, store them under `priv/static/media/YYYY/MM/`, and return the resulting URL in the `Location` header.

* **`mt_excerpt` as a source of truth for `:description`.** Currently MarsEdit's "Excerpt" field populates `mt_excerpt` which we store in `:description`. This roundtrips correctly, but we don't do anything with the description in the rendered site beyond the RSS summary fallback. Worth surfacing on post pages if it differs from the first paragraph.

* **Category taxonomy.** Right now MarsEdit's "Categories" checklist and "Tags" text field both write into our single flat `:tags` list. WordPress treats them as distinct hierarchies. If the blog grows enough to need real categories, split into `:categories` and `:tags` and map accordingly on read/write.

* **Post previewing from MarsEdit.** MarsEdit's preview window fetches a URL template. We should document the right URL pattern (`http://localhost:4000/posts/<slug>/`) in the blog setup instructions so the preview shows the local staged version.

* **Tests covering the XML-RPC layer.** `ElixirLocalize.Micropub` is covered, but `ElixirLocalize.Web.XmlRpc` dispatching is only smoke-tested via curl. A handful of ExUnit tests feeding crafted method calls through the router would catch regressions in the post shape.

* **Authentication hardening.** The server currently accepts `LOCALIZE_BLOG_TOKEN` from the environment for both bearer (Micropub) and Basic Auth (XML-RPC). For public deployment this should move to a secret store, rotate, and support multiple tokens.
