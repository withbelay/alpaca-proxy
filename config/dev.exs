import Config

# A sandbox configuration to test with real endpoint
config :alpaca_proxy, secret: "secret"

config :alpaca_proxy, AlpacaProxy.API,
  base_url: "https://broker-api.sandbox.alpaca.markets",
  key: System.get_env("ALPACA_KEY", "KEY"),
  secret: System.get_env("ALPACA_SECRET", "SECRET")

config :alpaca_proxy, AlpacaProxyWeb.Endpoint,
  check_origin: false,
  debug_errors: true,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "R+jLD5R9XM9TeR/MFTH+DsWbYTC3Ul4wLqnhord2JYqIBfB+L6EC7CD9OJ2YLVRE"

config :logger, :console, format: "[$level] $message\n"

config :phoenix, plug_init_mode: :runtime, stacktrace_depth: 20
