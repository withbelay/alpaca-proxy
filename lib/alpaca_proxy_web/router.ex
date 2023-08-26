defmodule AlpacaProxyWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  alias Plug.BasicAuth
  alias Plug.Conn

  pipeline :api do
    plug :accepts, ["json"]
    plug :verify_proxy_basic_auth
  end

  scope "/v1", AlpacaProxyWeb do
    pipe_through :api
    get "/accounts", V1Controller, :chunked_response
    get "/accounts/:account_id", V1Controller, :chunked_response
    get "/events/journals/status", V1Controller, :chunked_response
    get "/events/trades", V1Controller, :chunked_response
    post "/journals", V1Controller, :chunked_response
    get "/trading/accounts/:account_id/positions", V1Controller, :chunked_response
  end

  @spec verify_proxy_basic_auth(Conn.t(), any()) :: Conn.t()
  defp verify_proxy_basic_auth(conn, _opts) when is_struct(conn, Conn) do
    with {key, secret} <- BasicAuth.parse_basic_auth(conn),
         "belay" <- key,
         ^secret <- Application.fetch_env!(:alpaca_proxy, :secret) do
      conn
    else
      _error ->
        conn
        |> Conn.resp(401, "Unauthorized")
        |> Conn.halt()
    end
  end
end
