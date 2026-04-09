%{
  title: "Hello, Localize",
  author: "Kip Cole",
  tags: ~w(localize release),
  description: "A first note on the Localize blog — what Localize is, why we're rebuilding it, and what to expect here."
}
---

**Localize** is the next-generation localization library for Elixir. It builds on eight years of production experience with [ex_cldr](https://github.com/elixir-cldr), unifying more than two dozen packages into a single coherent library, and trading compile-time backends for runtime-loaded locale data stored in `:persistent_term`.

This blog is where we'll post development notes, release updates, design rationale, and the occasional tutorial. Short posts for status updates, longer ones for anything that warrants a proper walkthrough.

## Why rebuild?

`ex_cldr` works — it's been in production for years — but a few design decisions have aged less well than others:

* **Compile-time backends.** Generating a module per application drives fast runtime access, but the compile-time cost grows with the locale set, and changing configuration means recompiling.
* **Many packages.** Twenty-eight repositories split along data/feature lines made maintenance timely in theory and confusing in practice.
* **Structured errors as tuples.** Returning `{:error, {Module, "text"}}` predates a proper understanding of how Elixir exceptions are meant to be used.

Localize addresses all three. Locales load lazily at runtime into `:persistent_term`; packaging is unified into `localize`, `localize_web`, and `localize_sql`; errors are real `Exception` structs.

## A taste of the API

Here is a minimal number-formatting example in the new API. Note the absence of a backend argument:

```elixir
iex> Localize.Number.to_string(1_234_567.89, locale: "fr")
{:ok, "1 234 567,89"}

iex> Localize.Number.to_string(42, format: :currency, currency: :EUR, locale: "de")
{:ok, "42,00 €"}
```

Dates and times look similar:

```elixir
iex> Localize.DateTime.to_string(~U[2026-04-09 14:30:00Z], locale: "ja", format: :long)
{:ok, "2026年4月9日 14:30:00 UTC"}
```

## What to expect on this blog

* **Release notes** for each tagged version, with migration guidance from `ex_cldr`.
* **Design notes** on the bigger architectural choices — runtime locale loading, rule compilation, the plugin story for storage.
* **Deep dives** into specific CLDR features: RBNF, pluralization, units, message formatting.
* **Benchmarks** comparing Localize and its predecessors.

If there's anything you'd like to see covered, [open an issue](https://github.com/elixir-localize/localize) and let us know.
