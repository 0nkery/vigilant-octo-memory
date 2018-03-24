defmodule TwitterFeed.MixProject do
  use Mix.Project

  def project do
    [
      app: :twitter_feed,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TwitterFeed.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto, "~> 2.0"},
      {:postgrex, "~> 0.11"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
