defmodule AlpacaProxy.Application do
  @moduledoc false

  use Application

  alias AlpacaProxyWeb.Endpoint

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  @impl Application
  def start(_type, _args) do
    LoggerBackends.add(Sentry.LoggerBackend)

    children = [
      {Phoenix.PubSub, name: AlpacaProxy.PubSub},
      Endpoint
    ]

    opts = [strategy: :one_for_one, name: AlpacaProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
