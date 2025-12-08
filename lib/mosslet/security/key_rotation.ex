defmodule Mosslet.Security.KeyRotation do
  @moduledoc """
  Context for managing encryption key rotation.

  Key rotation re-encrypts data from an old cipher to a new cipher without
  requiring downtime. The process:

  1. Orchestrator job starts rotation, scanning for schemas with encrypted fields
  2. Worker jobs process records in batches
  3. Progress is tracked in `key_rotation_progress` table
  4. Once complete, old keys can be retired from the Vault

  ## Encrypted Schemas

  The following schemas use `Encrypted.Binary` fields and are candidates for rotation:
  - `Mosslet.Accounts.User`
  - `Mosslet.Accounts.Connection`
  - `Mosslet.Accounts.UserBlock`
  - `Mosslet.Accounts.UserConnection`
  - `Mosslet.Accounts.UserToken`
  - `Mosslet.Accounts.UserTOTP`
  - `Mosslet.Billing.Customers.Customer`
  - `Mosslet.Billing.PaymentIntents.PaymentIntent`
  - `Mosslet.Conversations.Conversation`
  - `Mosslet.Groups.Group`
  - `Mosslet.Groups.GroupBlock`
  - `Mosslet.Groups.GroupMessage`
  - `Mosslet.Groups.UserGroup`
  - `Mosslet.Memories.Memory`
  - `Mosslet.Memories.Remark`
  - `Mosslet.Memories.UserMemory`
  - `Mosslet.Messages.Message`
  - `Mosslet.Orgs.Invitation`
  - `Mosslet.Orgs.Org`
  - `Mosslet.Security.IpBan`
  - `Mosslet.Timeline.Bookmark`
  - `Mosslet.Timeline.BookmarkCategory`
  - `Mosslet.Timeline.ContentWarningCategory`
  - `Mosslet.Timeline.Post`
  - `Mosslet.Timeline.PostHide`
  - `Mosslet.Timeline.PostReport`
  - `Mosslet.Timeline.Reply`
  - `Mosslet.Timeline.UserPost`
  - `Mosslet.Timeline.UserPostReport`
  """

  import Ecto.Query
  alias Mosslet.Repo.Local, as: Repo
  alias Mosslet.Security.KeyRotationProgress
  alias Mosslet.Vault

  require Logger

  @pubsub_topic "key_rotation:progress"

  def subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, @pubsub_topic)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, @pubsub_topic, message)
  end

  @encrypted_schemas [
    {Mosslet.Accounts.User, :users},
    {Mosslet.Accounts.Connection, :connections},
    {Mosslet.Accounts.UserBlock, :user_blocks},
    {Mosslet.Accounts.UserConnection, :user_connections},
    {Mosslet.Accounts.UserToken, :users_tokens},
    {Mosslet.Accounts.UserTOTP, :users_totps},
    {Mosslet.Billing.Customers.Customer, :billing_customers},
    {Mosslet.Billing.PaymentIntents.PaymentIntent, :payment_intents},
    {Mosslet.Conversations.Conversation, :conversations},
    {Mosslet.Groups.Group, :groups},
    {Mosslet.Groups.GroupBlock, :group_blocks},
    {Mosslet.Groups.GroupMessage, :group_messages},
    {Mosslet.Groups.UserGroup, :user_groups},
    {Mosslet.Memories.Memory, :memories},
    {Mosslet.Memories.Remark, :remarks},
    {Mosslet.Memories.UserMemory, :user_memories},
    {Mosslet.Messages.Message, :messages},
    {Mosslet.Orgs.Invitation, :org_invitations},
    {Mosslet.Orgs.Org, :orgs},
    {Mosslet.Security.IpBan, :ip_bans},
    {Mosslet.Timeline.Bookmark, :bookmarks},
    {Mosslet.Timeline.BookmarkCategory, :bookmark_categories},
    {Mosslet.Timeline.ContentWarningCategory, :content_warning_categories},
    {Mosslet.Timeline.Post, :posts},
    {Mosslet.Timeline.PostHide, :post_hides},
    {Mosslet.Timeline.PostReport, :post_reports},
    {Mosslet.Timeline.Reply, :replies},
    {Mosslet.Timeline.UserPost, :user_posts},
    {Mosslet.Timeline.UserPostReport, :user_post_reports}
  ]

  @doc """
  Returns a list of all schemas that have encrypted fields.
  """
  def encrypted_schemas, do: @encrypted_schemas

  @doc """
  Gets the encrypted binary fields for a schema module.
  """
  def encrypted_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn field ->
      type = schema_module.__schema__(:type, field)
      is_encrypted_type?(type)
    end)
  end

  defp is_encrypted_type?(Mosslet.Encrypted.Binary), do: true
  defp is_encrypted_type?({:map, Mosslet.Encrypted.Binary}), do: true
  defp is_encrypted_type?(_), do: false

  @doc """
  Creates progress tracking for a schema rotation with a given rotation_id.
  """
  def create_progress(schema_module, from_tag, to_tag, rotation_id) do
    schema_name = inspect(schema_module)

    {_, table_name} = Enum.find(@encrypted_schemas, fn {mod, _} -> mod == schema_module end)
    total = count_records(schema_module)

    %KeyRotationProgress{}
    |> KeyRotationProgress.changeset(%{
      schema_name: schema_name,
      table_name: to_string(table_name),
      from_cipher_tag: from_tag,
      to_cipher_tag: to_tag,
      rotation_id: rotation_id,
      total_records: total,
      status: "pending"
    })
    |> Repo.insert()
  end

  @doc """
  Gets existing progress for a schema rotation.
  """
  def get_progress(schema_name, from_tag, to_tag) do
    Repo.get_by(KeyRotationProgress,
      schema_name: schema_name,
      from_cipher_tag: from_tag,
      to_cipher_tag: to_tag
    )
  end

  @doc """
  Gets the current active rotation_id (the most recent one with pending/in_progress status).
  Returns nil if there's no active rotation.
  """
  def current_rotation_id do
    KeyRotationProgress
    |> where([p], p.status in ["pending", "in_progress"])
    |> order_by([p], desc: p.inserted_at)
    |> limit(1)
    |> select([p], p.rotation_id)
    |> Repo.one()
  end

  @doc """
  Gets all distinct rotation_ids ordered by most recent first.
  """
  def list_rotation_ids do
    KeyRotationProgress
    |> select([p], %{
      rotation_id: p.rotation_id,
      from_cipher_tag: p.from_cipher_tag,
      to_cipher_tag: p.to_cipher_tag,
      inserted_at: min(p.inserted_at)
    })
    |> group_by([p], [p.rotation_id, p.from_cipher_tag, p.to_cipher_tag])
    |> order_by([p], desc: min(p.inserted_at))
    |> Repo.all()
  end

  @doc """
  Gets all rotation progress records.
  """
  def list_progress do
    KeyRotationProgress
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets all rotation progress records for a specific rotation_id.
  """
  def list_progress_for_rotation(rotation_id) do
    KeyRotationProgress
    |> where([p], p.rotation_id == ^rotation_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets all in-progress or pending rotations.
  """
  def list_active_rotations do
    KeyRotationProgress
    |> where([p], p.status in ["pending", "in_progress"])
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Marks a rotation as started.
  """
  def start_rotation(progress_id) do
    progress = Repo.get!(KeyRotationProgress, progress_id)

    result =
      progress
      |> KeyRotationProgress.changeset(%{
        status: "in_progress",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    case result do
      {:ok, updated} -> broadcast({:progress_updated, updated})
      _ -> :ok
    end

    result
  end

  @doc """
  Updates progress after processing a batch.
  """
  def update_progress(progress_id, processed_count, last_id, failed_count \\ 0) do
    progress = Repo.get!(KeyRotationProgress, progress_id)

    new_processed = progress.processed_records + processed_count
    new_failed = progress.failed_records + failed_count

    status =
      if new_processed + new_failed >= progress.total_records,
        do: "completed",
        else: "in_progress"

    attrs = %{
      processed_records: new_processed,
      failed_records: new_failed,
      last_processed_id: last_id,
      status: status
    }

    attrs =
      if status == "completed",
        do: Map.put(attrs, :completed_at, DateTime.utc_now() |> DateTime.truncate(:second)),
        else: attrs

    result =
      progress
      |> KeyRotationProgress.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} -> broadcast({:progress_updated, updated})
      _ -> :ok
    end

    result
  end

  @doc """
  Marks a rotation as completed.
  """
  def complete_rotation(progress_id) do
    progress = Repo.get!(KeyRotationProgress, progress_id)

    result =
      progress
      |> KeyRotationProgress.changeset(%{
        status: "completed",
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()

    case result do
      {:ok, updated} -> broadcast({:progress_updated, updated})
      _ -> :ok
    end

    result
  end

  @doc """
  Marks a rotation as failed with an error message.
  """
  def fail_rotation(progress_id, error_message) do
    progress = Repo.get!(KeyRotationProgress, progress_id)

    existing_log = progress.error_log || ""
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    new_log = "#{existing_log}[#{timestamp}] #{error_message}\n"

    result =
      progress
      |> KeyRotationProgress.changeset(%{
        status: "failed",
        error_log: new_log
      })
      |> Repo.update()

    case result do
      {:ok, updated} -> broadcast({:progress_updated, updated})
      _ -> :ok
    end

    result
  end

  @doc """
  Appends an error message to the progress log without changing status.
  """
  def append_error(progress_id, error_message) do
    progress = Repo.get!(KeyRotationProgress, progress_id)

    existing_log = progress.error_log || ""
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    new_log = "#{existing_log}[#{timestamp}] #{error_message}\n"

    progress
    |> KeyRotationProgress.changeset(%{error_log: new_log})
    |> Repo.update()
  end

  @doc """
  Cancels all pending/in_progress rotations by deleting their progress records.
  """
  def cancel_rotation do
    {count, _} =
      KeyRotationProgress
      |> where([p], p.status in ["pending", "in_progress"])
      |> Repo.delete_all()

    broadcast({:rotation_cancelled, count})
    {:ok, count}
  end

  @doc """
  Fetches a batch of records from a schema for rotation.

  Records are fetched in order by ID, starting after `after_id` if provided.
  """
  def fetch_batch(schema_module, batch_size, after_id \\ nil) do
    query =
      schema_module
      |> order_by([r], asc: r.id)
      |> limit(^batch_size)

    query =
      if after_id do
        where(query, [r], r.id > ^after_id)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Re-encrypts a single record's encrypted fields.

  This decrypts with the current vault (which can use any configured cipher)
  and re-encrypts with the default cipher.
  """
  def rotate_record(record) do
    schema_module = record.__struct__
    fields = encrypted_fields(schema_module)

    changes =
      Enum.reduce(fields, %{}, fn field, acc ->
        value = Map.get(record, field)

        if value != nil do
          rotated = rotate_field_value(value, schema_module.__schema__(:type, field))
          Map.put(acc, field, rotated)
        else
          acc
        end
      end)

    if map_size(changes) > 0 do
      record
      |> Ecto.Changeset.change(changes)
      |> Repo.update()
    else
      {:ok, record}
    end
  end

  defp rotate_field_value(value, Mosslet.Encrypted.Binary) do
    case Vault.decrypt(value) do
      {:ok, plaintext} -> Vault.encrypt!(plaintext)
      {:error, _} -> value
    end
  end

  defp rotate_field_value(value, {:map, Mosslet.Encrypted.Binary}) when is_map(value) do
    Enum.into(value, %{}, fn {k, v} ->
      rotated =
        case Vault.decrypt(v) do
          {:ok, plaintext} -> Vault.encrypt!(plaintext)
          {:error, _} -> v
        end

      {k, rotated}
    end)
  end

  defp rotate_field_value(value, _), do: value

  @doc """
  Counts total records in a schema.
  """
  def count_records(schema_module) do
    Repo.aggregate(schema_module, :count)
  end

  @doc """
  Gets overall rotation status summary for a specific rotation_id.
  If no rotation_id is provided, uses the current active rotation.
  """
  def rotation_summary(rotation_id \\ nil) do
    rotation_id = rotation_id || current_rotation_id()

    progress_list =
      if rotation_id do
        list_progress_for_rotation(rotation_id)
      else
        []
      end

    total_records = Enum.sum(Enum.map(progress_list, & &1.total_records))
    processed_records = Enum.sum(Enum.map(progress_list, & &1.processed_records))
    failed_records = Enum.sum(Enum.map(progress_list, & &1.failed_records))

    %{
      rotation_id: rotation_id,
      total_schemas: length(progress_list),
      total_records: total_records,
      processed_records: processed_records,
      failed_records: failed_records,
      progress_percentage:
        if(total_records > 0, do: round(processed_records / total_records * 100), else: 0),
      by_status:
        Enum.group_by(progress_list, & &1.status)
        |> Enum.into(%{}, fn {k, v} -> {k, length(v)} end)
    }
  end

  @doc """
  Checks if there's an active rotation in progress.
  """
  def rotation_in_progress? do
    KeyRotationProgress
    |> where([p], p.status in ["pending", "in_progress"])
    |> Repo.exists?()
  end

  @doc """
  Initiates key rotation from the base key (CLOAK_KEY) to the new key (CLOAK_KEY_NEW).

  Requires CLOAK_KEY_NEW to be set in the environment.
  Creates progress records for all encrypted schemas.
  """
  def initiate_rotation do
    unless Vault.rotation_in_progress?() do
      {:error, :no_new_key_configured}
    else
      from_tag = Vault.base_cipher_tag()
      to_tag = Vault.current_cipher_tag()

      if from_tag == to_tag do
        {:error, :same_cipher}
      else
        do_initiate_rotation(from_tag, to_tag)
      end
    end
  end

  @doc """
  Initiates key rotation from a specific cipher tag to the current default.
  Use this when you have additional retired keys to migrate.
  """
  def initiate_rotation(from_tag) do
    to_tag = Vault.current_cipher_tag()

    if from_tag == to_tag do
      {:error, :same_cipher}
    else
      do_initiate_rotation(from_tag, to_tag)
    end
  end

  defp do_initiate_rotation(from_tag, to_tag) do
    rotation_id = Ecto.UUID.generate()

    results =
      @encrypted_schemas
      |> Enum.map(fn {schema_module, _table} ->
        create_progress(schema_module, from_tag, to_tag, rotation_id)
      end)

    errors = Enum.filter(results, fn {status, _} -> status == :error end)

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, p} -> p end)}
    else
      {:error, errors}
    end
  end
end
