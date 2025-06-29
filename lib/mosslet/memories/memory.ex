defmodule Mosslet.Memories.Memory do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups.{Group, UserGroup}
  alias Mosslet.Memories.{Remark, UserMemory}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memories" do
    field :memory_url, Encrypted.Binary
    field :memory_url_hash, Encrypted.HMAC
    field :username, Encrypted.Binary
    field :username_hash, Encrypted.HMAC
    field :favs_list, {:array, :binary_id}, default: []
    field :favs_count, :integer, default: 0
    field :visibility, Ecto.Enum, values: [:public, :private, :connections], default: :private
    field :size, :decimal
    field :type, :string
    field :blurb, Encrypted.Binary
    field :blur, :boolean, default: false

    field :user_memory_map, :map, virtual: true

    embeds_many :shared_users, SharedUser, on_replace: :delete do
      @derive Jason.Encoder
      field :sender_id, :string, virtual: true
      field :username, :string, virtual: true
      field :current_user_id, :binary_id, virtual: true
      field :user_id, :binary_id
      field :blur, :boolean, default: false
      field :color, Ecto.Enum, values: [:emerald, :orange, :pink, :purple, :rose, :yellow, :zinc]
    end

    belongs_to :group, Group
    belongs_to :user, User
    belongs_to :user_group, UserGroup

    has_many :user_memories, UserMemory
    has_many :remarks, Remark, preload_order: [desc: :inserted_at]

    timestamps()
  end

  @doc false
  def changeset(memory, attrs, opts \\ []) do
    memory
    |> cast(attrs, [
      :memory_url,
      :blurb,
      :username,
      :favs_count,
      :favs_list,
      :user_id,
      :visibility,
      :size,
      :type,
      :group_id
    ])
    |> validate_required([:username, :user_id])
    |> validate_length(:blurb, max: 250)
    |> add_username_hash()
    |> add_memory_url_hash()
    |> validate_visibility(opts)
    |> encrypt_attrs(opts)
    |> cast_embed(:shared_users,
      with: &shared_user_changeset/2,
      sort_param: :shared_users_order,
      drop_param: :shared_users_delete
    )
  end

  def blur_changeset(memory, attrs, user, opts \\ []) do
    if memory.user_id == user.id do
      if memory.blur do
        change(memory, blur: false)
      else
        change(memory, blur: true)
      end
    else
      if opts[:blur] do
        memory
        |> cast(attrs, [])
        |> cast_embed(:shared_users, with: &shared_user_blur_changeset/2)
      end
    end
  end

  def shared_user_changeset(shared_user, attrs \\ %{}) do
    shared_user
    |> cast(attrs, [:sender_id, :username])
    |> validate_shared_username()
  end

  def shared_user_blur_changeset(shared_user, attrs) do
    if attrs.current_user_id && attrs.current_user_id == shared_user.user_id do
      shared_user
      |> change_shared_user_blur()
    else
      shared_user
      |> cast(attrs, [:blur])
    end
  end

  def change_shared_user_blur(shared_user) do
    if shared_user.blur do
      change(shared_user, blur: false)
    else
      change(shared_user, blur: true)
    end
  end

  defp add_username_hash(changeset) do
    if Map.has_key?(changeset.changes, :username) do
      changeset
      |> put_change(:username_hash, String.downcase(get_field(changeset, :username)))
    else
      changeset
    end
  end

  defp add_memory_url_hash(changeset) do
    if Map.has_key?(changeset.changes, :memory_url) do
      changeset
      |> put_change(:memory_url_hash, String.downcase(get_field(changeset, :memory_url)))
    else
      changeset
    end
  end

  defp validate_visibility(changeset, opts) do
    visibility = get_field(changeset, :visibility)

    case visibility do
      :public ->
        # |> add_error(:blurb, "Woopsy, public photos are not available yet.")
        changeset

      :private ->
        changeset

      :connections ->
        if Accounts.has_any_user_connections?(opts[:user]) do
          changeset
        else
          changeset |> add_error(:blurb, "Woopsy, first we need to make some connections.")
        end
    end
  end

  defp validate_shared_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 160)
    |> maybe_add_recipient_id_by_username()
  end

  # The recipient is either the user_id or reverse_user_id
  # of the connection.
  defp maybe_add_recipient_id_by_username(changeset) do
    username = get_change(changeset, :username, "")
    user_id = get_field(changeset, :sender_id)

    if recipient = Accounts.get_shared_user_by_username(user_id, username) do
      changeset
      |> put_change(:user_id, recipient.id)
    else
      changeset
      |> add_error(:username, "invalid or does not exist")
    end
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      body = get_change(changeset, :blurb)
      username = get_field(changeset, :username)
      visibility = get_field(changeset, :visibility)
      memory_url = get_field(changeset, :memory_url)
      memory_key = maybe_generate_memory_key(opts, visibility)

      case visibility do
        :public ->
          changeset
          |> put_change(:memory_url, Utils.encrypt(%{key: memory_key, payload: memory_url}))
          |> put_change(:blurb, maybe_encrypt_blurb(memory_key, body))
          |> put_change(:username, Utils.encrypt(%{key: memory_key, payload: username}))
          |> put_change(:user_memory_map, %{temp_key: memory_key})

        :private ->
          changeset
          |> put_change(:memory_url, Utils.encrypt(%{key: memory_key, payload: memory_url}))
          |> put_change(:blurb, maybe_encrypt_blurb(memory_key, body))
          |> put_change(:username, Utils.encrypt(%{key: memory_key, payload: username}))
          |> put_change(:user_memory_map, %{temp_key: memory_key})

        :connections ->
          changeset
          |> put_change(:memory_url, Utils.encrypt(%{key: memory_key, payload: memory_url}))
          |> put_change(:blurb, maybe_encrypt_blurb(memory_key, body))
          |> put_change(:username, Utils.encrypt(%{key: memory_key, payload: username}))
          |> put_change(:user_memory_map, %{temp_key: memory_key})

        _rest ->
          changeset |> add_error(:blurb, "There was an error determining the visibility.")
      end
    else
      changeset
    end
  end

  defp maybe_encrypt_blurb(memory_key, body) do
    if is_binary(body) do
      Utils.encrypt(%{key: memory_key, payload: body})
    else
      nil
    end
  end

  defp maybe_generate_memory_key(opts, visibility) do
    if opts[:update_memory] do
      case visibility do
        :public ->
          Encrypted.Users.Utils.decrypt_public_item_key(opts[:memory_key])

        _rest ->
          {:ok, d_memory_key} =
            Encrypted.Users.Utils.decrypt_user_attrs_key(
              opts[:memory_key],
              opts[:user],
              opts[:key]
            )

          d_memory_key
      end
    else
      opts[:temp_key]
    end
  end
end
