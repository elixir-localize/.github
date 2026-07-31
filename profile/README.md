# Elixir Localize

Next-generation internationalization and localization for the Elixir language, built on [Unicode CLDR](https://cldr.unicode.org).

This organization is the home of the successor to the [ex_cldr](https://github.com/elixir-cldr) family of libraries. Where `ex_cldr` comprised 28 separate packages with compile-time backend generation, the `elixir-localize` libraries consolidate that functionality into a smaller set of cohesive packages with runtime locale loading, no compile-time configuration, and faster build times.

## Key Repositories

### [localize](https://github.com/elixir-localize/localize)

The core localization library. Provides locale-aware formatting and operations for numbers, currencies, dates and times, units, lists, message formats, locale display names, and more. Consolidates the functionality of `ex_cldr`, `ex_cldr_numbers`, `ex_cldr_currencies`, `ex_cldr_dates_times`, `ex_cldr_units`, `ex_cldr_lists`, `ex_cldr_locale_display`, and `ex_cldr_messages` into a single package.

### [calendrical](https://github.com/elixir-localize/calendrical)

A unified calendar library supporting the Gregorian, Coptic, Ethiopic, Japanese, Persian, and lunisolar calendar systems, together with composite calendars and calendar-aware formatting. Replaces the separate `ex_cldr_calendar_*` packages.

### [localize_web](https://github.com/elixir-localize/localize_web)

Phoenix and Plug integration for `localize`. Provides locale negotiation plugs, HTML helpers, and localized routing. Consolidates `ex_cldr_plugs`, `ex_cldr_html`, and `ex_cldr_routes`, and will host a LiveView-based interactive locale explorer.

### [intl](https://github.com/elixir-localize/intl)

A thin shim over `localize` that mirrors the JavaScript [Intl](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl) API — `Intl.NumberFormat`, `Intl.DateTimeFormat`, `Intl.ListFormat`, `Intl.DisplayNames`, `Intl.RelativeTimeFormat`, `Intl.PluralRules`, `Intl.Collator`, `Intl.DurationFormat`, and `Intl.Segmenter`. Module names, function purposes, and option names mirror their JS counterparts, adapted to idiomatic Elixir conventions (snake_case options, `{:ok, result}` / `{:error, reason}` tuples). Useful for developers moving between Elixir and JavaScript, or for porting existing code that targets `Intl`.

### [unity](https://github.com/elixir-localize/unity)

A unit conversion calculator inspired by the Unix `units` utility, usable as a library, an escript, or an interactive REPL. Parses and evaluates unit expressions — `3 meters to feet`, `1 gallon + 2 litres`, `100 celsius to fahrenheit` — with dimensional analysis, and formats results through `localize`, so output follows the user's locale conventions. Can import GNU units definition files to extend the unit set.

### [localize_person_names](https://github.com/elixir-localize/localize_person_names)

Locale-aware formatting of personal names following the CLDR person name specification. Handles ordering, given/surname conventions, honorifics, and script-specific display rules across locales.

### [localize_phone_number](https://github.com/elixir-localize/localize_phone_number)

Parsing, validation, and formatting of international phone numbers using Google's [libphonenumber](https://github.com/google/libphonenumber) metadata, integrated with `localize` for locale-aware display.

### [localize_address](https://github.com/elixir-localize/localize_address)

Locale-aware postal address parsing, validation, and formatting based on the CLDR and Google address metadata, including country-specific field ordering and required components.

### [localize_sql](https://github.com/elixir-localize/localize_sql)

SQL database support for Ecto, in two parts. First, locale-aware PostgreSQL ICU collation: the `collate/1,2` macros apply a `COLLATE` clause — resolved from a Localize language tag by CLDR language matching — to query expressions and comparisons, so results sort and compare by the conventions of the user's locale. Migration helpers create the ICU collations PostgreSQL does not preload (for example German phonebook order, `de-u-co-phonebk`, or case-insensitive and natural-sort collations) and build collation-matched indexes.

Second, Ecto types for the Localize and Elixir data types worth storing structurally rather than flattening to a string: units of measure and money as composite types with database-side aggregates (`sum`, `min`, `max`, `avg`) and arithmetic operators, plus currencies, language tags, territories, scripts, integer and date ranges, and durations. [ex_money_sql](https://github.com/kipcole9/money_sql) builds its money support on the same shared DDL machinery.

### [localize_translate](https://github.com/elixir-localize/localize_translate)

Embeds translations directly into Ecto schemas, storing all of a record's translations in a single JSONB column rather than a separate translations table — avoiding the extra tables and JOINs of the traditional approach. `Localize.Translate` provides the `use` macro for translatable schemas and runtime `translate/2,3` functions with CLDR parent-chain fallback, while the optional `Localize.Translate.QueryBuilder` adds `Ecto.Query` macros for filtering and selecting on translated values in SQL. Continues the work of [`trans`](https://github.com/crbelaus/trans) and [`ex_cldr_trans`](https://github.com/elixir-cldr/cldr_trans) within the `localize` ecosystem.

## Form & User Input Libraries

A family of Phoenix LiveView components for locale-aware form inputs. The components share a common CSS token set, Gettext catalog, and structured validation errors so they look and behave consistently when used together. Server-side parsers accept whatever the user types in their locale's conventions (digit shaping, group/decimal separators, calendar systems, date patterns) and the JS hooks degrade gracefully when their optional peer dependencies are not loaded.

### [localize_inputs_core](https://github.com/elixir-localize/localize_inputs_core)

Shared foundation for the input component family. Hosts the `Localize.Inputs.ValidationError` exception, the `Localize.Inputs.Gettext` backend with shared UI strings (button labels, ARIA labels), and the `--li-*` CSS variable tokens for light and dark mode. You usually don't depend on this directly — it is pulled in transitively by the sibling component packages.

### [localize_number_inputs](https://github.com/elixir-localize/localize_number_inputs)

Locale-aware number-like form inputs for Phoenix LiveView. Provides `<.number_input>` for decimal and integer values with cursor-preserving live formatting via [AutoNumeric](https://autonumeric.org), and `<.unit_input>` paired with a searchable `<.unit_picker>` covering CLDR units of measure (length, mass, volume, …) with locale-specific preferred unit systems (metric, US, UK) and localized unit names.

### [localize_datetime_inputs](https://github.com/elixir-localize/localize_datetime_inputs)

Locale-aware date form inputs for Phoenix LiveView. Provides `<.date_input>` with a popup calendar grid that accepts the locale's CLDR short, medium, long, and full date patterns as well as ISO-8601, plus `<.date_range_input>` and `<.date_range_picker>` for two-date selection with min/max, span, and weekday restrictions. Multi-calendar support (Gregorian, Buddhist, Japanese imperial, Islamic, Persian, Hebrew, ROC, …) is provided through [calendrical](https://github.com/elixir-localize/calendrical), so users can type dates in their locale's calendar and the server parses them correctly.

### [localize_inputs_playground](https://github.com/elixir-localize/localize_inputs_playground)

A standalone deployment wrapper that demonstrates the input components across every CLDR locale, with tabs for input behaviour, server-side parsing, formatting, and locale data. The live instance runs at [localize-inputs-playground.fly.dev](https://localize-inputs-playground.fly.dev). The package can also be embedded into a host Phoenix application's dev router as a `forward` route for local experimentation.

## BEAM Language Bindings

`localize` is a plain BEAM library, so any language that compiles to the BEAM can call it directly — there is no foreign runtime to bridge and no FFI overhead. These packages exist purely for ergonomics: each shapes arguments and results the way its host language expects, so callers write idiomatic code instead of reaching across into Elixir modules by hand.

### [localize_lua](https://github.com/elixir-localize/localize_lua)

Locale-aware formatting for the [Lua](https://hexdocs.pm/lua) (Luerl) VM. Installs a small `localize` table into a Luerl VM so Lua scripts — such as templates rendered by a CMS — can format numbers, currencies, dates, times, units, lists, and MessageFormat 2 messages. The exposed surface is a curated allowlist of pure formatting functions with no filesystem or network access, making it safe to hand to untrusted template authors.

### [localize_lfe](https://github.com/elixir-localize/localize_lfe)

Idiomatic [LFE](https://lfe.io) bindings. The `localize` module speaks LFE's own conventions — charlists, atoms, Erlang date/time tuples, and lisp-case option keys — so lispers write `(localize:currency 1234.56 "EUR")` and the library handles the charlist/binary/atom coercion Localize expects.

### [localize_erl](https://github.com/elixir-localize/localize_erl)

Idiomatic Erlang bindings, exposed as small per-concern modules (`localize_number`, `localize_currency`, `localize_date`, `localize_collation`, …). Binaries in and out, maps for options, Erlang date/time tuples, and `{ok, Binary} | {error, {Tag, Message}}` returns that translate Localize's Elixir exceptions into ordinary Erlang error terms.

### [localize_gleam](https://github.com/elixir-localize/localize_gleam)

Type-safe [Gleam](https://gleam.run) bindings. Options are a typed `Options` record built with record-update syntax, and every fallible call returns a `Result(String, LocalizeError)` whose error is a union you can pattern-match (`InvalidLocale`, `InvalidDate`, `UnknownCurrency`, …). Localize's `{ok, _}`/`{error, _}` maps straight onto Gleam's `Result`.

## Agent Tooling

### [localize_mcp](https://github.com/elixir-localize/localize_mcp)

A Model Context Protocol (MCP) server that exposes the Localize API surface to AI agents — Claude Code, Claude Desktop, Codex, Zed, and any other MCP host. Structured tools cover documentation search and browsing, curated examples, formatter options, closed atom collections, locale resolution, and a whitelisted read-only invocation tool, all backed by BEAM introspection of the exact package versions the host project pins. The optional companions (`calendrical`, `localize_web`, `localize_sql`) are detected at boot and their APIs surfaced when present.

### Claude Code skill

The [localize](https://github.com/elixir-localize/localize) repository ships a [Claude Code skill](https://github.com/elixir-localize/localize/blob/main/skills/localize/SKILL.md) that teaches Claude the library's APIs and localization-first patterns — plural-correct messages instead of string interpolation, locale-aware formatting instead of `Calendar.strftime/3`, collation instead of raw `Enum.sort/1` — with every example execution-verified against the library. Install it as a plugin with `/plugin marketplace add elixir-localize/localize` followed by `/plugin install localize@localize`.

## Design Goals

* **No backend modules.** Locale data is loaded at runtime into [`:persistent_term`](https://www.erlang.org/doc/apps/erts/persistent_term.html) for fast access, removing the compile-time backend generation used by `ex_cldr`.

* **No compile-time configuration.** Locales can be added, loaded, or downloaded dynamically at runtime. Locale data is distributed in Erlang term format, so no JSON decoder dependency is required.

* **Pluggable locale storage and loading.** The default downloads locale data on demand, but custom loaders and stores are supported for resource-constrained devices, air-gapped environments, or organizations with bespoke data requirements.

* **Idiomatic errors.** Errors are returned as `{:error, Exception.t()}` with structured exception data, replacing the `{:error, {module, message}}` tuples used in `ex_cldr`.

* **Simpler packaging.** A small number of focused libraries rather than 28 separately versioned packages.

## Relationship to ex_cldr

The `ex_cldr` libraries remain supported and will continue to receive maintenance updates. `elixir-localize` is a parallel next-generation codebase rather than a drop-in replacement — most public function signatures are preserved, but the removal of the backend argument and the change in error format mean that migration requires code changes. Migration guides will accompany each library's first stable release.

## Requirements

* Elixir 1.17 or later
* Erlang/OTP 26 or later

## Status

The core libraries reached 1.0 in July 2026 and are published on hex.pm: `localize`, `calendrical`, `intl`, `unity`, `localize_sql`, `localize_web`, `localize_address`, `localize_phone_number` and `localize_person_names`. The form input components and the MCP server are published and still pre-1.0. Development remains active.
