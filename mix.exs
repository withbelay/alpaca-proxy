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
        # Code checking tools
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
        {:dialyxir, "~> 1.3", only: :dev, runtime: false},
        {:excoveralls, "~> 0.17", only: :test},
        # Documentation
        {:ex_doc, "~> 0.30", only: :dev, runtime: false},
        # Used only in tests
        {:bypass, "~> 2.1", only: :test}
      ],
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "1.0.0-rc.0",
      aliases: aliases(),
      preferred_cli_env: preferred_cli_envs()
    ]
  end

  defp aliases do
    [
      compile_with_sentry: ["compile deps.compile sentry --force"],
      "test.int": ["test --include integration"],
      "test.ext": ["test --include external"],
      "test.all": ["test --include external --include integration"]
    ]
  end

  defp preferred_cli_envs() do
    [
      "coveralls.github": :test,
      coveralls: :test,
      dialyzer: :test,
      test: :test,
      "test.all": :test,
      "test.int": :test,
      "test.ext": :test
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
