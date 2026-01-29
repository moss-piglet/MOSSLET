defmodule Mosslet.Groups.Group do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.PasswordStrength

  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Utils
  alias Mosslet.Groups.{GroupMessage, UserGroup}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "groups" do
    field :name, Encrypted.Binary, redact: true
    field :name_hash, Encrypted.HMAC, redact: true
    field :description, Encrypted.Binary, redact: true
    field :user_group_map, :map, virtual: true
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :require_password?, :boolean, default: false
    field :public?, :boolean, default: false

    belongs_to :user, Mosslet.Accounts.User

    has_many :memories, Mosslet.Memories.Memory
    has_many :messages, GroupMessage
    has_many :posts, Mosslet.Timeline.Post
    has_many :user_groups, UserGroup
    timestamps()
  end

  @doc false
  def changeset(group, attrs, opts \\ []) do
    group
    |> cast(attrs, [:name, :description, :password, :public?, :require_password?, :user_id])
    |> cast_assoc(:user)
    |> validate_required([:name, :description])
    |> validate_length(:name, min: 2, max: 160)
    |> validate_format(
      :name,
      ~r/\A(?!.*[\x00-\x1F])/,
      message: "contains invalid characters"
    )
    |> validate_allowed_name()
    |> validate_length(:description, max: 250)
    |> add_name_hash()
    |> encrypt_attrs(opts)
    |> validate_password(opts)
  end

  @doc false
  def join_changeset(group, attrs \\ %{}, _opts \\ []) do
    if group.require_password? do
      if valid_password?(group, attrs.password) do
        group
        |> cast(attrs, [])
      else
        group
        |> cast(attrs, [:password])
        |> add_error(:password, "is not valid")
      end
    else
      group
      |> cast(attrs, [])
    end
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Argon2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Mosslet.Groups.Group{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end

  defp add_name_hash(changeset) do
    if Map.has_key?(changeset.changes, :name) do
      changeset
      |> put_change(:name_hash, String.downcase(get_field(changeset, :name)))
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    require_password? = Keyword.get(opts, :require_password?, false)

    if require_password? == "true" do
      changeset
      |> validate_required([:password])
      |> validate_length(:password, min: 6, max: 72)
      |> check_zxcvbn_strength()
      |> maybe_hash_password(opts)
    else
      changeset
    end
  end

  defp check_zxcvbn_strength(changeset) do
    password = get_change(changeset, :password)

    if password != nil do
      password_strength =
        PasswordStrength.check(password, [
          get_change(changeset, :name),
          get_change(changeset, :username),
          get_change(changeset, :email)
        ])

      offline_fast_hashing =
        Map.get(password_strength.crack_times_display, :offline_fast_hashing_1e10_per_second)

      offline_slow_hashing =
        Map.get(password_strength.crack_times_display, :offline_slow_hashing_1e4_per_second)

      cond do
        password_strength.score >= 2 || offline_fast_hashing === "centuries" ->
          changeset

        password_strength.score <= 2 ->
          add_error(
            changeset,
            :password,
            "may be cracked in #{offline_fast_hashing} to #{offline_slow_hashing}"
          )
      end
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password, salt_len: 128))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp encrypt_attrs(changeset, opts) do
    if changeset.valid? && opts[:user] && opts[:key] do
      changeset
      |> generate_key(opts)
      |> then(fn x ->
        put_change(
          x,
          :name,
          Utils.encrypt(%{
            key: get_field(x, :user_group_map).key,
            payload: get_field(x, :name)
          })
        )
      end)
      |> then(fn x ->
        put_change(
          x,
          :description,
          Utils.encrypt(%{
            key: get_field(x, :user_group_map).key,
            payload: get_field(x, :description)
          })
        )
      end)
    else
      changeset
    end
  end

  defp generate_key(changeset, opts) do
    if opts[:update] && opts[:group_key] do
      changeset
      |> put_change(:user_group_map, %{
        key: opts[:group_key]
      })
    else
      changeset
      |> put_change(:user_group_map, %{
        key: Encrypted.Utils.generate_key()
      })
    end
  end

  # we want to ensure people can't make a name
  # like "admin" or "mosslet" that may trick or
  # confuse other people (or be easily inappropriate)
  defp validate_allowed_name(changeset) do
    if name = get_field(changeset, :name) do
      english_config = Expletive.configure(blacklist: Expletive.Blacklist.english())
      international_config = Expletive.configure(blacklist: Expletive.Blacklist.international())

      cond do
        String.downcase(name) in [
          "admin",
          "admin-moss",
          "admin-mosslet",
          "admin-mossy",
          "admin moss",
          "admin mosslet",
          "admin mosspiglet",
          "moss",
          "moss_admin",
          "moss-admin",
          "moss_piglet",
          "moss-piglet",
          "mosslet",
          "mosslet-admin",
          "mosslet_admin",
          "mosslet admin",
          "mosspiglet admin",
          "mosspiglet",
          "mossy",
          "mossy-admin",
          "mossy_admin",
          "mossy admin"
        ] ->
          changeset
          |> add_error(:name, "name unavailable or not allowed")

        Expletive.profane?(String.downcase(name), english_config) ->
          changeset
          |> add_error(:name, "name unavailable or not allowed")

        Expletive.profane?(String.downcase(name), international_config) ->
          changeset
          |> add_error(:name, "name unavailable or not allowed")

        true ->
          changeset
      end
    else
      changeset
    end
  end
end
