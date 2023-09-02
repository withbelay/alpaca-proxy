import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

if System.get_env("ALPACA_PROXY_SERVER") do
  config :alpaca_proxy, AlpacaProxyWeb.Endpoint, server: true
end

if config_env() == :prod do
  # FIXME: This env variable is confusingly named
  config :alpaca_proxy, secret: System.fetch_env!("ALPACA_PROXY_SECRET")

  config :alpaca_proxy, AlpacaProxy.API,
    # FIXME: this should default to alpaca's real url in prod
    base_url: System.fetch_env!("ALPACA_PROXY_BASE_URL"),
    key: System.fetch_env!("ALPACA_PROXY_API_KEY"),
    secret: System.fetch_env!("ALPACA_PROXY_API_SECRET")

  # FIXME: this should be true in prod always
  force_ssl = System.get_env("ALPACA_PROXY_FORCE_SSL", "false")
  host = System.get_env("ALPACA_PROXY_HOST", "localhost")
  ipv6_remote_ip = {0, 0, 0, 0, 0, 0, 0, 0}
  # ipv6_local_ip = {0, 0, 0, 0, 0, 0, 0, 1}
  port = System.get_env("ALPACA_PROXY_PORT", "80")
  secret_key_base = System.fetch_env!("ALPACA_PROXY_SECRET_KEY_BASE")
  ssl_cert_path = System.get_env("ALPACA_PROXY_SSL_CERT_PATH")
  ssl_key_path = System.get_env("ALPACA_PROXY_SSL_KEY_PATH")
  ssl_port_string = System.get_env("ALPACA_PROXY_SSL_PORT", "443")
  ssl_port = String.to_integer(ssl_port_string)
  ssl_suite = System.get_env("ALPACA_PROXY_SSL_SUITE", "strong")

  config :alpaca_proxy, AlpacaProxyWeb.Endpoint,
    force_ssl: [hsts: force_ssl == "true"],
    http: [ip: ipv6_remote_ip, port: String.to_integer(port)],
    https: [
      certfile: ssl_cert_path,
      cipher_suite: String.to_atom(ssl_suite),
      keyfile: ssl_key_path,
      port: ssl_port
    ],
    secret_key_base: secret_key_base,
    url: [host: host, port: ssl_port, scheme: "https"]
end
