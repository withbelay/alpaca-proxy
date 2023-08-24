defmodule AlpacaProxyWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :alpaca_proxy

  @session_options [
    key: "_alpaca_proxy_key",
    same_site: "Lax",
    signing_salt: "qyt31eGV",
    store: :cookie
  ]

  @static_paths ["assets", "fonts", "images", "favicon.ico", "robots.txt"]
  plug Plug.Static, at: "/", from: :alpaca_proxy, gzip: false, only: @static_paths

  plug Plug.RequestId

  plug Plug.Parsers,
    json_decoder: Phoenix.json_library(),
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"]

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug AlpacaProxyWeb.Router
end
