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

  Schemas with encrypted fields are auto-discovered at runtime by scanning
  all Ecto schemas for fields using `Mosslet.Encrypted.Binary` types.
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

  @doc """
  Returns a list of all schemas that have encrypted fields.

  Auto-discovers schemas by scanning all loaded modules under `Mosslet.*`
  for Ecto schemas with `Mosslet.Encrypted.Binary` field types.

  Embedded schemas are excluded since their data is stored in the parent
  schema's table and rotated when the parent is rotated.

  Returns a list of `{schema_module, table_name}` tuples.
  """
  def encrypted_schemas do
    {:ok, modules} = :application.get_key(:mosslet, :modules)

    modules
    |> Enum.filter(&ecto_schema_with_encrypted_fields?/1)
    |> Enum.reject(&embedded_schema?/1)
    |> Enum.map(fn module -> {module, module.__schema__(:source) |> String.to_atom()} end)
    |> Enum.sort_by(fn {mod, _} -> inspect(mod) end)
  end

  defp ecto_schema_with_encrypted_fields?(module) do
    Code.ensure_loaded(module)

    function_exported?(module, :__schema__, 1) and
      has_encrypted_fields?(module)
  end

  defp embedded_schema?(module) do
    module.__schema__(:source) == nil
  end

  defp has_encrypted_fields?(module) do
    module.__schema__(:fields)
    |> Enum.any?(fn field ->
      type = module.__schema__(:type, field)
      is_encrypted_type?(type)
    end)
  end

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

  @encrypted_types [
    Mosslet.Encrypted.Binary,
    Mosslet.Encrypted.DateTime,
    Mosslet.Encrypted.Date,
    Mosslet.Encrypted.Float,
    Mosslet.Encrypted.HMAC,
    Mosslet.Encrypted.IntegerList,
    Mosslet.Encrypted.Integer,
    Mosslet.Encrypted.Map,
    Mosslet.Encrypted.NaiveDateTime,
    Mosslet.Encrypted.StringList,
    Mosslet.Encrypted.Time
  ]

  defp is_encrypted_type?(type) when type in @encrypted_types, do: true
  defp is_encrypted_type?(_), do: false

  @doc """
  Creates progress tracking for a schema rotation with a given rotation_id.
  """
  def create_progress(schema_module, from_tag, to_tag, rotation_id) do
    schema_name = inspect(schema_module)
    table_name = schema_module.__schema__(:source)
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
  Resets a failed rotation to in_progress status so it can be resumed.
  The rotation will continue from the last_processed_id.
  """
  def resume_rotation(progress_id) do
    progress = Repo.get!(KeyRotationProgress, progress_id)

    if progress.status in ["failed", "stalled"] do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      new_log = "#{progress.error_log || ""}[#{timestamp}] Rotation resumed\n"

      result =
        progress
        |> KeyRotationProgress.changeset(%{
          status: "in_progress",
          error_log: new_log
        })
        |> Repo.update()

      case result do
        {:ok, updated} -> broadcast({:progress_updated, updated})
        _ -> :ok
      end

      result
    else
      {:error, :not_resumable}
    end
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
  Re-encrypts a single record's encrypted fields, including embedded schemas.

  This decrypts with the current vault (which can use any configured cipher)
  and re-encrypts with the default cipher.
  """
  def rotate_record(record) do
    schema_module = record.__struct__
    fields = encrypted_fields(schema_module)

    changeset =
      Enum.reduce(fields, Ecto.Changeset.change(record), fn field, changeset ->
        value = Map.get(record, field)

        if value != nil and value != "" and value != [] do
          Ecto.Changeset.force_change(changeset, field, value)
        else
          changeset
        end
      end)

    embed_changes = rotate_embeds(record, schema_module)
    changeset = Ecto.Changeset.change(changeset, embed_changes)

    if changeset.changes != %{} do
      Repo.update(changeset)
    else
      {:ok, record}
    end
  end

  defp rotate_embeds(record, schema_module) do
    schema_module.__schema__(:embeds)
    |> Enum.reduce(%{}, fn embed_field, acc ->
      embed_value = Map.get(record, embed_field)
      embed_type = schema_module.__schema__(:type, embed_field)

      case embed_type do
        {:parameterized, {Ecto.Embedded, %Ecto.Embedded{cardinality: :one, related: related}}} ->
          if embed_value do
            rotated = rotate_embedded_struct(embed_value, related)
            if rotated != embed_value, do: Map.put(acc, embed_field, rotated), else: acc
          else
            acc
          end

        {:parameterized, {Ecto.Embedded, %Ecto.Embedded{cardinality: :many, related: related}}} ->
          if is_list(embed_value) and embed_value != [] do
            rotated = Enum.map(embed_value, &rotate_embedded_struct(&1, related))
            if rotated != embed_value, do: Map.put(acc, embed_field, rotated), else: acc
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  defp rotate_embedded_struct(struct, related_module) do
    fields = encrypted_fields(related_module)

    Enum.reduce(fields, struct, fn field, acc ->
      value = Map.get(acc, field)

      if value != nil and value != "" and value != [] do
        Map.put(acc, field, value)
      else
        acc
      end
    end)
  end

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
      encrypted_schemas()
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
