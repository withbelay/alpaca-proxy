defmodule AlpacaProxyWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  alias AlpacaProxyWeb.Endpoint
  alias Phoenix.Token
  alias Plug.BasicAuth
  alias Plug.Conn

  pipeline :api do
    plug :accepts, ["json"]
    plug :verify_api_authorization_token
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

  @spec verify_api_authorization_token(Conn.t(), any()) :: Conn.t()
  defp verify_api_authorization_token(conn, _opts) when is_struct(conn, Conn) do
    with {app_id, token} <- BasicAuth.parse_basic_auth(conn),
         true <- token_authorized?(app_id, token) do
      conn
    else
      _error ->
        conn
        |> Conn.resp(401, "Unauthorized")
        |> Conn.halt()
    end
  end

  @spec token_authorized?(String.t(), String.t()) :: boolean()
  defp token_authorized?(app_id, token) do
    salt = Application.fetch_env!(:alpaca_proxy, AlpacaProxyWeb)[:salt]
    {result, data} = Token.verify(Endpoint, salt, token)
    result == :ok and data == app_id
  end
end
