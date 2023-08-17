# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule AlpacaProxyWeb do
  @moduledoc """
  Core proxy functions to work with REST and Server Sent Event requests.
  """

  alias HTTPoison.AsyncChunk
  alias HTTPoison.AsyncEnd
  alias HTTPoison.AsyncHeaders
  alias HTTPoison.AsyncResponse
  alias HTTPoison.AsyncStatus
  alias HTTPoison.Response
  alias Plug.Conn

  @type body_params :: Conn.params() | []
  @type headers :: HTTPoison.headers()

  @doc "Retrieves data from conn, passes them to requests and applies response data to current connection."
  @spec rest(Conn.t()) :: conn :: Conn.t()
  def rest(%Conn{} = conn) do
    conn
    |> fetch!(false)
    |> then(&copy_data(conn, &1))
  end

  @spec copy_data(Conn.t(), response :: Response.t()) :: conn :: Conn.t()
  defp copy_data(conn, %Response{body: body, headers: headers, status_code: code}) do
    headers
    |> Enum.reduce(conn, fn {key, value}, conn ->
      Conn.put_resp_header(conn, key, value)
    end)
    |> Conn.send_resp(code, body)
  end

  @doc "Retrieves data from conn, passes them to requests and applies synchronous response data to current connection."
  @spec server_sent_event(Conn.t()) :: conn :: Conn.t()
  def server_sent_event(conn) do
    %AsyncResponse{} = fetch!(conn, true)
    proxy_server_sent_event(conn)
  end

  @spec proxy_server_sent_event(Conn.t()) :: conn :: Conn.t()
  defp proxy_server_sent_event(%Conn{} = conn, status_code \\ nil) do
    receive do
      %AsyncStatus{code: status_code} ->
        proxy_server_sent_event(conn, status_code)

      %AsyncHeaders{headers: headers} ->
        conn
        |> put_headers(headers)
        |> Conn.send_chunked(status_code)
        |> proxy_server_sent_event(status_code)

      %AsyncChunk{chunk: chunk} ->
        Conn.chunk(conn, chunk)
        proxy_server_sent_event(conn, status_code)

      %AsyncEnd{} ->
        conn
    end
  end

  @spec put_headers(Conn.t(), headers()) :: conn :: Conn.t()
  defp put_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      Conn.put_resp_header(acc, key, value)
    end)
  end

  @spec fetch!(conn :: Conn.t(), stream :: false) :: response :: Response.t()
  @spec fetch!(conn :: Conn.t(), stream :: true) :: async_response :: AsyncResponse.t()
  defp fetch!(%Conn{} = conn, stream) do
    alpaca_api_env =
      :alpaca_proxy
      |> Application.fetch_env!(AlpacaProxyWeb)
      |> Map.new()

    method = request_method_to_function(conn.method)
    token = Base.encode64("#{alpaca_api_env.key}:#{alpaca_api_env.secret}")

    headers =
      conn.req_headers
      |> Enum.reject(&(elem(&1, 0) in ~w[cookie host]))
      |> then(&[{"Authorization", "Basic #{token}"} | &1])

    alpaca_api_env
    |> Map.take(~w[host port scheme]a)
    |> then(&Map.merge(%URI{path: conn.request_path, query: conn.query_string}, &1))
    |> URI.to_string()
    |> fetch!(method, Map.to_list(conn.body_params), headers, stream)
  end

  @spec request_method_to_function(method :: String.t()) :: function :: atom()
  defp request_method_to_function(method) do
    method
    |> String.downcase()
    |> then(&(&1 <> "!"))
    |> String.to_existing_atom()
  end

  @spec fetch!(String.t(), method :: atom(), body_params(), headers(), stream :: true) ::
          async_response :: AsyncResponse.t()
  defp fetch!(url, :get!, [], headers, true) do
    opts = [recv_timeout: :infinity, stream_to: self()]
    HTTPoison.get!(url, headers, opts)
  end

  @spec fetch!(String.t(), method :: atom(), body_params(), headers(), stream :: false) ::
          response :: Response.t()
  defp fetch!(url, :get!, [], headers, false) do
    HTTPoison.get!(url, headers)
  end

  defp fetch!(url, :post!, body_params, headers, false) do
    HTTPoison.post!(url, {:form, body_params}, headers)
  end
end
