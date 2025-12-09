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
  alias Mosslet.Repo
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
  Gets all encrypted fields for a schema module (including HMAC).
  """
  def encrypted_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn field ->
      type = schema_module.__schema__(:type, field)
      is_encrypted_type?(type)
    end)
  end

  @doc """
  Gets only the rotatable encrypted fields for a schema module (excludes HMAC).
  HMAC fields are deterministic hashes and cannot be re-encrypted without the original plaintext.
  """
  def rotatable_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn field ->
      type = schema_module.__schema__(:type, field)
      is_rotatable_type?(type)
    end)
  end

  @doc """
  Gets the HMAC fields for a schema module.
  These fields use deterministic hashing and cannot be rotated.
  """
  def hmac_fields(schema_module) do
    schema_module.__schema__(:fields)
    |> Enum.filter(fn field ->
      type = schema_module.__schema__(:type, field)
      is_hmac_type?(type)
    end)
  end

  @rotatable_encrypted_types [
    Mosslet.Encrypted.Binary,
    Mosslet.Encrypted.DateTime,
    Mosslet.Encrypted.Date,
    Mosslet.Encrypted.Float,
    Mosslet.Encrypted.IntegerList,
    Mosslet.Encrypted.Integer,
    Mosslet.Encrypted.Map,
    Mosslet.Encrypted.NaiveDateTime,
    Mosslet.Encrypted.StringList,
    Mosslet.Encrypted.Time
  ]

  @hmac_types [
    Mosslet.Encrypted.HMAC
  ]

  @all_encrypted_types @rotatable_encrypted_types ++ @hmac_types

  defp is_encrypted_type?(type) when type in @all_encrypted_types, do: true
  defp is_encrypted_type?(_), do: false

  defp is_rotatable_type?(type) when type in @rotatable_encrypted_types, do: true
  defp is_rotatable_type?(_), do: false

  defp is_hmac_type?(type) when type in @hmac_types, do: true
  defp is_hmac_type?(_), do: false

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
  HMAC fields are skipped since they are deterministic hashes that cannot be re-encrypted.

  This decrypts with the current vault (which can use any configured cipher)
  and re-encrypts with the default cipher.
  """
  def rotate_record(record) do
    schema_module = record.__struct__
    fields = rotatable_fields(schema_module)

    changeset =
      Enum.reduce(fields, Ecto.Changeset.change(record), fn field, changeset ->
        value = Map.get(record, field)

        if value != nil do
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
    fields = rotatable_fields(related_module)

    Enum.reduce(fields, struct, fn field, acc ->
      value = Map.get(acc, field)

      if value != nil do
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

  @doc """
  Extracts the cipher tag from encrypted binary data.

  Cloak's AES.GCM format stores the tag at the beginning:
  - Type (1 byte): 0x01 for string tags
  - Length (1 byte): length of the tag
  - Tag value (n bytes): the actual tag string

  Returns {:ok, tag} or {:error, reason}.
  """
  def extract_cipher_tag(nil), do: {:ok, nil}

  def extract_cipher_tag(<<0x01, length, tag::binary-size(length), _rest::binary>>)
      when length > 0 do
    {:ok, tag}
  end

  def extract_cipher_tag(<<type, _rest::binary>>) when type != 0x01 do
    {:error, :unknown_tag_type}
  end

  def extract_cipher_tag(_) do
    {:error, :invalid_format}
  end

  @doc """
  Extracts cipher tags from all rotatable fields of a record.
  Returns a map of field => tag.
  """
  def extract_record_cipher_tags(record) do
    schema_module = record.__struct__
    fields = rotatable_fields(schema_module)

    Enum.reduce(fields, %{}, fn field, acc ->
      value = Map.get(record, field)

      case extract_cipher_tag(value) do
        {:ok, nil} -> acc
        {:ok, tag} -> Map.put(acc, field, tag)
        {:error, _} -> acc
      end
    end)
  end

  @doc """
  Checks if a record has any fields encrypted with the specified cipher tag.
  """
  def record_uses_cipher_tag?(record, target_tag) do
    tags = extract_record_cipher_tags(record)

    Enum.any?(tags, fn {_field, tag} -> tag == target_tag end)
  end

  @doc """
  Scans a schema for records that still use a specific cipher tag.
  Returns a summary of affected records.

  This queries the database directly to read raw encrypted values,
  bypassing Cloak's automatic decryption.

  Options:
  - :limit - maximum number of records to scan (default: 1000)
  - :sample_records - number of sample record IDs to return (default: 10)
  """
  def scan_schema_for_cipher_tag(schema_module, target_tag, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    sample_size = Keyword.get(opts, :sample_records, 10)
    fields = rotatable_fields(schema_module)
    table_name = schema_module.__schema__(:source)

    if fields == [] do
      %{
        schema: inspect(schema_module),
        fields: [],
        total_scanned: 0,
        records_with_old_key: 0,
        sample_record_ids: [],
        field_breakdown: %{}
      }
    else
      field_names = Enum.map(fields, &Atom.to_string/1) |> Enum.join(", ")
      query = "SELECT id::text, #{field_names} FROM #{table_name} ORDER BY id LIMIT $1"

      result = Repo.query!(query, [limit])
      id_col_idx = Enum.find_index(result.columns, &(&1 == "id"))

      field_indices =
        Enum.map(fields, fn field ->
          {field, Enum.find_index(result.columns, &(&1 == Atom.to_string(field)))}
        end)

      {affected_records, field_breakdown} =
        Enum.reduce(result.rows, {[], %{}}, fn row, {affected, breakdown} ->
          record_id = Enum.at(row, id_col_idx)

          affected_fields =
            Enum.filter(field_indices, fn {_field, idx} ->
              raw_value = Enum.at(row, idx)

              case extract_cipher_tag(raw_value) do
                {:ok, ^target_tag} -> true
                _ -> false
              end
            end)
            |> Enum.map(fn {field, _} -> field end)

          if affected_fields != [] do
            new_breakdown =
              Enum.reduce(affected_fields, breakdown, fn field, acc ->
                Map.update(acc, field, 1, &(&1 + 1))
              end)

            {[record_id | affected], new_breakdown}
          else
            {affected, breakdown}
          end
        end)

      sample_ids = Enum.take(affected_records, sample_size)

      %{
        schema: inspect(schema_module),
        fields: fields,
        total_scanned: length(result.rows),
        records_with_old_key: length(affected_records),
        sample_record_ids: sample_ids,
        field_breakdown: field_breakdown
      }
    end
  end

  @doc """
  Scans all encrypted schemas for records using a specific cipher tag.
  Returns a comprehensive report of all affected schemas and records.
  """
  def scan_all_for_cipher_tag(target_tag, opts \\ []) do
    schemas = encrypted_schemas()

    results =
      Enum.map(schemas, fn {schema_module, _table} ->
        scan_schema_for_cipher_tag(schema_module, target_tag, opts)
      end)
      |> Enum.reject(fn result -> result.records_with_old_key == 0 end)

    total_affected =
      results
      |> Enum.map(& &1.records_with_old_key)
      |> Enum.sum()

    %{
      target_tag: target_tag,
      schemas_affected: length(results),
      total_records_affected: total_affected,
      by_schema: results
    }
  end

  @doc """
  Gets a detailed breakdown of cipher tag usage across all schemas.
  Useful for monitoring rotation progress and identifying remaining work.

  Queries the database directly to read raw encrypted values.
  """
  def cipher_tag_usage_report(opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)
    schemas = encrypted_schemas()

    results =
      Enum.map(schemas, fn {schema_module, table} ->
        fields = rotatable_fields(schema_module)

        if fields == [] do
          nil
        else
          field_names = Enum.map(fields, &Atom.to_string/1) |> Enum.join(", ")
          query = "SELECT #{field_names} FROM #{table} LIMIT $1"

          result = Repo.query!(query, [limit])

          field_indices =
            Enum.map(fields, fn field ->
              {field, Enum.find_index(result.columns, &(&1 == Atom.to_string(field)))}
            end)

          tag_counts =
            Enum.reduce(result.rows, %{}, fn row, acc ->
              Enum.reduce(field_indices, acc, fn {field, idx}, field_acc ->
                raw_value = Enum.at(row, idx)

                case extract_cipher_tag(raw_value) do
                  {:ok, nil} ->
                    field_acc

                  {:ok, tag} ->
                    key = "#{field}:#{tag}"
                    Map.update(field_acc, key, 1, &(&1 + 1))

                  {:error, _} ->
                    field_acc
                end
              end)
            end)

          %{
            schema: inspect(schema_module),
            table: table,
            rotatable_fields: fields,
            hmac_fields: hmac_fields(schema_module),
            records_sampled: length(result.rows),
            cipher_tag_distribution: tag_counts
          }
        end
      end)
      |> Enum.reject(&is_nil/1)

    current_tag = Vault.current_cipher_tag()
    base_tag = Vault.base_cipher_tag()

    %{
      current_cipher_tag: current_tag,
      base_cipher_tag: base_tag,
      rotation_in_progress: Vault.rotation_in_progress?(),
      schemas: results
    }
  end

  @doc """
  Scans for users that have records using an old cipher tag.
  Returns a list of user IDs whose data needs rotation.

  This is useful for tracking which specific users still have data
  encrypted with the old key.

  Queries the database directly to read raw encrypted values.
  """
  def scan_users_for_cipher_tag(target_tag, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    schema_module = Mosslet.Accounts.User
    fields = rotatable_fields(schema_module)
    table_name = schema_module.__schema__(:source)

    field_names = Enum.map(fields, &Atom.to_string/1) |> Enum.join(", ")
    query = "SELECT id::text, #{field_names} FROM #{table_name} ORDER BY id LIMIT $1"

    result = Repo.query!(query, [limit])
    id_col_idx = Enum.find_index(result.columns, &(&1 == "id"))

    field_indices =
      Enum.map(fields, fn field ->
        {field, Enum.find_index(result.columns, &(&1 == Atom.to_string(field)))}
      end)

    affected_user_ids =
      Enum.filter(result.rows, fn row ->
        Enum.any?(field_indices, fn {_field, idx} ->
          raw_value = Enum.at(row, idx)

          case extract_cipher_tag(raw_value) do
            {:ok, ^target_tag} -> true
            _ -> false
          end
        end)
      end)
      |> Enum.map(fn row -> Enum.at(row, id_col_idx) end)

    %{
      target_tag: target_tag,
      total_scanned: length(result.rows),
      users_with_old_key: length(affected_user_ids),
      user_ids: affected_user_ids
    }
  end
end
