defmodule Mosslet.Groups.UserGroup do
  @moduledoc false
  use Ecto.Schema
  use MossletWeb, :verified_routes
  import Ecto.Changeset

  alias Mosslet.Encrypted

  @roles [:admin, :member, :moderator, :owner]
  @avatar_img_list ~w(astronaut.png bear.png cat.png chicken.png dinosaur.png dog.png panda.png penguin.png rabbit.png sea-lion.png)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_groups" do
    field :key, Encrypted.Binary, redact: true
    field :role, Ecto.Enum, values: @roles
    field :name, Encrypted.Binary, redact: true
    field :name_hash, Encrypted.HMAC, redact: true
    field :moniker, Encrypted.Binary, redact: true
    field :avatar_img, Encrypted.Binary, redact: true
    field :confirmed_at, :naive_datetime

    belongs_to :group, Mosslet.Groups.Group
    belongs_to :user, Mosslet.Accounts.User

    has_many :memories, Mosslet.Memories.Memory
    has_many :posts, Mosslet.Timeline.Post

    timestamps()
  end

  @doc false
  def changeset(user_group, attrs, opts \\ []) do
    user_group
    |> cast(attrs, [
      :key,
      :role,
      :name,
      :confirmed_at,
      :user_id,
      :group_id,
      :moniker,
      :avatar_img
    ])
    |> cast_assoc(:group)
    |> cast_assoc(:user)
    |> validate_required([:key, :role])
    |> validate_name(opts)
    |> encrypt_attrs(opts)
  end

  @doc """
  Changeset for updating the user_group role.
  """
  def role_changeset(user_group, attrs) do
    user_group
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end

  @doc """
  Confirms the user_group by setting `confirmed_at`.
  """
  def confirm_changeset(user_group) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user_group, confirmed_at: now)
  end

  defp validate_name(changeset, _opts) do
    changeset
    |> validate_required([:name])
    |> validate_format(
      :name,
      ~r/^[\p{L}\p{M}' -]+$/u
    )
    |> validate_length(:name, max: 160)
    |> validate_allowed_name()
    |> add_name_hash()
  end

  defp add_name_hash(changeset) do
    if Map.has_key?(changeset.changes, :name) do
      changeset
      |> put_change(:name_hash, String.downcase(get_field(changeset, :name)))
    else
      changeset
    end
  end

  defp encrypt_attrs(changeset, opts) do
    name = get_field(changeset, :name)

    if changeset.valid? && opts[:user] && opts[:key] do
      public_key =
        if opts[:public?] do
          Encrypted.Session.server_public_key()
        else
          opts[:user].key_pair["public"]
        end

      changeset
      |> put_change(
        :name,
        Encrypted.Utils.encrypt(%{key: get_field(changeset, :key), payload: name})
      )
      |> put_change(:name_hash, name)
      |> generate_moniker()
      |> generate_avatar_img()
      |> put_change(
        :key,
        Encrypted.Utils.encrypt_message_for_user_with_pk(get_field(changeset, :key), %{
          public: public_key
        })
      )
    else
      changeset
    end
  end

  defp generate_moniker(changeset) do
    changeset
    |> put_change(
      :moniker,
      Encrypted.Utils.encrypt(%{key: get_field(changeset, :key), payload: FriendlyID.generate(3)})
    )
  end

  defp generate_avatar_img(changeset) do
    changeset
    |> put_change(
      :avatar_img,
      Encrypted.Utils.encrypt(%{key: get_field(changeset, :key), payload: random_avatar_img()})
    )
  end

  defp random_avatar_img() do
    Enum.random(@avatar_img_list)
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
