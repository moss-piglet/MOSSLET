defmodule Mosslet.Repo.Local do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :mosslet,
    adapter: Ecto.Adapters.Postgres

  @env Mix.env()

  # Dynamically configure the database url based on runtime and build
  # environments.
  def init(_type, config) do
    Fly.Postgres.config_repo_url(config, @env)
  end
end

defmodule Mosslet.Repo do
  @moduledoc false
  use Fly.Repo, local_repo: Mosslet.Repo.Local
  use Mosslet.Extensions.Ecto.RepoExt

  def transaction_on_primary(tx_fun) do
    # Temporary shim during fly_postgres removal - behaves as a plain transaction.
    # TODO: replace call sites as we will now run on Fly MPG and then delete this function.
    # Fly.Postgres.rpc_and_wait(__MODULE__, :transaction, [tx_fun])
    transaction(tx_fun)
  end
end
