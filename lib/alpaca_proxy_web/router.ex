defmodule AlpacaProxyWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  alias Plug.BasicAuth
  alias Plug.Conn

  pipeline :api do
    plug :accepts, ["json"]
    plug :verify_proxy_basic_auth
  end

  # Rate limit all alpaca routes which do not utilize an account_id in the path params
  pipeline :general_rate_limit do
    plug Hammer.Plug,
      rate_limit: {"belay", :timer.minutes(1), 100},
      by: :ip
  end

  # Used for the alpaca routes which are rate limited based upon the path param account ID supplied
  pipeline :account_rate_limit do
    plug Hammer.Plug,
      rate_limit: {"belay", :timer.minutes(1), 100},
      by: {:conn, &__MODULE__.get_account_id_from_request/1}
  end

  scope "/v1", AlpacaProxyWeb do
    pipe_through [:api, :general_rate_limit]

    # https://alpaca.markets/docs/api-references/broker-api/accounts/accounts/#listing-all-accounts
    # * when user logs in using an email / password, we only get their email and their token. We need to find their
    #   account_id. So we query accounts by email address.
    get "/accounts", V1Controller, :chunked_response

    # https://alpaca.markets/docs/api-references/broker-api/clock/
    # * let investor web figure out if the market is open
    get "/clock", V1Controller, :chunked_response

    # https://alpaca.markets/docs/api-references/broker-api/journals/#creating-a-journal
    # * policy payments (investor -> sweep -> belay)
    # * policy refund (belay -> sweep -> investor)
    # * policy claim (belay -> sweep -> investor)
    post "/journals", V1Controller, :chunked_response

    # https://alpaca.markets/docs/api-references/broker-api/events/#journal-status
    # * allows us to see the status of journals
    get "/events/journals/status", V1Controller, :chunked_response

    # https://alpaca.markets/docs/api-references/broker-api/events/#trade-updates
    # * we automatically process claims when customers sell out of a position
    get "/events/trades", V1Controller, :chunked_response
  end

  scope "/v1", AlpacaProxyWeb do
    pipe_through [:api, :account_rate_limit]

    # https://alpaca.markets/docs/api-references/broker-api/accounts/accounts/#retrieving-an-account-brokerage
    # * get cash available (to see if they can afford the policy)
    get "/accounts/:account_id", V1Controller, :get_account

    # https://alpaca.markets/docs/api-references/broker-api/trading/positions/#getting-all-positions
    # * we can only sell them policies to cover positions they have
    get "/trading/accounts/:account_id/positions", V1Controller, :chunked_response

    # https://alpaca.markets/docs/api-references/broker-api/accounts/accounts/#retrieving-an-account-trading
    # * get cash available (to see if they can afford the policy)
    get "/trading/accounts/:account_id/account", V1Controller, :chunked_response
  end

  @doc """
  Used for the Hammer rate-limiting plug set above
  """
  @spec get_account_id_from_request(Conn.t()) :: String.t()
  def get_account_id_from_request(conn) do
    conn.path_params["account_id"]
  end

  @spec verify_proxy_basic_auth(Conn.t(), any()) :: Conn.t()
  defp verify_proxy_basic_auth(conn, _opts) when is_struct(conn, Conn) do
    with {"belay", secret} <- BasicAuth.parse_basic_auth(conn),
         ^secret <- Application.fetch_env!(:alpaca_proxy, :secret) do
      conn
    else
      _error ->
        conn
        |> Conn.resp(401, "Unauthorized")
        |> Conn.halt()
    end
  end
end
