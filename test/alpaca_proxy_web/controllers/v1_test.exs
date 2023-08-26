defmodule AlpacaProxyWeb.V1Test do
  use ExUnit.Case, async: true

  alias Plug.BasicAuth
  alias Plug.Conn

  require Phoenix.ConnTest, as: ConnTest

  setup _tags do
    env = Application.fetch_env!(:alpaca_proxy, AlpacaProxy.API)
    api_env = env[:api]
    unauthorized_conn = ConnTest.build_conn()
    authorization = BasicAuth.encode_basic_auth("belay", env[:secret])
    conn = Conn.put_req_header(unauthorized_conn, "authorization", authorization)
    port = String.to_integer(api_env[:port])
    endpoint_uri = struct(URI, host: api_env[:host], port: port, scheme: api_env[:scheme])
    {:ok, bypass: Bypass.open(port: port), conn: conn, endpoint: URI.to_string(endpoint_uri)}
  end

  id = "sample"
  @endpoint AlpacaProxyWeb.Endpoint
  @error_messages ["something", "went", "wrong"]
  @messages ["hello", "world"]

  describe "unauthorized connection" do
    test "without headers" do
      unauthorized_conn = ConnTest.build_conn()
      conn = ConnTest.get(unauthorized_conn, "/v1/accounts")
      assert ConnTest.response(conn, 401) == "Unauthorized"
    end

    test "with fake header" do
      conn =
        ConnTest.build_conn()
        |> Conn.put_req_header("authorization", "Basic fake")
        |> ConnTest.get("/v1/accounts")

      assert ConnTest.response(conn, 401) == "Unauthorized"
    end

    test "with wrong app_id" do
      authorization = BasicAuth.encode_basic_auth("fake", "fake")

      conn =
        ConnTest.build_conn()
        |> Conn.put_req_header("authorization", authorization)
        |> ConnTest.get("/v1/accounts")

      assert ConnTest.response(conn, 401) == "Unauthorized"
    end
  end

  accounts_routes = ["/accounts", "/accounts/" <> id]
  events_routes = ["/events/journals/status", "/events/trades"]
  get_routes = ["/trading/accounts/" <> id <> "/positions"] ++ accounts_routes ++ events_routes
  routes = [{"GET", get_routes}, {"POST", ["/journals"]}]

  for {method, paths} <- routes, path <- paths, v1_path = Path.join("v1", path) do
    describe method <> " " <> v1_path do
      test "returns 200", %{bypass: bypass, endpoint: endpoint} do
        Bypass.expect_once(bypass, unquote(method), unquote(v1_path), fn conn ->
          chunked_response(conn, 200, @messages)
        end)

        fetch!(unquote(method), endpoint, unquote(v1_path))
        assert_chunked_response(200, @messages)
      end

      test "returns 500", %{bypass: bypass, endpoint: endpoint} do
        Bypass.expect_once(bypass, unquote(method), unquote(v1_path), fn conn ->
          chunked_response(conn, 500, @error_messages)
        end)

        fetch!(unquote(method), endpoint, unquote(v1_path))
        assert_chunked_response(500, @error_messages)
      end
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

  defp fetch!("GET", endpoint, path) do
    endpoint
    |> Path.join(path)
    |> HTTPoison.get!([], recv_timeout: :infinity, stream_to: self())
  end

  defp fetch!("POST", endpoint, path) do
    endpoint
    |> Path.join(path)
    |> HTTPoison.post!({:form, [{"data", "fake"}]}, [],
      recv_timeout: :infinity,
      stream_to: self()
    )
  end
end
