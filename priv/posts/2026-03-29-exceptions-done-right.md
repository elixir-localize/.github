%{
  title: "Exceptions done right (eight years late)",
  author: "Kip Cole",
  tags: ~w(localize exceptions api),
  description: "For eight years ex_cldr has returned `{:error, {Module, message}}`. Localize returns real Exception structs. Here is why the old format was a mistake and what the new one enables."
}
---

Since version 0.1, `ex_cldr` has returned errors in this shape:

```elixir
{:error, {Cldr.UnknownLocaleError, "The locale \"xx\" is not known"}}
```

It looks reasonable. Machine-readable tag in the first element, human message in the second. What could be wrong with it?

A lot, it turns out. I got it wrong in 2018 and I've been stuck with it ever since.

## What's wrong with the tuple form

**The module is not the error.** `Cldr.UnknownLocaleError` in that tuple is just an atom. It isn't raised, it isn't caught, it doesn't carry any structured data. To extract the locale name that caused the problem, you have to parse the message string — or use the module as a dispatch key and go look up what fields it *would* have had, if it had been a real struct.

**The message isn't localized.** That string is generated at the point the error is constructed, in English, with no way to render it in the caller's locale. For a library whose job is *to localize things*, hard-coding English error messages is embarrassing.

**`raise/1` does the wrong thing.** A common pattern was `raise exception`, expecting Elixir to construct the exception struct for you. But:

```elixir
case result do
  {:error, {exception, message}} -> raise exception, message
  ...
end
```

`raise SomeModule, "text"` calls `SomeModule.exception/1` with the string, which — because we never defined a proper `exception/1` — silently created an exception with `:message` set to `"text"` and no other data. Stack traces looked fine. Debugging was miserable because the original data was gone.

**You can't pattern-match cleanly.** To handle a specific error you have to match on `{:error, {Cldr.UnknownLocaleError, _}}`. If the error kind grows a new field tomorrow, you have to update every match site. A real struct gives you `%Cldr.UnknownLocaleError{locale: locale}` which is idiomatic Elixir.

## What Localize does instead

Exceptions are proper `Exception` structs:

```elixir
defmodule Localize.UnknownLocaleError do
  @moduledoc """
  Raised when a locale name is not recognised by CLDR.
  """
  defexception [:locale, :hint]

  @impl true
  def message(%{locale: locale, hint: nil}) do
    "The locale #{inspect(locale)} is not known"
  end

  def message(%{locale: locale, hint: hint}) do
    "The locale #{inspect(locale)} is not known. Did you mean #{inspect(hint)}?"
  end
end
```

Errors are returned as:

```elixir
{:error, %Localize.UnknownLocaleError{locale: "xx", hint: "xh"}}
```

That one change cascades into a pile of small improvements:

* **You can pattern-match on fields.** `{:error, %Localize.UnknownLocaleError{locale: locale}}` gives you the offending locale directly.
* **You can raise cleanly.** `case Localize.Number.to_string(…) do {:ok, s} -> s; {:error, e} -> raise e end` Just Works.
* **Messages are generated on demand.** `Exception.message(exception)` is called when — and only when — somebody actually wants a string. That's the right place to look up a localized template.
* **Hints are structured.** The locale error above carries a `:hint` field populated by a nearest-match search. We can render it or not; we can render it differently; we can *not* render it in a production log where it would leak unrelated locale names.

## Localized exception messages

This is the headline feature that the old format blocked completely.

The `Exception.message/1` callback is a normal function. Nothing stops it from calling `Localize.Message.format/2`:

```elixir
@impl true
def message(%__MODULE__{locale: locale}) do
  Localize.Message.format(:unknown_locale, locale: locale)
end
```

The message template lives in CLDR-shaped data and can be rendered in whichever locale the caller prefers. A Japanese application can show Japanese error messages. An application serving multiple users from the same VM can render each error in the requesting user's locale.

The machinery for localized exceptions will land progressively. The important point is that Localize's error return type **does not stand in the way**, where `ex_cldr`'s did.

## Migration

If you have code like this:

```elixir
case Cldr.Locale.new(locale, MyApp.Cldr) do
  {:ok, l} -> l
  {:error, {Cldr.UnknownLocaleError, msg}} -> raise Cldr.UnknownLocaleError, msg
end
```

it becomes:

```elixir
case Localize.Locale.new(locale) do
  {:ok, l} -> l
  {:error, %Localize.UnknownLocaleError{} = e} -> raise e
end
```

or, more idiomatically:

```elixir
with {:ok, l} <- Localize.Locale.new(locale) do
  l
end
```

A script to rewrite the common patterns will be part of the migration guide. The tuple → struct mapping is mechanical for the vast majority of call sites.

## The lesson

The old error format wasn't a bug — every part of it worked, for some definition of "worked". It was a decision that expressed a misunderstanding of how Elixir exceptions are designed to be used, and that misunderstanding was baked so deeply into the public API that fixing it required a major version.

If there is a moral, it's this: when you define the error return type for a new library, **return real exception structs**. Not tuples, not atoms, not strings. You will not regret it. I did.
