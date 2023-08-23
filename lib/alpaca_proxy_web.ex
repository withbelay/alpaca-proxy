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
  def rest(conn) when is_struct(conn, Conn) do
    response = fetch!(conn, false)
    copy_data(conn, response)
  end

  @spec copy_data(Conn.t(), response :: Response.t()) :: conn :: Conn.t()
  defp copy_data(conn, response) when is_struct(response, Response) do
    response
    |> Map.fetch!(:headers)
    |> Enum.reduce(conn, fn {key, value}, conn ->
      Conn.put_resp_header(conn, key, value)
    end)
    |> Conn.send_resp(response.status_code, response.body)
  end

  @doc "Retrieves data from conn, passes them to requests and applies synchronous response data to current connection."
  @spec server_sent_event(Conn.t()) :: conn :: Conn.t()
  def server_sent_event(conn) do
    fetch!(conn, true)
    proxy_server_sent_event(conn)
  end

  @spec proxy_server_sent_event(Conn.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp proxy_server_sent_event(conn, status_code \\ nil) when is_struct(conn, Conn) do
    receive do
      message -> handle_message(conn, message, status_code)
    end
  end

  @spec handle_message(Conn.t(), AsyncStatus.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_status, nil)
       when is_struct(async_status, AsyncStatus) do
    proxy_server_sent_event(conn, async_status.code)
  end

  @spec handle_message(Conn.t(), AsyncHeaders.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_headers, status_code)
       when is_struct(async_headers, AsyncHeaders) do
    conn
    |> put_headers(async_headers.headers)
    |> Conn.send_chunked(status_code)
    |> proxy_server_sent_event(status_code)
  end

  @spec handle_message(Conn.t(), AsyncChunk.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_chunk, status_code)
       when is_struct(async_chunk, AsyncChunk) do
    Conn.chunk(conn, async_chunk.chunk)
    proxy_server_sent_event(conn, status_code)
  end

  @spec handle_message(Conn.t(), AsyncEnd.t(), nil | non_neg_integer()) :: conn :: Conn.t()
  defp handle_message(conn, async_end, _status_code) when is_struct(async_end, AsyncEnd) do
    conn
  end

  @spec put_headers(Conn.t(), headers()) :: conn :: Conn.t()
  defp put_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      Conn.put_resp_header(acc, key, value)
    end)
  end

  @spec fetch!(conn :: Conn.t(), stream :: false) :: response :: Response.t()
  @spec fetch!(conn :: Conn.t(), stream :: true) :: async_response :: AsyncResponse.t()
  defp fetch!(conn, stream) when is_struct(conn, Conn) do
    alpaca_api_env =
      :alpaca_proxy
      |> Application.fetch_env!(AlpacaProxyWeb)
      |> Map.new()

    map = %{
      host: alpaca_api_env[:host],
      port: String.to_integer(alpaca_api_env[:port]),
      scheme: alpaca_api_env[:scheme]
    }

    token = Base.encode64(alpaca_api_env.key <> ":" <> alpaca_api_env.secret)
    token_header = {"authorization", "Basic " <> token}
    uri = struct(URI, path: conn.request_path, query: conn.query_string)

    headers =
      [token_header] ++
        Enum.reject(conn.req_headers, fn tuple ->
          elem(tuple, 0) in ["authorization", "cookie", "host"]
        end)

    uri
    |> Map.merge(map)
    |> URI.to_string()
    |> fetch!(conn.method, Map.to_list(conn.body_params), headers, stream)
  end

  @spec fetch!(String.t(), method :: String.t(), body_params(), headers(), stream :: true) ::
          async_response :: AsyncResponse.t()
  defp fetch!(url, "GET", [], headers, true) do
    opts = [recv_timeout: :infinity, stream_to: self()]
    HTTPoison.get!(url, headers, opts)
  end

  @spec fetch!(String.t(), method :: String.t(), body_params(), headers(), stream :: false) ::
          response :: Response.t()
  defp fetch!(url, "GET", [], headers, false) do
    HTTPoison.get!(url, headers)
  end

  defp fetch!(url, "POST", body_params, headers, false) do
    HTTPoison.post!(url, {:form, body_params}, headers)
  end
end
