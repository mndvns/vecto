defmodule Vecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :vecto,
      version: "0.1.3",
      elixir: "~> 1.8",
      deps: deps(),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test
    ]
  end

  def application do
    [
      mod: {Vecto.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:delegate_access, "~> 0.1.0"},
      {:ecto_sql, "~> 3.1"},
      {:poison, "~> 3.1.0"},
      {:postgrex, ">= 0.0.0"},
      {:request_cache, github: "mndvns/request_cache", tag: "0.1.2"},
    ]
  end
end
