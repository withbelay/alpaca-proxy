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
    get "/accounts", V1Controller, :rest
    get "/accounts/:account_id", V1Controller, :rest
    get "/events/journals/status", V1Controller, :sse
    get "/events/trades", V1Controller, :sse
    post "/journals", V1Controller, :rest
    get "/trading/accounts/:account_id/positions", V1Controller, :rest
  end

  @spec verify_proxy_basic_auth(Conn.t(), any()) :: Conn.t()
  defp verify_proxy_basic_auth(conn, _opts) when is_struct(conn, Conn) do
    with {key, secret} <- BasicAuth.parse_basic_auth(conn),
         "belay" <- key,
         ^secret <- Application.fetch_env!(:alpaca_proxy, AlpacaProxyWeb)[:secret] do
      conn
    else
      _error ->
        conn
        |> Conn.resp(401, "Unauthorized")
        |> Conn.halt()
    end
  end
end
