defmodule Mosslet.Groups.GroupMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups.Group
  alias Mosslet.Groups.GroupMessageMention
  alias Mosslet.Groups.UserGroup

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "group_messages" do
    field :content, Encrypted.Binary, redact: true
    belongs_to :group, Group
    belongs_to :sender, UserGroup
    belongs_to :voice_note, Mosslet.VoiceNotes.VoiceNote
    has_many :mentions, GroupMessageMention

    timestamps()
  end

  @doc false
  def changeset(message, attrs, opts \\ []) do
    message
    |> cast(attrs, [:content, :sender_id, :group_id])
    |> validate_required([:content, :sender_id, :group_id])
    |> maybe_put_voice_note_id(opts)
    |> encrypt_attrs(opts)
  end

  # A voice note is delivered AS a group message referencing its VoiceNote
  # (docs/VOICE_NOTES_DESIGN.md §3.3). `voice_note_id` is set programmatically
  # from opts (never cast from user params).
  defp maybe_put_voice_note_id(changeset, opts) do
    case opts[:voice_note_id] do
      id when is_binary(id) -> put_change(changeset, :voice_note_id, id)
      _ -> changeset
    end
  end

  defp encrypt_attrs(changeset, opts) do
    cond do
      # Browser pre-encrypted content (ZK write path) — skip server-side encryption
      opts[:encrypted_content] ->
        put_change(changeset, :content, opts[:encrypted_content])

      changeset.valid? && opts[:user_group_key] && opts[:user] && opts[:key] ->
        d_user_group_key =
          if opts[:public?] do
            Encrypted.Users.Utils.decrypt_public_item_key(opts[:user_group_key])
          else
            case Encrypted.Users.Utils.decrypt_user_attrs_key(
                   opts[:user_group_key],
                   opts[:user],
                   opts[:key]
                 ) do
              {:ok, key} -> key
              _ -> nil
            end
          end

        if d_user_group_key do
          changeset
          |> put_change(
            :content,
            Utils.encrypt(%{
              key: d_user_group_key,
              payload: get_field(changeset, :content)
            })
          )
        else
          changeset
        end

      true ->
        changeset
    end
  end
end
