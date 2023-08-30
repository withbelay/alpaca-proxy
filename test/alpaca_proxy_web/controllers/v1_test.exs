defmodule AlpacaProxyWeb.V1Test do
  use ExUnit.Case, async: true

  alias AlpacaProxyWeb.Endpoint
  alias Plug.BasicAuth
  alias Plug.Conn

  require Phoenix.ConnTest, as: ConnTest

  setup _tags do
    # Our configuration of AlpacaProxyWeb.Endpoint has set server to true, which implies we are running a
    # real local server. Below we attach bypass to listen to the port of that live server
    api_env = Application.fetch_env!(:alpaca_proxy, AlpacaProxy.API)[:api]
    secret = Application.fetch_env!(:alpaca_proxy, :secret)

    endpoint_uri =
      struct(URI,
        host: Endpoint.config(:url)[:host],
        port: Endpoint.config(:http)[:port],
        scheme: "http"
      )

    authorization = BasicAuth.encode_basic_auth("belay", secret)
    endpoint = URI.to_string(endpoint_uri)
    port = String.to_integer(api_env[:port])
    bypass = Bypass.open(port: port)
    conn = ConnTest.build_conn()
    {:ok, authorization: authorization, bypass: bypass, conn: conn, endpoint: endpoint}
  end

  @endpoint AlpacaProxyWeb.Endpoint

  describe "unauthorized connection" do
    test "without headers", %{conn: conn} do
      conn = ConnTest.get(conn, "/v1/accounts")
      assert ConnTest.response(conn, 401) == "Unauthorized"
    end

    test "with fake header", %{conn: conn} do
      conn =
        conn
        |> Conn.put_req_header("authorization", "Basic fake")
        |> ConnTest.get("/v1/accounts")

      assert ConnTest.response(conn, 401) == "Unauthorized"
    end

    test "with wrong app_id", %{conn: conn} do
      authorization = BasicAuth.encode_basic_auth("fake", "fake")

      conn =
        conn
        |> Conn.put_req_header("authorization", authorization)
        |> ConnTest.get("/v1/accounts")

      assert ConnTest.response(conn, 401) == "Unauthorized"
    end
  end

  id = "sample"
  error_messages = ["something", "went", "wrong"]
  messages = ["hello", "world"]

  routes = [
    {"GET", "/v1/accounts"},
    {"GET", "/v1/accounts/" <> id},
    {"GET", "/v1/events/journals/status"},
    {"GET", "/v1/events/trades"},
    {"GET", "/v1/trading/accounts/" <> id <> "/positions"},
    {"POST", "/v1/journals"}
  ]

  for {status_code, messages} <- [{200, messages}, {500, error_messages}],
      {method, path} <- routes do
    test method <> " " <> path <> " returns " <> Integer.to_string(status_code), data do
      Bypass.expect(data.bypass, unquote(method), unquote(path), fn conn ->
        chunked_response(conn, unquote(status_code), unquote(messages))
      end)

      # This fetch! is pointing back at the local cowboy server, so we are sending a REST call to our router
      fetch!(unquote(method), data.endpoint, unquote(path), data.authorization)
      assert_chunked_response(unquote(status_code), unquote(messages))
    end
  end

  defp assert_chunked_response(status_code, messages) do
    assert_receive %HTTPoison.AsyncStatus{code: ^status_code}, 200
    assert_receive %HTTPoison.AsyncHeaders{headers: headers}, 200
    assert {"transfer-encoding", "chunked"} in headers

    for message <- messages do
      assert_receive %HTTPoison.AsyncChunk{chunk: ^message}, 200
    end

    assert_receive %HTTPoison.AsyncEnd{}, 200
  end

  defp chunked_response(conn, status_code, messages) do
    conn
    |> Conn.send_chunked(status_code)
    |> tap(fn conn ->
      Enum.each(messages, fn message -> Conn.chunk(conn, message) end)
    end)
  end

  defp fetch!("GET", endpoint, path, authorization) do
    opts = [recv_timeout: :infinity, stream_to: self()]

    endpoint
    |> Path.join(path)
    |> HTTPoison.get!([{"authorization", authorization}], opts)
  end

  defp fetch!("POST", endpoint, path, authorization) do
    opts = [recv_timeout: :infinity, stream_to: self()]

    endpoint
    |> Path.join(path)
    |> HTTPoison.post!({:form, [{"data", "fake"}]}, [{"authorization", authorization}], opts)
  end
end
