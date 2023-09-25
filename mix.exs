defmodule AlpacaProxy.MixProject do
  use Mix.Project

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {AlpacaProxy.Application, []}
    ]
  end

  def project do
    [
      app: :alpaca_proxy,
      deps: deps(),
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.1.0",
      aliases: aliases(),
      preferred_cli_env: preferred_cli_envs(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  defp deps do
    [
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :test, runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:excoveralls, "~> 0.17", only: :test},
      {:hammer, "~> 6.1"},
      {:hammer_plug, "~> 3.0"},
      {:httpoison, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:logger_backends, "~> 1.0"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.7"},
      {:plug_cowboy, "~> 2.6"},
      {:sentry, "~> 8.1"}
    ]
  end

  defp aliases do
    [
      compile_with_sentry: ["compile", "deps.compile sentry --force"]
    ]
  end

  defp preferred_cli_envs() do
    [
      dialyzer: :test,
      "test.watch": :test
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
