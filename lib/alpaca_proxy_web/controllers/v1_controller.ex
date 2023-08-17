defmodule AlpacaProxyWeb.V1Controller do
  use Phoenix.Controller, formats: [:json]

  alias Plug.Conn

  @doc "Handles requests to representational state transfer API"
  @spec rest(Conn.t(), Conn.params()) :: Conn.t()
  def rest(conn, _params), do: AlpacaProxyWeb.rest(conn)

  @doc "Handles requests to Server-Sent Events API"
  @spec sse(Conn.t(), Conn.params()) :: Conn.t()
  def sse(conn, _params), do: AlpacaProxyWeb.server_sent_event(conn)
end
