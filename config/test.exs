import Config

# A test configuration to work with bypass dependency
config :alpaca_proxy, secret: "secret"

config :alpaca_proxy, AlpacaProxy.API,
  base_url: "http://localhost:4001",
  key: "key",
  secret: "secret"

# FIXME: Why are these ports different?
config :alpaca_proxy, AlpacaProxyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "E1RMUAhoiNxtFLOEHow5liO+Rmdt6fLPSnBPJjub8/4sTCmFFDZ3Unczh1LLNxRf",
  server: true

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
