%{
  title: "Next week is a big week for Elixir Localize",
  author: "Kip Cole",
  tags: ["Localize"],
  description: "Elixir Localize, the evolution of ex_cldr will officially launch next week starting from Monday, April 13th. Each day there will be one or more libraries launching.",
  published: "2026-04-10T14:54:27Z",
  updated: "2026-04-11T02:40:26Z"
}
---
Elixir [Localize](https://github.com/elixir-localize), the evolution of [ex_cldr](https://hex.pm/packaged/ex_cldr)  will officially launch next week starting from Monday, April 13th.  Each day there will be one or more libraries launching.

* Monday sees the launch of [localize](https://github.com/elixir-localize/localize) that supersedes `ex_cldr`. In a single library it contains localised number, currency, date/time, units of measure, list and message format 2 formatting for over 700 locales using the data from [CLDR](https://cldr.unicode.org). In addition it includes a full CLDR-compliant collator. It compiles faster than `ex_cldr`, runs faster than `ex_cldr`, uses less memory than `ex_cldr` and has dynamic runtime locale loading mechanism that provides an overall better developer experience and a more complete and integrated localisation solution.

* On Tuesday, `localize_web` will launch. It provides localised routing, plugs for accept-language headers that then set the locale for `localize` and `gettext` and some HTML helpers.

* Wednesday is the launch of `localize_person_names` for formatting names in a localised manner; in formal, informal and other ways.  And `the launch of Calendrical` which is a consolidated set of calendars now including Gregorian, Julian, Islamic (four variants), Hebrew, Persian, Indian, Buddhist, Composite and user definable. And a few more I probably missed.

* Thursday is the launch of `localize_address` and `localize_phonenumber`. These are still somewhat experimental and both NIF-based. `localize_address` wraps the fabulous [libpostal](https://github.com/openvenues/libpostal) for parsing free-form address data and [OpenCageData address-formatting](https://github.com/OpenCageData/address-formatting) templates for formatting.  `localize_phonenumber` wraps the well-known [libphonenumber](https://github.com/google/libphonenumber) for both parsing and formatting phone numbers from around the world.

* Friday is room for just one more thing.  `Intl` is an API wrapper for `localize` that uses the ECMAScript Internationalization API called [Intl](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl). This gives developers who are more familiar with front-end development an easier on-boarding to localisation in Elixir.

Stand by for more updates, or subscribe to the RSS feed to be kept up-to-date.
