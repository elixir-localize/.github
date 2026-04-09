%{
  title: "Twenty-eight into three: why Localize collapses the ex_cldr family",
  author: "Kip Cole",
  tags: ["ex_cldr", "localize", "packaging"],
  description: "Eight years of ex_cldr produced twenty-eight packages. Localize collapses them into three. Here is what changes, and why.",
  updated: "2026-04-09T18:48:16Z"
}
---
EDIT EDIT AGAIN EDIT
When I started `ex_cldr` in 2018 the plan was modest: wrap the Unicode CLDR data in a way Elixir applications could actually use. Eight years later there are [twenty-eight repositories](https://github.com/orgs/elixir-cldr/repositories) in the org. That's the kind of number that demands an explanation.

## How we got here

Two decisions, both reasonable at the time, compounded:

1. **Split by feature.** Numbers, dates, units, currencies, lists, plural rules, messages, HTML helpers, plugs, routes — each became a library so that applications could depend on only what they needed. Compile times for small apps stayed manageable, and a bug in the units formatter didn't require cutting a release of the number formatter.

2. **Split calendars by calendar.** The CLDR calendar machinery is large, and each non-Gregorian calendar (Coptic, Ethiopic, Islamic, Japanese, Persian, …) was published as its own package so applications could avoid pulling in calendars they would never use.

Add a handful of SQL integrations (`ex_money_sql`, `ex_cldr_units_sql`, `ex_cldr_trans`) and a few meta-packages for plugs and routes, and the count climbs quickly.

## Why it's a problem now

* **Discoverability.** New users consistently ask *"which packages do I actually need?"* The split that made sense to me as a maintainer was confusing to everyone else.
* **Version churn.** A CLDR release touches almost every package. Coordinating twenty-eight version bumps is not a maintenance win — it's a maintenance *tax*.
* **Cross-cutting changes.** Improvements that span packages — error handling, for example, or the locale loader — require PRs in half a dozen places. Things drift.
* **Dependency graphs.** Users regularly end up with three different versions of `ex_cldr` in their dep tree because intermediate libraries pin different bounds.

## The new packaging

Localize ships as **three** packages:

```elixir
defp deps do
  [
    {:localize, "~> 1.0"},
    {:localize_web, "~> 1.0"},    # optional — if you run a Phoenix app
    {:localize_sql, "~> 1.0"}     # optional — if you persist money/units
  ]
end
```

That's it.

`localize` absorbs the functionality of `ex_cldr`, `ex_cldr_numbers`, `ex_cldr_dates_times`, `ex_cldr_calendars` (and every calendar dependent), `ex_cldr_currencies`, `ex_cldr_units`, `ex_cldr_person_names`, `ex_cldr_locale_display`, `ex_cldr_messages`, `ex_cldr_lists`, `ex_cldr_languages`, and `ex_cldr_territories`.

`localize_web` absorbs `ex_cldr_routes`, `ex_cldr_plugs`, and `ex_cldr_html`. It will also host the new Phoenix-based Locale Explorer.

`localize_sql` absorbs `ex_units_sql` and `ex_cldr_trans`.

## But won't it be bigger?

A little bigger on disk, yes. But the old approach of splitting by feature never actually paid off in memory — compiled locale data dominates the footprint, and you always needed CLDR's core anyway. In practice the extra modules you pull in with `:localize` weigh almost nothing next to the locale data they reference.

And the bigger number — **1.6 MB of persistent-term storage per loaded locale** — is entirely independent of how many packages the code lives in. We were never paying that cost at the packaging layer.

## Calendars in particular

Calendrical has its own post coming, but the short version: all calendar libraries fold into a single package called `calendrical`. `localize` depends on it. Application code no longer configures `:cldr_calendars_coptic` or `:cldr_calendars_japanese` — the calendars are simply *there*, available when you ask for them, with their data loaded on first use via the same mechanism that handles locales.

## Migration

Localize is **not** a drop-in replacement. The core function signatures are mostly preserved, but:

* The `backend` argument is gone everywhere (no more compile-time backends).
* `Cldr.*` modules become `Localize.*`.
* Errors are proper exception structs instead of `{:error, {Module, "text"}}` tuples.
* Some configuration keys move from `:ex_cldr` to `:localize`.

A migration guide is in the works. If you're a heavy `ex_cldr` user and you'd like to try the alpha, get in touch — concrete feedback on specific codebases is the fastest way to find the rough edges.
