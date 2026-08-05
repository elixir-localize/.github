defmodule LocalizeBlog.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :localize_blog,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :crypto]
    ]
  end

  defp deps do
    [
      {:static_blog, "~> 0.2"},
      {:nimble_publisher, "~> 2.1"},
      {:makeup_elixir, "~> 0.16"},
      {:makeup_erlang, "~> 0.1"}
    ]
  end
end
