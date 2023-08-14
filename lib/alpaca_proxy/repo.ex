defmodule AlpacaProxy.Repo do
  use Ecto.Repo,
    otp_app: :alpaca_proxy,
    adapter: Ecto.Adapters.Postgres
end
