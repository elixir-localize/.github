defmodule LocalizeBlog.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :localize_blog,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:static_blog, "~> 0.2"},
      {:nimble_publisher, "~> 2.1"},
      {:makeup_elixir, "~> 0.16"},
      {:makeup_erlang, "~> 0.1"}
    ]
  end
end
