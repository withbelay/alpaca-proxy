defmodule AlpacaProxyWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ~w[json]
  end

  scope "/v1", AlpacaProxyWeb do
    pipe_through :api
    get "/accounts", V1Controller, :rest
    get "/accounts/:account_id", V1Controller, :rest
    get "/events/journals/status", V1Controller, :sse
    get "/events/trades", V1Controller, :sse
    post "/journals", V1Controller, :rest
    get "/trading/accounts/:account_id/positions", V1Controller, :rest
  end
end
