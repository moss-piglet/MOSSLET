defmodule Mosslet.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :mosslet,
    adapter: Ecto.Adapters.Postgres

  use Mosslet.Extensions.Ecto.RepoExt

  def transaction_on_primary(tx_fun) do
    # Temporary shim during fly_postgres removal - behaves as a plain transaction.
    # TODO: replace call sites as we will now run on Fly MPG and then delete this function.
    # Fly.Postgres.rpc_and_wait(__MODULE__, :transaction, [tx_fun])
    transaction(tx_fun)
  end
end
