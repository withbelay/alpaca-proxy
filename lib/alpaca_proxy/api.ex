defmodule AlpacaProxy.API do
  @moduledoc "Calls 3rd-party API expecting async chunked response"

  alias HTTPoison.AsyncResponse
  alias Plug.BasicAuth
  alias Plug.Conn

  @enforce_keys [:base_url, :key, :secret]
  defstruct [:base_url, :key, :secret]

  @type headers :: HTTPoison.headers()

  @spec get_config :: struct
  def get_config() do
    struct!(__MODULE__, Application.fetch_env!(:alpaca_proxy, __MODULE__))
  end

  @spec async_fetch!(Conn.t()) :: AsyncResponse.t()
  def async_fetch!(conn) when is_struct(conn, Conn) do
    config = get_config()

    headers =
      conn.req_headers
      |> reject_hijacked_headers()
      |> add_alpaca_authorization(config.key, config.secret)

    async_fetch!(
      build_url(config, conn),
      conn.method,
      conn.body_params,
      headers
    )
  end

  @spec async_fetch!(String.t(), method :: String.t(), Conn.params(), headers()) ::
          AsyncResponse.t()
  defp async_fetch!(url, "GET", body, headers) when map_size(body) == 0 do
    opts = [recv_timeout: :infinity, stream_to: self(), timeout: :infinity]
    HTTPoison.get!(url, headers, opts)
  end

  defp async_fetch!(url, "POST", body, headers) do
    opts = [recv_timeout: :infinity, stream_to: self(), timeout: :infinity]
    HTTPoison.post!(url, Jason.encode!(body), headers, opts)
  end

  defp add_alpaca_authorization(req_headers, key, secret) do
    [{"authorization", BasicAuth.encode_basic_auth(key, secret)} | req_headers]
  end

  defp reject_hijacked_headers(req_headers) do
    Enum.reject(req_headers, fn
      {name, _value} when name in ["authorization", "cookie", "host"] -> true
      _any -> false
    end)
  end

  defp build_url(%__MODULE__{} = config, %Conn{} = conn) do
    URI.merge(config.base_url, conn.request_path)
    |> URI.append_query(conn.query_string)
    |> URI.to_string()
  end
end
