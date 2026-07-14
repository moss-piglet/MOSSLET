defmodule Mosslet.VoiceNotes do
  @moduledoc """
  E2EE voice notes context (Task #383, see `docs/VOICE_NOTES_DESIGN.md`).

  Orchestrates the zero-knowledge lifecycle of a voice note delivered into a
  Conversation (DM) or a Group (personal/family/business circle). Reuses the ZK
  file-sharing pipeline (`Mosslet.Files` / `docs/ZK_FILE_SHARING_DESIGN.md`)
  verbatim with ZERO new crypto:

    * the browser records audio, generates a per-note `file_key`, encrypts the
      blob with `encryptSecretbox`, and uploads the opaque ciphertext (chunked)
      to object storage via `SharedFileStorage.put_encrypted_blob/1`;
    * the `file_key` is sealed per recipient with `sealForUser` (Cat-5 hybrid);
    * the recipient set is **server-authoritative** — resolved here from cohort
      membership (I1), never trusted from the client;
    * the server never sees the `file_key` or the plaintext audio (I2/I3).

  All writes go through `Repo.transaction_on_primary/1`; all FKs are stamped
  server-side (never `cast`).
  """
  import Ecto.Query, warn: false

  alias Mosslet.Accounts.User
  alias Mosslet.Conversations
  alias Mosslet.Conversations.{Conversation, UserConversation}
  alias Mosslet.FileUploads.SharedFileStorage
  alias Mosslet.Groups
  alias Mosslet.Groups.{Group, UserGroup}
  alias Mosslet.Repo
  alias Mosslet.VoiceNotes.{UserVoiceNote, VoiceNote}

  # v1 limits (defense in depth alongside the client-side caps — §4.3).
  @max_duration_ms 5 * 60 * 1000
  # Ciphertext is a little larger than plaintext; 25 MB is comfortably within
  # the object-store + secretbox limits for a 5-minute opus/aac clip.
  @max_size_bytes 25 * 1024 * 1024

  @doc "Server-enforced maximum voice-note duration (ms)."
  def max_duration_ms, do: @max_duration_ms

  @doc "Server-enforced maximum encrypted blob size (bytes)."
  def max_size_bytes, do: @max_size_bytes

  ## Recipient resolution (server-authoritative — I1) ------------------------

  @doc """
  Recipients for a DM: both conversation participants (the two `UserConversation`
  users). Returns `[%{user_id, public_key, pq_public_key}]` — the shape the
  browser needs to `sealForUser` per recipient (sender included).
  """
  def recipients_for_conversation(%Conversation{} = conversation) do
    conversation
    |> conversation_participant_ids()
    |> users_by_ids()
    |> Enum.map(&recipient_entry/1)
  end

  @doc """
  Recipients for a group: the confirmed members. Returns
  `[%{user_id, public_key, pq_public_key}]`.
  """
  def recipients_for_group(%Group{} = group) do
    group
    |> confirmed_member_user_ids()
    |> users_by_ids()
    |> Enum.map(&recipient_entry/1)
  end

  ## Create (phase 1) --------------------------------------------------------

  @doc """
  ZK phase-1 insert. The browser already uploaded the opaque blob and produced
  the encrypted `checksum`. Validates that `sender` is a member of the cohort
  and that the blob is within size limits, then inserts the `VoiceNote` with
  `sender_id` + the cohort FK stamped server-side. The raw `file_key` NEVER
  reaches the server.

  `cohort` is a `Conversation` or a `Group`.
  """
  def create_voice_note_zk(cohort, %User{} = sender, attrs) do
    attrs = normalize_keys(attrs)

    cond do
      not member_of_cohort?(cohort, sender.id) ->
        {:error, :not_a_member}

      oversized?(attrs) ->
        {:error, :too_large}

      too_long?(attrs) ->
        {:error, :too_long}

      true ->
        changeset = VoiceNote.insert_changeset(cohort, sender, attrs)

        case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
          {:ok, {:ok, voice_note}} -> {:ok, voice_note}
          {:ok, {:error, changeset}} -> {:error, changeset}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  ## Finalize (phase 2) ------------------------------------------------------

  @doc """
  ZK phase-2. Inserts one `UserVoiceNote` per ELIGIBLE recipient — dropping any
  `user_id` that is not a current cohort member (I1). `sealed_recipients` is a
  list of `%{"user_id" => id, "sealed_key" => base64}` produced in the browser.

  Returns `{:ok, inserted_count}`.
  """
  def finalize_voice_note_zk(%VoiceNote{} = voice_note, sealed_recipients)
      when is_list(sealed_recipients) do
    eligible_ids = eligible_recipient_ids(voice_note)

    inserted =
      sealed_recipients
      |> Enum.map(&normalize_keys/1)
      |> Enum.filter(fn entry ->
        is_binary(entry["sealed_key"]) and entry["user_id"] in eligible_ids
      end)
      |> Enum.reduce(0, fn entry, acc ->
        changeset =
          UserVoiceNote.insert_changeset(voice_note, entry["user_id"], entry["sealed_key"])

        case Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) do
          {:ok, {:ok, _}} -> acc + 1
          _ -> acc
        end
      end)

    {:ok, inserted}
  end

  ## Read path ---------------------------------------------------------------

  def get_voice_note(id) when is_binary(id), do: Repo.get(VoiceNote, id)
  def get_voice_note!(id) when is_binary(id), do: Repo.get!(VoiceNote, id)

  @doc """
  The requester's sealed `file_key` row for a voice note, or `nil`. This IS the
  read-authorization check: only a user who holds a `UserVoiceNote` row may play.
  """
  def get_user_voice_note(%VoiceNote{} = voice_note, %User{} = user) do
    Repo.get_by(UserVoiceNote, voice_note_id: voice_note.id, user_id: user.id)
  end

  @doc """
  Authorizes the requester (must hold a `UserVoiceNote` row), then relays the
  opaque ciphertext inline (`get_encrypted_blob`) so the browser can decrypt it
  without hitting object storage directly (avoids CORS — matches the #349 fix).
  The server never decrypts (I2).

  Returns `{:ok, ciphertext_binary}` or `{:error, :unauthorized | :not_found}`.
  """
  def blob_for(%VoiceNote{} = voice_note, %User{} = user) do
    if get_user_voice_note(voice_note, user) do
      case SharedFileStorage.get_encrypted_blob(voice_note.storage_path) do
        {:ok, ciphertext} -> {:ok, ciphertext}
        _ -> {:error, :not_found}
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc "Transparency (I4): the users who currently hold a sealed key (readers)."
  def list_readers(%VoiceNote{} = voice_note) do
    User
    |> join(:inner, [u], uvn in UserVoiceNote, on: uvn.user_id == u.id)
    |> where([_u, uvn], uvn.voice_note_id == ^voice_note.id)
    |> Repo.all()
  end

  ## Delete (I5) -------------------------------------------------------------

  @doc """
  Deletes a voice note: removes the blob + all sealed keys + the record (I5).
  Authorized to the sender (or, for a group note, a circle owner/admin/moderator).
  Never claims to recall already-downloaded copies.

  Note: the referencing `Message` / `GroupMessage` has `voice_note_id` with
  `on_delete: :delete_all`, so the stream bubble is removed together with the
  note. Callers should broadcast the message deletion for live removal.
  """
  def delete_voice_note(%VoiceNote{} = voice_note, %User{} = actor) do
    if can_delete?(voice_note, actor) do
      storage_path = voice_note.storage_path

      result =
        Repo.transaction_on_primary(fn ->
          Repo.delete_all(from(uvn in UserVoiceNote, where: uvn.voice_note_id == ^voice_note.id))

          Repo.delete(voice_note)
        end)

      case result do
        {:ok, {:ok, _}} ->
          SharedFileStorage.delete_blob(storage_path)
          {:ok, :deleted}

        {:ok, {:error, reason}} ->
          {:error, reason}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :unauthorized}
    end
  end

  ## Teardown (blob cleanup when a cohort is deleted) ------------------------

  @doc "Deletes all voice notes (blobs + sealed keys + records) for a conversation."
  def delete_all_for_conversation(%Conversation{id: id}),
    do: delete_all_where(conversation_id: id)

  def delete_all_for_conversation(id) when is_binary(id),
    do: delete_all_where(conversation_id: id)

  @doc "Deletes all voice notes (blobs + sealed keys + records) for a group."
  def delete_all_for_group(%Group{id: id}), do: delete_all_where(group_id: id)
  def delete_all_for_group(id) when is_binary(id), do: delete_all_where(group_id: id)

  ## Internals ---------------------------------------------------------------

  defp delete_all_where(clauses) do
    notes =
      VoiceNote
      |> where(^clauses)
      |> select([vn], %{id: vn.id, storage_path: vn.storage_path})
      |> Repo.all()

    ids = Enum.map(notes, & &1.id)

    result =
      Repo.transaction_on_primary(fn ->
        Repo.delete_all(from(uvn in UserVoiceNote, where: uvn.voice_note_id in ^ids))
        Repo.delete_all(from(vn in VoiceNote, where: vn.id in ^ids))
      end)

    case result do
      {:ok, _} ->
        Enum.each(notes, &SharedFileStorage.delete_blob(&1.storage_path))
        {:ok, length(notes)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp eligible_recipient_ids(%VoiceNote{conversation_id: cid, group_id: gid}) do
    cond do
      is_binary(cid) ->
        case Conversations.get_conversation!(cid) do
          %Conversation{} = c -> conversation_participant_ids(c)
          _ -> []
        end

      is_binary(gid) ->
        gid |> Groups.get_group!() |> confirmed_member_user_ids()

      true ->
        []
    end
  end

  defp member_of_cohort?(%Conversation{} = conversation, user_id),
    do: user_id in conversation_participant_ids(conversation)

  defp member_of_cohort?(%Group{} = group, user_id),
    do: user_id in confirmed_member_user_ids(group)

  defp conversation_participant_ids(%Conversation{} = conversation) do
    UserConversation
    |> where([uc], uc.conversation_id == ^conversation.id)
    |> select([uc], uc.user_id)
    |> Repo.all()
  end

  defp confirmed_member_user_ids(%Group{} = group) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id)
    |> where([ug], not is_nil(ug.confirmed_at))
    |> select([ug], ug.user_id)
    |> Repo.all()
  end

  defp can_delete?(%VoiceNote{} = voice_note, %User{} = actor) do
    cond do
      voice_note.sender_id == actor.id ->
        true

      is_binary(voice_note.group_id) ->
        group = Groups.get_group!(voice_note.group_id)
        admin_or_owner_of_group?(group, actor.id)

      true ->
        false
    end
  end

  defp admin_or_owner_of_group?(%Group{} = group, user_id) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id and ug.user_id == ^user_id)
    |> where([ug], ug.role in [:owner, :admin, :moderator])
    |> Repo.exists?()
  end

  defp recipient_entry(%User{} = user) do
    %{
      user_id: user.id,
      public_key: user.key_pair["public"],
      pq_public_key: user.pq_public_key
    }
  end

  defp users_by_ids([]), do: []
  defp users_by_ids(ids), do: User |> where([u], u.id in ^ids) |> Repo.all()

  defp oversized?(attrs) do
    size = attrs["size_bytes"]
    is_integer(size) and size > @max_size_bytes
  end

  defp too_long?(attrs) do
    duration = attrs["duration_ms"]
    is_integer(duration) and duration > @max_duration_ms
  end

  defp normalize_keys(entry), do: Map.new(entry, fn {k, v} -> {to_string(k), v} end)
end
