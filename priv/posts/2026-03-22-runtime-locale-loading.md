%{
  title: "Runtime locale loading with :persistent_term",
  author: "Kip Cole",
  tags: ~w(localize architecture persistent_term),
  description: "Localize drops ex_cldr's compile-time backend modules in favour of loading locale data into :persistent_term at runtime. Here is how it works and what it buys you."
}
---

The single most visible change in Localize, compared with `ex_cldr`, is that the compile-time backend module is gone. You no longer write this:

```elixir
defmodule MyApp.Cldr do
  use Cldr,
    locales: ["en", "fr", "de", "ja"],
    default_locale: "en",
    providers: [Cldr.Number, Cldr.DateTime, Cldr.Calendar, Cldr.Unit]
end
```

You don't write anything. You call `Localize.Number.to_string/2` directly:

```elixir
iex> Localize.Number.to_string(1234.5, locale: "fr")
{:ok, "1 234,5"}
```

If the `"fr"` locale isn't already loaded, Localize loads it now.

## What does "load" mean?

In `ex_cldr`, a locale was a compile-time artefact: its data was baked into the backend module as function heads. The backend module was, functionally, a very large pattern-match table that took `locale, key` and returned data. That's fast — about as fast as Elixir function dispatch gets — but it means the data has to be known at compile time, and every change to the locale set triggers a recompile.

In Localize, a locale is a **runtime** artefact. When you ask for data from a locale:

1. We check `:persistent_term` for `{:localize, locale_name}`.
2. If it's there, we use it. This is the hot path and it's very nearly free — `:persistent_term` reads are a pointer dereference.
3. If it's not there, we fetch it. By default that means decoding an Erlang term from a file that ships with the library, but the loader is [pluggable](#pluggable-loaders) so you can fetch from disk, from a CDN, from an internal mirror, or bundle it with a release.
4. Once decoded, we call `:persistent_term.put/2` and continue.

Decoding is done once per locale, per node. `:persistent_term` was designed for exactly this shape of data: large, mostly-read, updated rarely.

## What about the code that was generated?

The compile-time backend didn't just hold data — it also generated **code**. Plural rules and [rule-based number formatting](https://unicode.org/reports/tr35/tr35-numbers.html#Rule-Based_Number_Formatting) in particular were compiled from their declarative CLDR form into native Elixir function heads. That generated code was *fast*.

Localize keeps the generated-code approach, but shifts it from compile time to load time. When a locale is first loaded, we build the pluralization and RBNF modules for that locale and compile them on the fly:

```elixir
# Simplified
defp compile_plural_module(locale, rules) do
  ast = Localize.Plural.Compiler.build(locale, rules)
  [{module, bytecode}] = Code.compile_quoted(ast)
  :code.load_binary(module, ~c"localize_runtime", bytecode)
end
```

On a typical developer laptop, compiling the pluralization module for a new locale takes a few milliseconds. Loading the locale data itself takes most of the rest of the hundred-ish milliseconds a cold locale costs. Every subsequent use of that locale is at the same speed as the old backend-compiled code.

## What you get

* **Compile time.** A Phoenix app that previously took sixty seconds to compile because it had forty locales configured now takes ten. All the locale work has moved to runtime.
* **No compile-time configuration.** You do not have to declare your locales in `mix.exs` or in a backend module. Ask for a locale and you get it.
* **Dynamic locales.** A deployed application can start using a new locale — one that wasn't known at release time — without a redeploy. For content sites adding market coverage this matters.
* **Shorter feedback loop.** Changes to locale configuration don't trigger a recompile.

## What you give up

* **Cold-start latency.** The first use of a locale costs ~100 ms. Not a lot, but not nothing. For applications that need predictable latency on every request, Localize provides `Localize.preload/1` which accepts a list of locale names and loads them at application start.
* **Observability of "what's compiled."** With `ex_cldr`, the backend module was right there in your app and you could see every locale you'd configured. With Localize it's all in `:persistent_term`. We expose `Localize.loaded_locales/0` and `Localize.preloaded?/1` to compensate.

## Pluggable loaders

By default the `Localize` loader reads pre-serialised Erlang term files that ship inside the `localize` hex package. That's the right default for most applications.

Some applications benefit from a different strategy:

```elixir
config :localize, :loader, MyApp.Localize.S3Loader
```

The loader behaviour is three functions: `list/0`, `fetch/1`, and `store/2`. We ship `Localize.Loader.Bundled` (the default), `Localize.Loader.HTTP` (for CDN delivery), and `Localize.Loader.File` (for on-disk caches). An organisation with a security posture that forbids arbitrary network access at runtime can write a loader that reads from an internal mirror; a resource-constrained embedded deployment can write one that keeps locale data on an SD card and uses a small LRU in place of `:persistent_term`.

## Are we sure this is faster?

For the hot path — the part that runs millions of times under production load — the answer is *yes* and the benchmarks are boring. `:persistent_term.get/1` followed by pattern matching on the result is within the margin of noise of the old generated-function dispatch. I will post numbers in a future benchmark post.

For the cold path, Localize is slower than `ex_cldr`, by about a hundred milliseconds per uncached locale. That's the deliberate trade: a one-time runtime cost in exchange for removing the compile-time cost altogether.

For most applications, that trade is the right one.
