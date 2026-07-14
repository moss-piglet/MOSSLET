defmodule Mosslet.VoiceNotes.VoiceNote do
  @moduledoc """
  E2EE voice note record (Task #383, see `docs/VOICE_NOTES_DESIGN.md`).

  A `VoiceNote` is the metadata for ONE browser-encrypted audio blob delivered
  into a Conversation (DM) or a Group (personal/family/business circle). Reuses
  the ZK file-sharing model (`docs/ZK_FILE_SHARING_DESIGN.md`) verbatim: a fresh
  per-note `file_key` (NaCl secretbox) encrypts the audio in the browser; the
  opaque ciphertext lives on object storage (Tigris); only the Cloak-wrapped
  pointer + encrypted checksum live in Postgres. The per-recipient sealed
  `file_key` lives on `UserVoiceNote.key` (mirrors `UserSharedFile`). The server
  never sees the `file_key` or the plaintext audio (invariants I2/I3).

  Exactly one of `conversation_id` / `group_id` is set (CHECK constraint + the
  validation below). All FKs are stamped server-side by `Mosslet.VoiceNotes` —
  never `cast` from user params (encryption/security guidelines).
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Conversations.Conversation
  alias Mosslet.Encrypted
  alias Mosslet.Groups.Group
  alias Mosslet.VoiceNotes.UserVoiceNote

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "voice_notes" do
    # Cloak-wrapped ciphertext (`Encrypted.Binary`). `storage_path` is the only
    # required encrypted field; `checksum` is browser-encrypted-with-file_key
    # (I7) and may be absent for an older/limited client.
    field :storage_path, Encrypted.Binary, redact: true
    field :checksum, Encrypted.Binary, redact: true

    # Plaintext, non-secret media metadata for playback + UX.
    field :media_type, :string, default: "audio"
    field :mime_hint, :string
    field :duration_ms, :integer
    field :size_bytes, :integer

    belongs_to :sender, User
    belongs_to :conversation, Conversation
    belongs_to :group, Group

    has_many :user_voice_notes, UserVoiceNote

    timestamps()
  end

  @type t :: %__MODULE__{}

  @doc """
  ZK insert changeset for a voice note. The browser produced the opaque blob
  (already uploaded) and the encrypted metadata. `sender_id` and the cohort FK
  (`conversation_id` OR `group_id`) are stamped server-side (server-
  authoritative — never trust the client for these). The raw `file_key` NEVER
  reaches the server.

  `cohort` is either a `Conversation` or a `Group`.
  """
  def insert_changeset(cohort, %User{} = sender, attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :storage_path,
      :checksum,
      :media_type,
      :mime_hint,
      :duration_ms,
      :size_bytes
    ])
    |> validate_required([:storage_path, :media_type])
    |> put_change(:sender_id, sender.id)
    |> put_cohort(cohort)
    |> validate_exactly_one_cohort()
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:conversation_id)
    |> foreign_key_constraint(:group_id)
    |> check_constraint(:conversation_id, name: :voice_notes_exactly_one_cohort)
  end

  defp put_cohort(changeset, %Conversation{} = conversation) do
    put_change(changeset, :conversation_id, conversation.id)
  end

  defp put_cohort(changeset, %Group{} = group) do
    put_change(changeset, :group_id, group.id)
  end

  defp validate_exactly_one_cohort(changeset) do
    conversation_id = get_field(changeset, :conversation_id)
    group_id = get_field(changeset, :group_id)

    case {conversation_id, group_id} do
      {nil, nil} ->
        add_error(changeset, :conversation_id, "a voice note must target a conversation or group")

      {c, g} when not is_nil(c) and not is_nil(g) ->
        add_error(
          changeset,
          :conversation_id,
          "a voice note cannot target both a conversation and a group"
        )

      _ ->
        changeset
    end
  end
end
