defmodule Mosslet.Repo.SQLite do
  @moduledoc """
  SQLite repository for local cache operations in desktop/mobile apps.

  This repo is used ONLY for:
  - Offline cache of encrypted blobs from the cloud
  - Sync queue for pending changes when offline
  - Local-only preferences/settings

  **IMPORTANT**: This repo does NOT store user data as the source of truth.
  All user data lives in the cloud Postgres database. This is a cache layer only.

  The encrypted blobs stored here are already enacl-encrypted from the server,
  so even if the local database is compromised, the data remains protected.
  """
  use Ecto.Repo,
    otp_app: :mosslet,
    adapter: Ecto.Adapters.SQLite3

  def init(_type, config) do
    {:ok, config}
  end
end
