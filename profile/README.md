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

### [localize_person_names](https://github.com/elixir-localize/localize_person_names)

Locale-aware formatting of personal names following the CLDR person name specification. Handles ordering, given/surname conventions, honorifics, and script-specific display rules across locales.

### [localize_phonenumber](https://github.com/elixir-localize/localize_phonenumber)

Parsing, validation, and formatting of international phone numbers using Google's [libphonenumber](https://github.com/google/libphonenumber) metadata, integrated with `localize` for locale-aware display.

### [localize_address](https://github.com/elixir-localize/localize_address)

Locale-aware postal address parsing, validation, and formatting based on the CLDR and Google address metadata, including country-specific field ordering and required components.

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
