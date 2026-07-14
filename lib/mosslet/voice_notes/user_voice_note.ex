defmodule Mosslet.VoiceNotes.UserVoiceNote do
  @moduledoc """
  Per-recipient sealed `file_key` for a `VoiceNote` (Task #383, see
  `docs/VOICE_NOTES_DESIGN.md` §3.2).

  Mirrors `UserSharedFile`/`UserGroup`/`UserPost`: one row per cohort member,
  holding the `file_key` sealed FOR that member's public key via `sealForUser`
  (Cat-5 hybrid ML-KEM-1024 + X25519). Each member unseals it with their OWN
  private key in the browser; the server can never assemble a usable `file_key`.

  `user_id` is set programmatically (never `cast`).
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.VoiceNotes.VoiceNote

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_voice_notes" do
    # The file_key sealed for this user's public key via sealForUser. Cloak-
    # wrapped ciphertext (`Encrypted.Binary`).
    field :key, Encrypted.Binary, redact: true

    belongs_to :voice_note, VoiceNote
    belongs_to :user, User

    timestamps()
  end

  @type t :: %__MODULE__{}

  @doc """
  ZK insert changeset for one recipient's sealed `file_key`. `voice_note_id` and
  `user_id` are stamped server-side (server-authoritative recipient set — I1);
  `sealed_key` is the opaque base64 sealed blob produced in the browser.
  """
  def insert_changeset(%VoiceNote{} = voice_note, recipient_user_id, sealed_key)
      when is_binary(recipient_user_id) and is_binary(sealed_key) do
    %__MODULE__{}
    |> change(%{key: sealed_key})
    |> put_change(:voice_note_id, voice_note.id)
    |> put_change(:user_id, recipient_user_id)
    |> unique_constraint([:voice_note_id, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
