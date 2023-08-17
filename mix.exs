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
      deps: [
        # JSON API Server
        {:httpoison, "~> 2.1"},
        {:jason, "~> 1.4"},
        {:phoenix, "~> 1.7"},
        {:plug_cowboy, "~> 2.6"},
        # Code checking
        {:credo, "~> 1.7", only: :checks, runtime: false},
        {:dialyxir, "~> 1.3", only: :checks, runtime: false},
        # Documentation
        {:ex_doc, "~> 0.30", only: :docs, runtime: false},
        # Tests
        {:bypass, "~> 2.1", only: :test},
        {:excoveralls, "~> 0.17", only: :test}
      ],
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [credo: :checks, dialyzer: :checks, docs: :docs],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "1.0.0-rc.0"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
