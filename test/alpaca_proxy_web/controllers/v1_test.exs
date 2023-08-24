defmodule AlpacaProxyWeb.V1Test do
  use ExUnit.Case, async: true

  alias Plug.BasicAuth
  alias Plug.Conn

  require Phoenix.ConnTest, as: ConnTest

  setup _tags do
    env = Application.fetch_env!(:alpaca_proxy, AlpacaProxyWeb)
    api_env = env[:api]
    unauthorized_conn = ConnTest.build_conn()
    authorization = BasicAuth.encode_basic_auth("belay", env[:secret])
    conn = Conn.put_req_header(unauthorized_conn, "authorization", authorization)
    port = api_env[:port]
    bypass = Bypass.open(port: String.to_integer(port))
    endpoint = api_env[:host] <> ":" <> port
    {:ok, bypass: bypass, conn: conn, endpoint: endpoint}
  end

  id = "sample"
  @endpoint AlpacaProxyWeb.Endpoint
  @data %{"sample" => "data"}
  @error %{"error" => "raison"}
  @error_json Jason.encode!(@error)
  @json Jason.encode!(@data)

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

  for path <- [
        "/v1/accounts",
        "/v1/accounts/" <> id,
        "/v1/trading/accounts/" <> id <> "/positions"
      ] do
    describe "GET " <> path do
      test "returns 200", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "GET", unquote(path), fn conn ->
          json_response(conn, 200, @json)
        end)

        conn = ConnTest.get(conn, unquote(path))
        assert ConnTest.json_response(conn, 200) == @data
      end

      test "returns 500", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "GET", unquote(path), fn conn ->
          json_response(conn, 500, @error_json)
        end)

        conn = ConnTest.get(conn, unquote(path))
        assert ConnTest.json_response(conn, 500) == @error
      end
    end
  end

  @post_body %{"data" => "fake"}

  for path <- ["/v1/journals"] do
    describe "POST " <> path do
      test "returns 200", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "POST", unquote(path), fn conn ->
          json_response(conn, 200, @json)
        end)

        conn = ConnTest.post(conn, unquote(path), @post_body)
        assert ConnTest.json_response(conn, 200) == @data
      end

      test "returns 500", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "POST", unquote(path), fn conn ->
          json_response(conn, 500, @error_json)
        end)

        conn = ConnTest.post(conn, unquote(path), @post_body)
        assert ConnTest.json_response(conn, 500) == @error
      end
    end
  end

  defp json_response(conn, status_code, json) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.resp(status_code, json)
  end

  @error_messages ["something", "went", "wrong"]
  @messages ["hello", "world"]

  for path <- ["/v1/events/journals/status", "/v1/events/trades"] do
    describe "GET " <> path do
      test "returns 200", %{bypass: bypass, endpoint: endpoint} do
        Bypass.expect_once(bypass, "GET", unquote(path), fn conn ->
          sse_response(conn, 200, @messages)
        end)

        endpoint
        |> Path.join(unquote(path))
        |> HTTPoison.get!([], recv_timeout: :infinity, stream_to: self())

        assert_receive_messages(@messages, 200)
      end

      test "returns 500", %{bypass: bypass, endpoint: endpoint} do
        Bypass.expect_once(bypass, "GET", unquote(path), fn conn ->
          sse_response(conn, 500, @error_messages)
        end)

        endpoint
        |> Path.join(unquote(path))
        |> HTTPoison.get!([], recv_timeout: :infinity, stream_to: self())

        assert_receive_messages(@error_messages, 500)
      end
    end
  end

  defp assert_receive_messages(messages, status_code) do
    assert_receive %HTTPoison.AsyncStatus{code: ^status_code}, 200
    assert_receive %HTTPoison.AsyncHeaders{headers: headers}, 200
    assert {"content-type", "text/event-stream"} in headers

    for message <- messages do
      assert_receive %HTTPoison.AsyncChunk{chunk: ^message}, 200
    end

    assert_receive %HTTPoison.AsyncEnd{}, 200
  end

  defp sse_response(conn, status_code, messages) do
    conn
    |> Conn.put_resp_header("content-type", "text/event-stream")
    |> Conn.send_chunked(status_code)
    |> tap(fn conn ->
      Enum.each(messages, fn message -> Conn.chunk(conn, message) end)
    end)
  end
end
