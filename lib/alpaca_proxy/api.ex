defmodule AlpacaProxy.API do
  @moduledoc "Calls 3rd-party API expecting async chunked response"

  alias HTTPoison.AsyncResponse
  alias Plug.BasicAuth
  alias Plug.Conn

  @type body_params :: Conn.params() | []
  @type headers :: HTTPoison.headers()

  @spec async_fetch!(conn :: Conn.t()) :: async_response :: AsyncResponse.t()
  def async_fetch!(conn) when is_struct(conn, Conn) do
    alpaca_api_env =
      :alpaca_proxy
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.fetch!(:api)
      |> Map.new()

    authorization = BasicAuth.encode_basic_auth(alpaca_api_env.key, alpaca_api_env.secret)
    port = String.to_integer(alpaca_api_env[:port])

    headers =
      [{"authorization", authorization}] ++
        Enum.reject(conn.req_headers, fn tuple ->
          elem(tuple, 0) in ["authorization", "cookie", "host"]
        end)

    URI
    |> struct(host: alpaca_api_env[:host], port: port, scheme: alpaca_api_env[:scheme])
    |> struct(path: conn.request_path, query: conn.query_string)
    |> URI.to_string()
    |> async_fetch!(conn.method, Map.to_list(conn.body_params), headers)
  end

  @spec async_fetch!(String.t(), method :: String.t(), body_params(), headers()) ::
          async_response :: AsyncResponse.t()
  defp async_fetch!(url, "GET", [], headers) do
    opts = [recv_timeout: :infinity, stream_to: self(), timeout: :infinity]
    HTTPoison.get!(url, headers, opts)
  end

  defp async_fetch!(url, "POST", body_params, headers) do
    opts = [recv_timeout: :infinity, stream_to: self(), timeout: :infinity]
    HTTPoison.post!(url, {:form, body_params}, headers, opts)
  end
end
