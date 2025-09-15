defmodule Mosslet.Invitations.Invite do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "invitations" do
    field :recipient_name, :string, virtual: true
    field :recipient_email, :string, virtual: true
    field :message, :string, virtual: true

    timestamps()
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:recipient_name, :recipient_email])
    |> validate_required([:recipient_name, :recipient_email])
    |> validate_name()
    |> validate_email()
  end

  defp validate_email(changeset) do
    if Map.has_key?(changeset.changes, :recipient_email) do
      changeset
      |> put_change(:recipient_email, String.downcase(get_field(changeset, :recipient_email)))
      |> validate_format(:recipient_email, ~r/^[^\s]+@[^\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:recipient_email, max: 160)
    else
      changeset
    end
  end

  defp validate_name(changeset) do
    changeset
    |> validate_required([:recipient_name])
    |> validate_format(
      :recipient_name,
      ~r/^[\p{L}\p{M}' -]+$/u
    )
    |> validate_allowed_name()
    |> validate_length(:recipient_name, max: 160)
  end

  # we want to ensure people can't make a name
  # like "admin" or "mosslet" that may trick or
  # confuse other people (or be easily inappropriate)
  defp validate_allowed_name(changeset) do
    if name = get_field(changeset, :recipient_name) do
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
          |> add_error(:recipient_name, "name unavailable or not allowed")

        Expletive.profane?(String.downcase(name), english_config) ->
          changeset
          |> add_error(:recipient_name, "name unavailable or not allowed")

        Expletive.profane?(String.downcase(name), international_config) ->
          changeset
          |> add_error(:recipient_name, "name unavailable or not allowed")

        true ->
          changeset
      end
    else
      changeset
    end
  end
end
