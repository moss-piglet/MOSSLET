defmodule Mosslet.Workers.PqResealWorker do
  @moduledoc """
  Oban worker that progressively re-seals a user's context keys from
  legacy v1 (X25519 box_seal) to hybrid v2 (ML-KEM-768 + X25519).

  Triggered on login after PQ key migration is confirmed. Processes
  user_posts, user_groups, user_memories, and user_connections keys.

  Re-seal changes the wrapping only — the underlying symmetric key
  does not change, so no data migration is needed.
  """
  use Oban.Worker, queue: :security, max_attempts: 3, unique: [period: 300]

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "session_key" => session_key}}) do
    user = Accounts.get_user!(user_id)

    # User must have PQ keys — otherwise nothing to re-seal to
    if is_nil(user.pq_public_key) do
      Logger.debug("[PqResealWorker] User #{user_id} has no PQ keys, skipping")
      :ok
    else
      reseal_user_context_keys(user, session_key)
    end
  end

  defp reseal_user_context_keys(user, session_key) do
    with {:ok, private_key} <- decrypt_private_key(user, session_key) do
      keys = %{public: user.key_pair["public"], private: private_key}
      pq_opts = Encrypted.Utils.pq_opts_for_user(user)

      counts =
        [
          reseal_table(Mosslet.Timeline.UserPost, :key, user.id, keys, pq_opts),
          reseal_table(Mosslet.Groups.UserGroup, :key, user.id, keys, pq_opts),
          reseal_table(Mosslet.Memories.UserMemory, :key, user.id, keys, pq_opts),
          reseal_table(Mosslet.Accounts.UserConnection, :key, user.id, keys, pq_opts)
        ]

      total = Enum.sum(counts)

      if total > 0 do
        Logger.info("[PqResealWorker] Re-sealed #{total} context keys for user #{user.id}")
      end

      :ok
    else
      {:error, reason} ->
        Logger.warning(
          "[PqResealWorker] Failed to decrypt private key for user #{user.id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp reseal_table(schema, field, user_id, keys, pq_opts) do
    import Ecto.Query

    records =
      from(r in schema, where: r.user_id == ^user_id, select: {r.id, field(r, ^field)})
      |> Repo.all()

    records
    |> Enum.filter(fn {_id, sealed_key} ->
      sealed_key && !MetamorphicCrypto.Hybrid.hybrid_ciphertext?(sealed_key)
    end)
    |> Enum.reduce(0, fn {id, sealed_key}, count ->
      case reseal_key(sealed_key, keys, pq_opts) do
        {:ok, new_sealed_key} ->
          from(r in schema, where: r.id == ^id)
          |> Repo.update_all(set: [{field, new_sealed_key}])

          count + 1

        {:error, _reason} ->
          count
      end
    end)
  end

  defp reseal_key(sealed_key, keys, pq_opts) do
    with {:ok, plaintext_key} <-
           Encrypted.Utils.decrypt_message_for_user(sealed_key, keys) do
      new_sealed =
        Encrypted.Utils.encrypt_message_for_user_with_pk(
          plaintext_key,
          %{public: keys.public},
          pq_opts
        )

      {:ok, new_sealed}
    end
  end

  defp decrypt_private_key(user, session_key) do
    private_key = user.key_pair["private"]

    case Encrypted.Utils.decrypt(%{key: session_key, payload: private_key}) do
      {:ok, d_key} -> {:ok, d_key}
      {:error, _} -> {:error, :failed_verification}
    end
  end
end
