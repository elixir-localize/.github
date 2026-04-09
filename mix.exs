defmodule ElixirLocalize.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :elixir_localize,
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
      {:nimble_publisher, "~> 1.1"},
      {:makeup_elixir, "~> 0.16"},
      {:makeup_erlang, "~> 0.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:req, "~> 0.5"},
      {:aws_signature, "~> 0.3"},
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.16"},
      {:xmlrpc, "~> 1.4"}
    ]
  end
end
