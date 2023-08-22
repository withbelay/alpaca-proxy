import Config

config :alpaca_proxy, AlpacaProxyWeb, env: config_env()

config :alpaca_proxy, AlpacaProxyWeb.Endpoint,
  pubsub_server: AlpacaProxy.PubSub,
  render_errors: [formats: [json: AlpacaProxyWeb.ErrorJSON], layout: false],
  url: [host: "localhost"]

config :logger, :console, format: "$time $metadata[$level] $message\n", metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
