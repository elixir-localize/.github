# Next Generation Localization for the Elixir language

`Localize` is a localization library leveraging the content built and maintained by [Unicode's](unicode.org) [CLDR](https://cldr.unicode.org) project.  It is the next-generation version of [ex_cldr](https://github.com/elixir-cldr).

## Status

`Localize` is under active development with a first version expected to be available for use by the end of March 2026.  Not all functionality of `ex_cldr` will be available in the first release.

The release plan is currently:

1. v0.1 contains the functionality of `ex_cldr`, `ex_cldr_currencies`, `ex_cldr_numbers` and `ex_cldr_lists`.
2. v0.2 adds the functionality of `ex_cldr_calendars` (and dependent calendars) and `ex_cldr_dates_times`.
3. v0.3 adds `ex_cldr_units` which will be largely re-implemented.

## Migration from `ex_cldr`

`Localize` is not a drop-in replacement for `ex_cldr`. Code changes will be required. However the public API will retain the majority of the function signatures. The main visible change to function signatures is the removal of the `backend` argument since `Localize` is not based upon a compile-time generated backend architecture.

## Architecture changes in Localize

Localize is based upon the code in `ex_cldr` and other libraries however there are some foundational changes intended to improve developer experience, reduce compile times and simplify library packaging.

### No "backend" architecture

CLDR is a large data repository and therefore any library using this data needs to encapsulate it and make it accessible in a performant manner. In `ex_cldr`, the data is compiled into a number of "backend" modules (similar to the way `gettext` works).

The benefits are that with Elixir metaprogramming, the data can be used to generate idiomatic functions that wrap the data. However this approach does elongate compile times and it does require compile-time configuration of the desired locales.

`Localize` takes a different approach. Locales are loaded (and potentially downloaded) at runtime and stored in the BEAMs [:persistent_term](https://www.erlang.org/doc/apps/erts/persistent_term.html) storage which has fast access (likely as fast as pattern matching function heads) and which can be updated at runtime.  As a result, there is no "backend" required with much less work done at compile time.

In addition, locales can now be dynamically added to the configuration at runtime which improves flexibility.

### Some code will still be generated at runtime

One of the benefits of the "backend" approach is that with metaprogramming we can convert some of the CLDR specifications into code.  For example, [rules based number formatting](https://unicode.org/reports/tr35/tr35-numbers.html#Rule-Based_Number_Formatting) and [pluralization rules](https://unicode.org/reports/tr35/tr35-numbers.html#Language_Plural_Rules) are compiled to native Elixir code in `ex_cldr` at compile time.

In `Localize`, we want to maintain the performance characteristics of compile-time code generation without the compile-time overhead.  On the basis that locales are loaded once and used many times, the same native Elixir code will be generated - but generated at runtime when the locale is being loaded.  This will mean there is some latency when a new locale is added to the system: the locale may have to be downloaded, then it has to be loaded into `:persistent_term` and then one or more modules will need to be compiled into the system to provide the required functions.  Early experiments suggests this is a reasonable tradeoff to gain faster compilation, simpler APIs and runtime configurability.

### Locale loading and locale storage and access will be pluggable

By default, locale data will be downloaded (from Github, and later CDN) on-demand at runtime and stored in [persistent_term](https://www.erlang.org/doc/apps/erts/persistent_term.html). For most use cases this is likely to be a good approach.

Some use cases may benefit from alternative approaches to downloading locale data, storing it and accessing it.

* Some devices are resource constrained. Locale data consumes approximately 1.6MB of persistent term storage. On a typical cloud server thats unlikely to be an issue but on an embedded device perhaps thats too much. A developer may choose to build a storage and access plugin to Localize that stores the data on an alternative storage device.

* Some organizations may restrict access to public internet content for sensitive production applications. In that case, an organisation may build its own locale loader that downloads from an internal site - or potentially package locale data with its applications directly.

* An organization may wish to change some of the CLDR locale data for its own use. While not recommended (its likely to be a maintenance nightmare), it will at least be possible by maintaining private copies of locale data.  Note that locale data formats usually change with each CLDR release.

## No compile-time configuration

Since `ex_cldr` generates modules at compile time it uses compile-time configuration to specify a default locale, a json decoding library, the desired locales (in a backend module) and so on.

`Localize` will specifically not require any compile-time configuration. Locale data will be delivered in [erlang term format](https://www.erlang.org/doc/apps/erts/erl_ext_dist.html) instead of JSON so no json decode is required.

## Simplified library packaging

Today there are 28 [ex_cldr based libraries](https://github.com/orgs/elixir-cldr/repositories) (many of which are add-on calendars). This packaging strategy was originally intended to achieve two objectives:

1. Minimise memory utilisation by including only that data (compiled into modules) required by an application.
2. Make maintenance more timely since only an affected library needed updating for bug fixes.

Given the maturity of the base code (now 8 years in production), and feedback from users, simplifying the packaging becomes a higher priority.

For `Localize` the following packaging is anticipated:

* `Localize` which includes the functionality of the existing `ex_cldr`, `ex_cldr_numbers`, `ex_cldr_dates_times`, `ex_cldr_calendars` (and dependent calendars), `ex_cldr_currencies`, `ex_cldr_units`, `ex_cldr_person_names`, `ex_cldr_locale_display`, `ex_cldr_messages`, `ex_cldr_lists`, `ex_cldr_languages`, `ex_cldr_territories`.

* `Localize_web` which includes the functionality of `ex_cldr_routes`, `ex_cldr_plugs` and `ex_cldr_html`. It will also include the new locale explorer Phoenix application.

* `Localize_sql` which includes the functionality of `ex_units_sql`, `ex_cldr_trans`.

## Improved exception and error returns

Today `ex_cldr` and friends standarize on returning `{:error, {exception_module, message_text}}`. This approach was adopted to keep the `{:error, term}` format common in Elixir but also returning a machine readable code (the exception module) and a human readable message.

Unfortunately all of that was based on a lack of understanding of how exceptions are structured in Elixir. A misunderstanding that goes back eight years.

In `Localize`, errors will be returned as `{:error, Exception.t}`, with the exception holding structured data about the error. And a user-readable message being generated as defined by `Exception.message/1`.

This approach is much more idiomatic, gives more visibility to the developer about the error and paves the way for localized exception messages.

## Interactive Locale Explorer

As part of Localize Web, a new web-based locale explorer will be provided that can be added to a Phoenix application. This liveview-based application will allow interactive exploration of locale data and show examples of the many capabilities that CLDR enables in Localize.

At a later stage, a publically accessible version of the locale explorer will be available.

## Additional tutorial documentation

In the era of LLMs its very useful to have libraries document how-to information and implementation guidelines. `Localize` documentation will progressively improve to support better LLM engagement.

## Elixir support

Currently `ex_cldr` supports Elixir ~> 1.12 (from 2021) which means there is release specific conditional code in several places. Localize will target support at Elixir ~> 1.17 with a possibility of tightening even further to a minimum of Elixir ~> 1.18. By the time of first public release that would mean the supported Elixir versions would be 1.17 (maybe), 1.18, 1.19 and 1.20.

## OTP Support

Localize is targetting to support OTP 26 and later.



