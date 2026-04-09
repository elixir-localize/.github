%{
  title: "Calendrical: one package for all the calendars",
  author: "Kip Cole",
  tags: ~w(calendrical calendars localize packaging),
  description: "The calendar packages scattered across the elixir-cldr org are consolidating into a single library called calendrical. Here is what it includes and how it fits with Localize."
}
---

`ex_cldr` has always had good calendar support, but "good" in this context meant "spread across eight packages." If you wanted the Japanese Imperial calendar you added `ex_cldr_calendars_japanese`. Persian calendar? `ex_cldr_calendars_persian`. And so on for Coptic, Ethiopic, Islamic, Lunisolar, and the calendar formatting and composite layers on top.

That's over now. Every calendar-related library in the org is folding into a single package: **[calendrical](https://github.com/elixir-localize/calendrical)**.

## What's in the box

The consolidated `calendrical` package includes:

* The base CLDR calendar machinery (formerly `ex_cldr_calendars`)
* All of the non-Gregorian calendars:
  - Coptic (formerly `ex_cldr_calendars_coptic`)
  - Ethiopic (formerly `ex_cldr_calendars_ethiopic`)
  - Islamic (formerly `ex_cldr_calendars_islamic`)
  - Japanese Imperial (formerly `ex_cldr_calendars_japanese`)
  - Lunisolar calendars: Chinese, Korean, Vietnamese, Hebrew (formerly `ex_cldr_calendars_lunisolar`)
  - Persian / Solar Hijri (formerly `ex_cldr_calendars_persian`)
* Composite calendars (formerly `ex_cldr_calendars_composite`)
* Formatting (formerly `ex_cldr_calendars_format`)

One package. One version. One changelog.

## Why now?

Two reasons, both pragmatic.

**Nobody wanted the split.** The split-by-calendar packaging was motivated by the theory that applications wanting only the Gregorian calendar shouldn't pay for calendars they didn't use. In practice almost nobody configured things that narrowly, and the cost of *maintaining* the split — coordinating releases, managing dependencies between calendar packages and the base package, keeping tests in sync — vastly exceeded any gain from the theoretical savings.

**Data-loading is now uniform.** With Localize's [runtime locale loading](/posts/runtime-locale-loading/), calendar data follows the same pattern as locale data: it lives as an Erlang term, gets loaded on demand, ends up in `:persistent_term`. There's no compile-time size cost to bundling the code for all calendars together. The data itself is only loaded for the calendars you use.

## How it fits with Localize

`calendrical` is a peer of `localize`, not a component of it. You can use it on its own:

```elixir
defp deps do
  [{:calendrical, "~> 1.0"}]
end
```

```elixir
iex> Calendrical.Japanese.today()
%Date{year: 8, month: 4, day: 9, calendar: Calendrical.Japanese}

iex> Calendrical.convert(~D[2026-04-09], from: Calendar.ISO, to: Calendrical.Persian)
{:ok, ~D[1405-01-20 Calendrical.Persian]}
```

`localize` depends on `calendrical` and uses it for date formatting, calendar-aware number parsing, and anything that needs a notion of "what day is it in this locale's preferred calendar?" But if all you need is calendar arithmetic — no localized formatting, no CLDR-driven layout — you can skip `localize` entirely and just pull in `calendrical`.

## Calendars as pluggable modules

Each calendar in `calendrical` implements the standard `Calendar` behaviour from Elixir's standard library, plus a `Calendrical.Calendar` extension for CLDR-shaped metadata (era names, cyclic year names, leap year rules, and so on).

That means a Japanese-calendar date is just a `Date` whose `:calendar` field is `Calendrical.Japanese`, and all the operations you already know — `Date.add/2`, `Date.diff/2`, `Date.compare/2` — work on it without any calendar-specific API.

## Status

`calendrical` is migrated and tests are passing. A new major version of `ex_money` (6.0) is also migrated and passing against `localize`. Both will be available for testing before the end of April 2026 along with `localize` itself. `localize_web` reached code-complete status this week — [separate post on that](/posts/localize-web-code-complete/).

If you want to try `calendrical` ahead of the public release, [open an issue](https://github.com/elixir-localize/calendrical/issues) and I'll point you at the alpha.
