/**
 * Cloudflare Worker that serves the Localize blog from an R2 bucket.
 *
 * All blog objects live under the `blog/` prefix in the `content` bucket.
 * This Worker maps incoming requests to the correct R2 key:
 *
 *   /                        → blog/index.html
 *   /posts/slug              → blog/posts/slug/index.html
 *   /posts/slug/             → blog/posts/slug/index.html
 *   /posts/slug/index.html   → blog/posts/slug/index.html
 *   /css/site.css             → blog/css/site.css
 *   /feed.xml                 → blog/feed.xml
 *
 * Paths that start with a known non-blog prefix (e.g. /locales/) are
 * passed through to R2 directly without the blog/ prefix, so other
 * content in the bucket is served as-is.
 *
 * It also sets security and caching headers on blog responses.
 */

const BLOG_PREFIX = "blog";

/**
 * Paths that should NOT be routed through the blog prefix. These are
 * served directly from the R2 bucket root. Add any other top-level
 * directories that share the bucket here.
 */
const PASSTHROUGH_PREFIXES = ["locales"];

/** Map file extensions to content types. */
const CONTENT_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json",
  ".xml": "application/rss+xml; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".webmanifest": "application/manifest+json",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".etf": "application/octet-stream",
};

/** Security and caching headers added to blog responses. */
const SECURITY_HEADERS = {
  "Strict-Transport-Security": "max-age=63072000; includeSubDomains; preload",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
};

function contentType(key) {
  const dot = key.lastIndexOf(".");
  if (dot === -1) return "application/octet-stream";
  return CONTENT_TYPES[key.slice(dot).toLowerCase()] || "application/octet-stream";
}

function cacheControl(key) {
  // Immutable assets (CSS, images, fonts) get long cache.
  // HTML, XML, manifest get short cache so updates propagate quickly.
  if (/\.(css|png|jpg|jpeg|gif|webp|svg|woff2?|ico)$/i.test(key)) {
    return "public, max-age=86400, stale-while-revalidate=3600";
  }
  return "public, max-age=60, stale-while-revalidate=30";
}

/**
 * Check if a path should bypass the blog prefix and be served
 * directly from the R2 bucket root.
 */
function isPassthrough(path) {
  for (const prefix of PASSTHROUGH_PREFIXES) {
    if (path === prefix || path.startsWith(prefix + "/")) {
      return true;
    }
  }
  return false;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let path = decodeURIComponent(url.pathname);

    // Strip leading slash.
    path = path.replace(/^\//, "");

    // ── Passthrough paths: serve directly from R2 root ──────────
    if (isPassthrough(path)) {
      const object = await env.BUCKET.get(path);

      if (object !== null) {
        const headers = new Headers();
        headers.set("Content-Type", contentType(path));
        headers.set("Cache-Control", "public, max-age=3600");
        headers.set("ETag", object.httpEtag);
        headers.set("X-Content-Type-Options", "nosniff");
        headers.set("Access-Control-Allow-Origin", "*");
        return new Response(object.body, { status: 200, headers });
      }

      return new Response("Not Found", { status: 404 });
    }

    // ── Blog paths: prepend blog/ prefix, try index.html fallback ──
    const candidates = [];

    if (path === "" || path === "/") {
      candidates.push("index.html");
    } else {
      // Remove trailing slash for uniform handling.
      const clean = path.replace(/\/+$/, "");
      candidates.push(clean);
      candidates.push(clean + "/index.html");
    }

    for (const candidate of candidates) {
      const key = BLOG_PREFIX + "/" + candidate;
      const object = await env.BUCKET.get(key);

      if (object !== null) {
        const headers = new Headers();
        headers.set("Content-Type", contentType(candidate));
        headers.set("Cache-Control", cacheControl(candidate));
        headers.set("ETag", object.httpEtag);

        for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
          headers.set(name, value);
        }

        // CSP: allow inline scripts (theme toggle) and inline styles.
        headers.set(
          "Content-Security-Policy",
          "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'"
        );

        return new Response(object.body, { status: 200, headers });
      }
    }

    // Nothing matched — serve the custom 404 page if it exists.
    const notFoundKey = BLOG_PREFIX + "/404.html";
    const notFoundObject = await env.BUCKET.get(notFoundKey);

    if (notFoundObject !== null) {
      const headers = new Headers();
      headers.set("Content-Type", "text/html; charset=utf-8");
      headers.set("Cache-Control", "no-cache");
      for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
        headers.set(name, value);
      }
      return new Response(notFoundObject.body, { status: 404, headers });
    }

    return new Response("Not Found", { status: 404 });
  },
};
