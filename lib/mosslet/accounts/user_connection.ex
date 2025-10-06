defmodule Mosslet.Accounts.UserConnection do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{Connection, User}

  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_connections" do
    field :key, Encrypted.Binary
    field :photos?, :boolean
    field :zen?, :boolean
    field :label, Encrypted.Binary
    field :label_hash, Encrypted.HMAC
    field :confirmed_at, :naive_datetime
    field :username, :string, virtual: true
    field :email, :string, virtual: true
    field :temp_label, :string, virtual: true
    field :request_username, Encrypted.Binary
    field :request_email, Encrypted.Binary
    field :request_username_hash, Encrypted.HMAC
    field :request_email_hash, Encrypted.HMAC

    field :color, Ecto.Enum,
      values: [:emerald, :teal, :orange, :purple, :rose, :amber, :cyan, :indigo, :pink]

    belongs_to :connection, Connection
    belongs_to :user, User
    belongs_to :reverse_user, User

    timestamps()
  end

  def changeset(uconn, attrs \\ %{}, opts \\ []) do
    uconn
    |> cast(attrs, [
      :key,
      :photos?,
      :zen?,
      :label,
      :temp_label,
      :email,
      :username,
      :request_email,
      :request_username,
      :user_id,
      :reverse_user_id,
      :connection_id,
      :color,
      :confirmed_at
    ])
    |> cast_assoc(:user)
    |> cast_assoc(:reverse_user)
    |> cast_assoc(:connection)
    |> validate_required([:temp_label])
    |> validate_length(:temp_label, min: 2, max: 160)
    |> add_label_hash()
    |> validate_request_email_and_username(opts)
    |> validate_email_or_username(opts)
    |> unsafe_validate_unique([:connection_id, :user_id], Mosslet.Repo.Local)
    |> unique_constraint([:connection_id, :user_id])
    |> unsafe_validate_unique([:user_id, :reverse_user_id], Mosslet.Repo.Local)
    |> unique_constraint([:user_id, :reverse_user_id])
    |> unsafe_validate_unique([:reverse_user_id, :user_id], Mosslet.Repo.Local)
    |> unique_constraint([:reverse_user_id, :user_id])
  end

  @doc """
  Confirms the user_connection by setting `confirmed_at`.
  """
  def confirm_changeset(user_connection) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user_connection, confirmed_at: now)
  end

  defp validate_email_or_username(changeset, opts) do
    case opts[:selector] do
      "" ->
        changeset
        |> add_error(:email, "can't both be blank")
        |> add_error(:username, "can't both be blank")

      "email" ->
        changeset
        |> validate_email(opts)

      "username" ->
        changeset
        |> validate_username(opts)

      _rest ->
        if opts[:confirm] do
          changeset
          |> validate_email(opts)
          |> validate_username(opts)
        else
          changeset
        end
    end
  end

  defp validate_request_email_and_username(changeset, opts) do
    changeset
    |> add_request_email_hash(opts)
    |> add_request_username_hash(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_add_recipient_id_by_email(opts)
  end

  defp validate_username(changeset, opts) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 160)
    |> maybe_add_recipient_id_by_username(opts)
  end

  # We don't need to add the user_id by the recipient when
  # confirming/accepting because we already know the user_id
  # from the requesting user.
  defp maybe_add_recipient_id_by_email(changeset, opts) do
    if opts[:confirm] do
      recipient = Accounts.get_user!(get_field(changeset, :user_id))

      changeset
      |> encrypt_connection_key_and_data(recipient, opts)
    else
      email = get_change(changeset, :email, "")

      if recipient = Accounts.get_user_by_email(opts[:user], email) do
        changeset
        |> put_change(:user_id, recipient.id)
        |> encrypt_connection_key_and_data(recipient, opts)
      else
        changeset
        |> add_error(:email, "invalid or does not exist")
      end
    end
  end

  # We don't need to add the user_id by the recipient when
  # confirming/accepting because we already know the user_id
  # from the requesting user.
  #
  # The recipient is always the other side of the connection
  # from the current user.
  defp maybe_add_recipient_id_by_username(changeset, opts) do
    if opts[:confirm] do
      recipient = Accounts.get_user!(get_field(changeset, :user_id))

      changeset
      |> encrypt_connection_key_and_data(recipient, opts)
    else
      username = get_change(changeset, :username, "")

      if recipient = Accounts.get_user_by_username(opts[:user], username) do
        changeset
        |> put_change(:user_id, recipient.id)
        |> encrypt_connection_key_and_data(recipient, opts)
      else
        changeset
        |> add_error(:username, "invalid or does not exist")
      end
    end
  end

  defp add_label_hash(changeset) do
    if Map.get(changeset.changes, :temp_label) do
      changeset
      |> put_change(:label_hash, String.downcase(get_field(changeset, :temp_label)))
    else
      changeset
    end
  end

  defp add_request_email_hash(changeset, opts) do
    if opts[:user] && opts[:key] do
      d_email =
        cond do
          opts[:confirm] ->
            get_field(changeset, :request_email)

          true ->
            Encrypted.Users.Utils.decrypt_user_data(
              opts[:user].email,
              opts[:user],
              opts[:key]
            )
        end

      changeset
      |> put_change(:request_email_hash, String.downcase(d_email))
    else
      changeset
    end
  end

  defp add_request_username_hash(changeset, opts) do
    if opts[:user] && opts[:key] do
      d_username =
        cond do
          opts[:confirm] ->
            get_field(changeset, :request_username)

          true ->
            Encrypted.Users.Utils.decrypt_user_data(
              opts[:user].username,
              opts[:user],
              opts[:key]
            )
        end

      changeset
      |> put_change(:request_username_hash, String.downcase(d_username))
    else
      changeset
    end
  end

  defp encrypt_connection_key_and_data(changeset, recipient, opts) do
    cond do
      opts[:confirm] ->
        changeset =
          encrypt_changes_on_changeset(
            changeset,
            recipient,
            decrypt_requesting_data(changeset, opts)
          )

        changeset

      opts[:user] && opts[:key] ->
        changeset =
          encrypt_changes_on_changeset(
            changeset,
            recipient,
            decrypt_requesting_data(changeset, opts)
          )

        changeset

      true ->
        changeset
    end
  end

  defp decrypt_requesting_data(changeset, opts) do
    # We first decrypt the current_user's conn_key
    # and username and email.
    {:ok, d_conn_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(
        opts[:user].conn_key,
        opts[:user],
        opts[:key]
      )

    {d_req_username, d_req_email, temp_label} =
      if opts[:confirm] do
        {get_field(changeset, :request_username), get_field(changeset, :request_email),
         get_field(changeset, :temp_label)}
      else
        d_req_username =
          Encrypted.Users.Utils.decrypt_user_data(
            opts[:user].username,
            opts[:user],
            opts[:key]
          )

        d_req_email =
          Encrypted.Users.Utils.decrypt_user_data(
            opts[:user].email,
            opts[:user],
            opts[:key]
          )

        {d_req_username, d_req_email, get_field(changeset, :temp_label)}
      end

    %{
      key: d_conn_key,
      request_username: d_req_username,
      request_email: d_req_email,
      temp_label: temp_label
    }
  end

  defp encrypt_changes_on_changeset(changeset, recipient, %{
         key: d_conn_key,
         request_username: d_req_username,
         request_email: d_req_email,
         temp_label: temp_label
       }) do
    # We next encrypt the current_user's conn key
    # and post key and username and email.
    changeset
    |> put_change(
      :key,
      Encrypted.Utils.encrypt_message_for_user_with_pk(d_conn_key, %{
        public: recipient.key_pair["public"]
      })
    )
    |> put_change(
      :request_username,
      Encrypted.Utils.encrypt(%{key: d_conn_key, payload: d_req_username})
    )
    |> put_change(
      :request_email,
      Encrypted.Utils.encrypt(%{key: d_conn_key, payload: d_req_email})
    )
    |> maybe_encrypt_label(d_conn_key, temp_label)
  end

  defp maybe_encrypt_label(changeset, d_conn_key, temp_label) do
    if temp_label do
      changeset
      |> put_change(:label, Encrypted.Utils.encrypt(%{key: d_conn_key, payload: temp_label}))
    else
      changeset
    end
  end

  def visibility_group_changeset(visibility_group, attrs, opts \\ []) do
    changeset =
      visibility_group
      |> cast(attrs, [:temp_name, :temp_description, :color, :temp_member_ids])
      |> validate_required([:temp_name])
      |> validate_length(:temp_name, min: 2, max: 60)
      |> validate_length(:temp_description, max: 200)

    # Encrypt the fields if we have the necessary opts
    if opts[:user] && opts[:key] && changeset.valid? do
      changeset
      |> encrypt_visibility_group_fields(opts)
    else
      changeset
    end
  end

  defp encrypt_visibility_group_fields(changeset, opts) do
    # Get the user's connection key for encryption
    {:ok, d_conn_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(
        opts[:user].conn_key,
        opts[:user],
        opts[:key]
      )

    changeset =
      if get_change(changeset, :temp_name) do
        name = get_change(changeset, :temp_name)
        encrypted_name = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: name})

        changeset
        |> put_change(:name, encrypted_name)
      else
        changeset
      end

    changeset =
      if get_change(changeset, :temp_description) do
        description = get_change(changeset, :temp_description)
        encrypted_description = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: description})

        changeset
        |> put_change(:description, encrypted_description)
      else
        changeset
      end

    changeset =
      if get_change(changeset, :temp_member_ids) do
        member_ids = get_change(changeset, :temp_member_ids) || []

        # Encrypt each member ID with the connection key
        encrypted_member_ids =
          Enum.map(member_ids, fn member_id ->
            Encrypted.Utils.encrypt(%{key: d_conn_key, payload: member_id})
          end)

        changeset
        |> put_change(:member_ids, encrypted_member_ids)
        |> put_change(:member_ids_hash, create_member_ids_hash(member_ids))
      else
        changeset
      end

    changeset
  end

  defp create_member_ids_hash(member_ids) when is_list(member_ids) do
    member_ids
    |> Enum.sort()
    |> Enum.join(",")
    |> String.downcase()
  end
end
