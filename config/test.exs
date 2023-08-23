import Config

# A test configuration to work with bypass dependency
config :alpaca_proxy, AlpacaProxyWeb,
  blacklisted_sweep_account_ids: ["fake-blacklisted-id"],
  host: "localhost",
  key: "key",
  port: "4001",
  scheme: "http",
  secret: "secret",
  sweep_account_id: "fake-id"

config :alpaca_proxy, AlpacaProxyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "E1RMUAhoiNxtFLOEHow5liO+Rmdt6fLPSnBPJjub8/4sTCmFFDZ3Unczh1LLNxRf",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
