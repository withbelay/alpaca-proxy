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
end
