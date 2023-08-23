defmodule AlpacaProxyWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  alias AlpacaProxyWeb.Endpoint
  alias Phoenix.Token
  alias Plug.Conn

  pipeline :api do
    plug :accepts, ~w[json]
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
  defp verify_api_authorization_token(%Conn{req_headers: headers} = conn, _opts) do
    if Enum.any?(headers, &header_authorized?/1) do
      conn
    else
      conn
      |> Conn.resp(401, "Unauthorized")
      |> Conn.halt()
    end
  end

  @spec header_authorized?({header_name :: String.t(), header_value :: String.t()}) :: boolean()
  defp header_authorized?({"authorization", "Basic " <> token}), do: token_authorized?(token)
  defp header_authorized?({_name, _value}), do: false

  @spec token_authorized?(String.t()) :: boolean()
  defp token_authorized?(token) do
    env = Application.fetch_env!(:alpaca_proxy, AlpacaProxyWeb)[:env]

    token
    |> Base.decode64!()
    |> then(&Token.verify(Endpoint, "alpaca-proxy-#{env}", &1))
    |> then(fn
      {:ok, _app_id} -> true
      {:error, _raison} -> false
    end)
  end
end
