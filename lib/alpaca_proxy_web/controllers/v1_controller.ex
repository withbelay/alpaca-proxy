defmodule AlpacaProxyWeb.V1Controller do
  use Phoenix.Controller, formats: [:json]

  alias AlpacaProxy.API
  alias AlpacaProxy.Response
  alias Plug.Conn

  @doc "Proxy requests with chunked response"
  @spec chunked_response(Conn.t(), Conn.params()) :: Conn.t()
  def chunked_response(conn, _params) do
    API.async_fetch!(conn)
    Response.chunked(conn)
  end

  # had to special case "/v1/accounts/activities", because it's the fastest way to distinguish between activities and an
  # account_id.
  def get_account(conn, %{"account_id" => "activities"}) do
    raise Phoenix.Router.NoRouteError, conn: conn, router: AlpacaProxyWeb.Router
  end

  def get_account(conn, params), do: chunked_response(conn, params)
end
