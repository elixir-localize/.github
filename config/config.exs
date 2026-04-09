import Config

config :elixir_localize, :site,
  title: "Localize",
  tagline: "Next-generation localization for Elixir.",
  description:
    "Development notes, release updates and technical writing about Localize, " <>
      "the next-generation CLDR-based localization library for Elixir.",
  author: "Kip Cole",
  base_url: "https://blog.localize.dev",
  language: "en"

config :elixir_localize, :r2,
  bucket: "blog",
  # R2 uses "auto" as the region for SigV4
  region: "auto"
