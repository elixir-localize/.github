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

A thin wrapper over `localize` that mirrors the JavaScript [Intl](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl) API. Useful for developers moving between Elixir and JavaScript, or for porting existing code that targets `Intl`.

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

The libraries are under active development and have been released to hex.pm.
