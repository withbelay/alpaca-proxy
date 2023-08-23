defmodule Mix.Tasks.Ap.Gen.Token do
  @shortdoc "Generates an API token for Alpaca Proxy"

  @moduledoc """
  Generates an API base64 encoded token for a specified app.
  Use this token in `Authorization` header together with `"Basic "` prefix"
  in order to access alpaca proxy's API.

  Every token works only in specific environment.
  To generate a token for different than default environment use `MIX_ENV` environment variable.

  ## Usage

      mix ap.gen.token APP_ID
      MIX_ENV=prod mix ap.gen.token APP_ID

  ## Arguments

  * APP_ID - id of app, for example belay-api
  """

  use Mix.Task

  @impl Mix.Task
  @spec run([String.t()]) :: String.t()
  def run(list) when is_list(list) do
    app_id = List.first(list)
    salt = Application.fetch_env!(:alpaca_proxy, AlpacaProxyWeb)[:salt]
    {:ok, _apps} = Application.ensure_all_started(:alpaca_proxy)

    AlpacaProxyWeb.Endpoint
    |> Phoenix.Token.sign(salt, app_id)
    |> Base.encode64()
    |> tap(fn token -> IO.write(token) end)
  end
end
