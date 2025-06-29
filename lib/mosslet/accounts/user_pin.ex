defmodule Mosslet.Accounts.UserPin do
  @moduledoc false
  use Mosslet.Schema

  import Ecto.Query, warn: false

  alias Mosslet.Accounts.User
  alias Mosslet.Repo

  @pin_validity_in_minutes 10

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_pins" do
    field :hashed_pin, :binary
    field :attempts, :integer, default: 0
    belongs_to :user, Mosslet.Accounts.User

    timestamps()
  end

  def create_changeset(%User{id: user_id}, hashed_pin) do
    %__MODULE__{}
    |> change(%{user_id: user_id, hashed_pin: hashed_pin})
    |> validate_required([:user_id, :hashed_pin])
    |> foreign_key_constraint(:user_id, name: :users_pins_user_id_fkey)
  end

  def increment_changeset(user_pin) do
    change(
      user_pin,
      %{attempts: user_pin.attempts + 1}
    )
  end

  def create_pin(%User{} = user, length \\ 6) do
    pin = Util.random_numeric_string(length)
    hashed_pin = get_hashed_pin(pin)

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:delete_pins, from(l in __MODULE__, where: l.user_id == ^user.id))
    |> Ecto.Multi.insert(:create_pin, fn _ -> create_changeset(user, hashed_pin) end)
    |> Repo.transaction()

    pin
  end

  def purge_pins(user) do
    Mosslet.Repo.delete_all(
      from l in __MODULE__,
        where: l.user_id == ^user.id,
        or_where: l.inserted_at < ago(@pin_validity_in_minutes, "minute")
    )
  end

  def failed_attempt(%User{id: user_id}) do
    user_pin =
      Repo.one(
        from l in __MODULE__,
          where: l.user_id == ^user_id
      )

    if user_pin do
      user_pin
      |> increment_changeset()
      |> Repo.update()
    end
  end

  def valid_pin_exists?(%User{id: user_id}) do
    valid_pins =
      Repo.one(
        from l in __MODULE__,
          where: l.user_id == ^user_id,
          where: l.inserted_at > ago(@pin_validity_in_minutes, "minute"),
          select: count()
      )

    valid_pins && valid_pins > 0
  end

  def validate_pin(%User{id: user_id}, pin, allowed_attempts) do
    from(l in __MODULE__,
      where: l.user_id == ^user_id
    )
    |> Repo.one()
    |> validation_status(pin, allowed_attempts)
  end

  defp validation_status(nil, _pin, _allowed_attempts), do: {:error, :not_found}

  defp validation_status(%__MODULE__{} = user_pin, pin, allowed_attempts) do
    expired? =
      Timex.diff(DateTime.utc_now(), user_pin.inserted_at, :minutes) >= @pin_validity_in_minutes

    hashed_pin = get_hashed_pin(pin)

    cond do
      expired? ->
        {:error, :expired}

      user_pin.attempts >= allowed_attempts ->
        {:error, :too_many_incorrect_attempts}

      user_pin.hashed_pin != hashed_pin ->
        {:error, :incorrect_pin}

      user_pin.hashed_pin == hashed_pin ->
        {:ok, user_pin}
    end
  end

  defp get_hashed_pin(pin),
    do:
      :crypto.mac(
        :hmac,
        :sha256,
        Application.get_env(:mosslet, MossletWeb.Endpoint)[:secret_key_base],
        pin
      )

  def pin_validity_in_minutes, do: @pin_validity_in_minutes
end
