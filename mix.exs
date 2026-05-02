defmodule Snarky.MixProject do
  use Mix.Project

  def project do
    [
      app: :snarky,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Snarky.Application, []}
    ]
  end

  defp deps do
    [
      {:bumblebee, "~> 0.6"},
      {:exla, "~> 0.9"},
      {:ortex, "~> 0.1"},
      {:ex_osc, "~> 0.1"},
      {:jason, "~> 1.4"},
      {:nx, "~> 0.9"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "snarky.setup"]
    ]
  end
end
