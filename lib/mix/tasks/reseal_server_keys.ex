defmodule Mix.Tasks.ResealServerKeys do
  @moduledoc """
  Re-seals server-keyed context keys from legacy box_seal (v1) or Cat-3 (v2)
  to Cat-5 hybrid (ML-KEM-1024 + X25519).

  This migrates public-visibility content keys (user_posts, user_groups,
  user_memories, connections/profile_keys, user_post_reports, and post_report
  admin_notes) that are sealed with the server's X25519 public key to hybrid
  PQ sealing using the server's new ML-KEM-1024 keypair.

  Requires SERVER_PQ_PUBLIC_KEY and SERVER_PQ_SECRET_KEY env vars to be set.

  Safe to run multiple times — skips keys already sealed as Cat-5 (version
  tag 0x03). The underlying symmetric keys are not changed.

  ## Usage

      mix reseal_server_keys
      mix reseal_server_keys --dry-run
  """

  use Mix.Task
  require Logger

  alias Mosslet.Encrypted
  alias Mosslet.Repo

  import Ecto.Query

  @cat5_version_tag 0x03

  @shortdoc "Re-seal public content keys to Cat-5 hybrid PQ"
  def run(args) do
    dry_run? = "--dry-run" in args

    Mix.Task.run("app.start")

    server_pq_pk = Encrypted.Session.server_pq_public_key()
    server_pq_sk = Encrypted.Session.server_pq_secret_key()

    if is_nil(server_pq_pk) || server_pq_pk == "" do
      Mix.raise("SERVER_PQ_PUBLIC_KEY env var is not set. Generate a keypair first.")
    end

    if is_nil(server_pq_sk) || server_pq_sk == "" do
      Mix.raise("SERVER_PQ_SECRET_KEY env var is not set. Generate a keypair first.")
    end

    server_keys = %{
      public: Encrypted.Session.server_public_key(),
      private: Encrypted.Session.server_private_key()
    }

    pq_opts = Encrypted.Utils.pq_opts_for_server()

    Mix.shell().info("Re-sealing server-keyed context keys to Cat-5 hybrid PQ...")

    if dry_run? do
      Mix.shell().info("[DRY RUN] No changes will be written.")
    end

    tables = [
      {Mosslet.Timeline.UserPost, :key, "user_posts"},
      {Mosslet.Groups.UserGroup, :key, "user_groups"},
      {Mosslet.Timeline.UserPostReport, :key, "user_post_reports"}
    ]

    total =
      Enum.reduce(tables, 0, fn {schema, field, label}, acc ->
        count = reseal_table(schema, field, server_keys, pq_opts, dry_run?)
        Mix.shell().info("  #{label}: #{count} re-sealed")
        acc + count
      end)

    # Connection profile_key is inside an embedded schema (profile.profile_key),
    # so it can't use the generic reseal_table helper.
    conn_count = reseal_connection_profile_keys(server_keys, pq_opts, dry_run?)
    Mix.shell().info("  connections (profile_key): #{conn_count} re-sealed")
    total = total + conn_count

    # Post report admin_notes are sealed differently (they're the plaintext,
    # not a context key). We re-seal those too for consistency.
    admin_count = reseal_post_report_admin_notes(server_keys, pq_opts, dry_run?)
    Mix.shell().info("  post_reports (admin_notes): #{admin_count} re-sealed")
    total = total + admin_count

    Mix.shell().info("Done. Total re-sealed: #{total}")
  end

  defp reseal_table(schema, field, server_keys, pq_opts, dry_run?) do
    records =
      from(r in schema, select: {r.id, field(r, ^field)})
      |> Repo.all()

    records
    |> Enum.filter(fn {_id, sealed_key} ->
      sealed_key && needs_reseal?(sealed_key)
    end)
    |> Enum.reduce(0, fn {id, sealed_key}, count ->
      case reseal_key(sealed_key, server_keys, pq_opts) do
        {:ok, new_sealed} ->
          unless dry_run? do
            from(r in schema, where: r.id == ^id)
            |> Repo.update_all(set: [{field, new_sealed}])
          end

          count + 1

        {:error, reason} ->
          Logger.warning(
            "[ResealServerKeys] Failed to re-seal #{inspect(schema)} #{id}: #{inspect(reason)}"
          )

          count
      end
    end)
  end

  defp reseal_connection_profile_keys(server_keys, pq_opts, dry_run?) do
    records =
      from(c in Mosslet.Accounts.Connection,
        where: not is_nil(c.profile),
        select: {c.id, c.profile}
      )
      |> Repo.all()

    records
    |> Enum.filter(fn {_id, profile} ->
      profile && profile.profile_key && needs_reseal?(profile.profile_key)
    end)
    |> Enum.reduce(0, fn {id, profile}, count ->
      case reseal_key(profile.profile_key, server_keys, pq_opts) do
        {:ok, new_sealed} ->
          unless dry_run? do
            new_profile = %{profile | profile_key: new_sealed}

            from(c in Mosslet.Accounts.Connection, where: c.id == ^id)
            |> Repo.update_all(set: [profile: new_profile])
          end

          count + 1

        {:error, reason} ->
          Logger.warning(
            "[ResealServerKeys] Failed to re-seal Connection #{id} profile_key: #{inspect(reason)}"
          )

          count
      end
    end)
  end

  defp reseal_post_report_admin_notes(server_keys, pq_opts, dry_run?) do
    records =
      from(r in Mosslet.Timeline.PostReport,
        where: not is_nil(r.admin_notes),
        select: {r.id, r.admin_notes}
      )
      |> Repo.all()

    records
    |> Enum.filter(fn {_id, notes} -> needs_reseal?(notes) end)
    |> Enum.reduce(0, fn {id, sealed_notes}, count ->
      case reseal_key(sealed_notes, server_keys, pq_opts) do
        {:ok, new_sealed} ->
          unless dry_run? do
            from(r in Mosslet.Timeline.PostReport, where: r.id == ^id)
            |> Repo.update_all(set: [admin_notes: new_sealed])
          end

          count + 1

        {:error, _reason} ->
          count
      end
    end)
  end

  defp reseal_key(sealed_key, server_keys, pq_opts) do
    case Encrypted.Utils.decrypt_message_for_user(sealed_key, server_keys) do
      {:ok, plaintext_key} ->
        new_sealed =
          Encrypted.Utils.encrypt_message_for_user_with_pk(
            plaintext_key,
            %{public: server_keys.public},
            pq_opts
          )

        {:ok, new_sealed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp needs_reseal?(sealed_key_b64) when is_binary(sealed_key_b64) do
    case Base.decode64(sealed_key_b64) do
      {:ok, <<@cat5_version_tag, _rest::binary>>} -> false
      _ -> true
    end
  end

  defp needs_reseal?(_), do: false
end
