defmodule AlpacaProxyWeb.V1Test do
  use ExUnit.Case, async: true

  alias AlpacaProxyWeb.Endpoint
  alias Plug.BasicAuth
  alias Plug.Conn

  require Phoenix.ConnTest, as: ConnTest

  # Generated this list by:
  # 1. Export this postman collection as JSON
  #    (https://www.postman.com/alpacamarkets/workspace/alpaca-public-workspace/request/19455863-d2ce00ad-f66b-4505-bb96-7a909b8621de)
  # 2. `cat Broker\ API.postman_collection.json | jq '.item[].item[].request | {method, "url": .url["raw"]} | join("
  #    ")'`
  @unproxied_routes [
    {"POST", "/v1/accounts"},
    {"PATCH", "/v1/accounts/:account_id"},
    {"DELETE", "/v1/accounts/:account_id"},
    {"POST", "/v1/accounts/:account_id/cip"},
    {"GET", "/v1/accounts/activities"},
    {"GET", "/v1/accounts/activities/:activity_type"},
    {"GET", "/v1/assets"},
    {"GET", "/v1/assets/:symbol_or_asset_id"},
    {"GET", "/v1/calendar"},
    {"GET",
     "/v1/corporate_actions/announcements?ca_types=dividend,merger,spinoff,split&since=2022-05-01&until=2022-07-01"},
    {"POST", "/v1/accounts/:account_id/documents/upload"},
    {"GET", "/v1/accounts/:account_id/documents"},
    {"GET", "/v1/accounts/:account_id/documents/:document_id/download"},
    {"GET", "/v1/accounts/:account_id/documents/:document_id"},
    {"GET", "/v1/events/accounts/status"},
    {"GET", "/v1/events/transfers/status"},
    {"POST", "/v1/accounts/:account_id/ach_relationships"},
    {"GET", "/v1/accounts/:account_id/ach_relationships"},
    {"DELETE", "/v1/accounts/:account_id/ach_relationships/:relationship_id"},
    {"POST", "/v1/accounts/:account_id/recipient_banks"},
    {"GET", "/v1/accounts/:account_id/recipient_banks"},
    {"DELETE", "/v1/accounts/:account_id/recipient_banks/:bank_id"},
    {"POST", "/v1/accounts/:account_id/transfers"},
    {"GET", "/v1/accounts/:account_id/transfers"},
    {"DELETE", "/v1/accounts/:account_id/transfers/:transfer_id"},
    {"POST", "/v1/journals/batch"},
    {"GET", "/v1/journals"},
    {"DELETE", "/v1/journals/:journal_id"},
    {"GET", "/v1/trading/accounts/:account_id/watchlists"},
    {"POST", "/v1/trading/accounts/:account_id/watchlists"},
    {"GET", "/v1/trading/accounts/:account_id/positions/:symbol_or_asset_id"},
    {"DELETE", "/v1/trading/accounts/:account_id/positions"},
    {"DELETE", "/v1/trading/accounts/:account_id/positions/:symbol_or_asset_id"},
    {"GET", "/v1/trading/accounts/:account_id/orders"},
    {"POST", "/v1/trading/accounts/:account_id/orders"},
    {"DELETE", "/v1/trading/accounts/:account_id/orders"},
    {"GET", "/v1/trading/accounts/:account_id/orders/:order_id"},
    {"PATCH", "/v1/trading/accounts/:account_id/orders/:order_id"},
    {"DELETE", "/v1/trading/accounts/:account_id/orders/:order_id"},
    {"PUT", "/v1/accounts/:account_id/watchlists/:watchlist_id"},
    {"GET", "/v1/accounts/:account_id/watchlists/:watchlist_id"},
    {"DELETE", "/v1/accounts/:account_id/watchlists/:watchlist_id"},
    {"GET", "/v1/oauth/clients/:client_id"},
    {"POST", "/v1/oauth/token"},
    {"POST", "/v1/oauth/authorize"},
    {"POST", "/v1/beta/rebalancing/portfolios"},
    {"GET", "/v1/beta/rebalancing/portfolios"},
    {"GET", "/v1/beta/rebalancing/portfolios/:portfolio_id"},
    {"PATCH", "/v1/beta/rebalancing/portfolios/:portfolio_id"},
    {"DELETE", "/v1/beta/rebalancing/portfolios/:portfolio_id"},
    {"POST", "/v1/beta/rebalancing/subscriptions"},
    {"GET", "/v1/beta/rebalancing/subscriptions"},
    {"GET", "/v1/beta/rebalancing/subscriptions/:subscription_id"},
    {"DELETE", "/v1/beta/rebalancing/subscriptions/:subscription_id"},
    {"POST", "/v1/beta/rebalancing/runs"},
    {"GET", "/v1/beta/rebalancing/runs?status=COMPLETED_SUCCESS"},
    {"GET", "/v1/beta/rebalancing/runs/:run_id"},
    {"DELETE", "/v1/beta/rebalancing/runs/:run_id"}
  ]

  @account_id "b6df1a1f-b7d5-479f-9a1f-c79bead97203"
  @proxied_routes [
    {"GET", "/v1/accounts?query=investor_email@gmail.com"},
    {"GET", "/v1/accounts/#{@account_id}"},
    {"GET", "/v1/clock"},
    {"GET", "/v1/events/journals/status"},
    {"GET", "/v1/events/trades"},
    {"GET", "/v1/trading/accounts/:account_id/account"},
    {"GET", "/v1/trading/accounts/#{@account_id}/positions"},
    {"POST", "/v1/journals"}
  ]

  @endpoint AlpacaProxyWeb.Endpoint
  @chunked_success ["that", "worked"]

  setup _tags do
    # Our configuration of AlpacaProxyWeb.Endpoint has set server to true, which implies we are running a
    # real local server. Below we attach bypass to listen to the port of that live server
    config = AlpacaProxy.API.get_config()
    bypass = Bypass.open(port: 4001)
    conn = ConnTest.build_conn()

    endpoint_uri =
      struct(URI,
        host: Endpoint.config(:url)[:host],
        port: Endpoint.config(:http)[:port],
        scheme: "http"
      )

    authorization = BasicAuth.encode_basic_auth("belay", config.secret)
    endpoint = URI.to_string(endpoint_uri)
    {:ok, authorization: authorization, bypass: bypass, conn: conn, base_url: endpoint}
  end

  describe "unauthorized connection" do
    # These tests verify that the security config that we are using to authorize belay to the proxy is being
    # checked.
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

  describe "when attempting to access denied routes" do
    Enum.map(@unproxied_routes, fn {method, path} ->
      @method method
      @path path

      test "#{@method} #{path} is not found", %{
        bypass: bypass,
        base_url: base_url,
        authorization: authorization
      } do
        # There is an Alpaca out there listening, but we should not be able to access it
        path = String.split(@path, "?") |> List.first()

        Bypass.stub(bypass, @method, path, fn conn ->
          conn = Conn.send_chunked(conn, 200)
          Enum.each(@chunked_success, fn message -> Conn.chunk(conn, message) end)
          conn
        end)

        execute_request(@method, @path, base_url, authorization)

        assert_404()
      end
    end)
  end

  describe "when accessing permitted routes" do
    Enum.map(@proxied_routes, fn {method, path} ->
      @method method
      @path path

      test "#{@method} #{path} is proxied", %{
        bypass: bypass,
        base_url: base_url,
        authorization: authorization
      } do
        # There is an Alpaca out there listening, and now we expect it to be used (expect vs stub)
        path = String.split(@path, "?") |> List.first()

        Bypass.expect(bypass, @method, path, fn conn ->
          conn = Conn.send_chunked(conn, 200)
          Enum.each(@chunked_success, fn message -> Conn.chunk(conn, message) end)
          conn
        end)

        execute_request(@method, @path, base_url, authorization)

        assert_chunked_response(200, @chunked_success)
      end
    end)
  end

  defp execute_request(method, path, base_url, authorization) do
    opts = [recv_timeout: :infinity, stream_to: self()]
    url = Path.join(base_url, path)
    headers = [{"authorization", authorization}, {"content-type", "application/json"}]

    case method do
      "DELETE" -> HTTPoison.delete!(url, headers, opts)
      "GET" -> HTTPoison.get!(url, headers, opts)
      "PATCH" -> HTTPoison.patch!(url, "", headers, opts)
      "POST" -> HTTPoison.post!(url, "", headers, opts)
      "PUT" -> HTTPoison.put!(url, "", headers, opts)
    end
  end

  defp assert_404() do
    assert_receive %HTTPoison.AsyncStatus{code: 404}
    assert_receive %HTTPoison.AsyncChunk{chunk: "{\"errors\":{\"detail\":\"Not Found\"}}"}
    assert_receive %HTTPoison.AsyncEnd{}
  end

  defp assert_chunked_response(status_code, messages) do
    assert_receive %HTTPoison.AsyncStatus{code: ^status_code}
    assert_receive %HTTPoison.AsyncHeaders{headers: headers}
    assert {"transfer-encoding", "chunked"} in headers

    for message <- messages do
      assert_receive %HTTPoison.AsyncChunk{chunk: ^message}
    end

    assert_receive %HTTPoison.AsyncEnd{}
  end
end
