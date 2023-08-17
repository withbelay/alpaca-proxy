defmodule AlpacaProxyWeb.V1Test do
  use ExUnit.Case, async: true

  alias Plug.Conn

  require Phoenix.ConnTest, as: ConnTest

  setup _tags do
    proxy_env = Application.fetch_env!(:alpaca_proxy, AlpacaProxyWeb)
    port = proxy_env[:port]
    endpoint = "#{proxy_env[:host]}:#{port}"
    {:ok, bypass: Bypass.open(port: port), conn: ConnTest.build_conn(), endpoint: endpoint}
  end

  id = "sample"
  @endpoint AlpacaProxyWeb.Endpoint
  @data %{"sample" => "data"}
  @error %{"error" => "raison"}
  @error_json Jason.encode!(@error)
  @json Jason.encode!(@data)

  for path <- ~w[/v1/accounts /v1/accounts/#{id} /v1/trading/accounts/#{id}/positions] do
    describe "GET #{path}" do
      test "returns 200", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "GET", unquote(path), &json_response(&1, 200, @json))
        conn = ConnTest.get(conn, unquote(path))
        assert ConnTest.json_response(conn, 200) == @data
      end

      test "returns 500", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "GET", unquote(path), &json_response(&1, 500, @error_json))
        conn = ConnTest.get(conn, unquote(path))
        assert ConnTest.json_response(conn, 500) == @error
      end
    end
  end

  for path <- ~w[/v1/journals] do
    describe "POST #{path}" do
      test "returns 200", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "POST", unquote(path), &json_response(&1, 200, @json))
        conn = ConnTest.post(conn, unquote(path), %{body: "good"})
        assert ConnTest.json_response(conn, 200) == @data
      end

      test "returns 500", %{bypass: bypass, conn: conn} do
        Bypass.expect_once(bypass, "POST", unquote(path), &json_response(&1, 500, @error_json))
        conn = ConnTest.post(conn, unquote(path), %{body: "wrong"})
        assert ConnTest.json_response(conn, 500) == @error
      end
    end
  end

  defp json_response(conn, status_code, json) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.resp(status_code, json)
  end

  @error_messages ~w[something went wrong]
  @messages ~w[hello world]

  for path <- ~w[/v1/events/journals/status /v1/events/trades] do
    describe "GET #{path}" do
      test "returns 200", %{bypass: bypass, endpoint: endpoint} do
        Bypass.expect_once(bypass, "GET", unquote(path), &sse_response(&1, 200, @messages))

        endpoint
        |> Path.join(unquote(path))
        |> HTTPoison.get!([], recv_timeout: :infinity, stream_to: self())

        assert_receive_messages(@messages, 200)
      end

      test "returns 500", %{bypass: bypass, endpoint: endpoint} do
        Bypass.expect_once(bypass, "GET", unquote(path), &sse_response(&1, 500, @error_messages))

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
    |> then(fn conn ->
      Enum.reduce(messages, conn, fn message, conn ->
        tap(conn, &Conn.chunk(&1, message))
      end)
    end)
  end
end
