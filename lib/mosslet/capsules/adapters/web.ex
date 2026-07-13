defmodule Mosslet.Capsules.Adapters.Web do
  @moduledoc """
  Web adapter for time-capsule operations.

  Uses direct Postgres access via `Mosslet.Repo`. This is the default adapter
  for web deployments on Fly.io. Writes go through
  `Repo.transaction_on_primary/1`.

  All visibility gating is done on the plaintext `deliver_on` metadata column
  only — capsule content (title/body) is opaque ciphertext.
  """

  @behaviour Mosslet.Capsules.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Capsules.Capsule
  alias Mosslet.Repo

  @impl true
  def list_sealed(user) do
    today = Date.utc_today()

    from(c in Capsule,
      where: c.user_id == ^user.id and c.deliver_on > ^today,
      order_by: [asc: c.deliver_on, desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @impl true
  def list_delivered(user) do
    today = Date.utc_today()

    from(c in Capsule,
      where: c.user_id == ^user.id and c.deliver_on <= ^today,
      order_by: [desc: c.deliver_on, desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @impl true
  def list_opening_today(user) do
    today = Date.utc_today()

    from(c in Capsule,
      where: c.user_id == ^user.id and c.deliver_on == ^today,
      order_by: [desc: c.inserted_at]
    )
    |> Repo.all()
  end

  @impl true
  def count_sealed(user) do
    today = Date.utc_today()

    from(c in Capsule,
      where: c.user_id == ^user.id and c.deliver_on > ^today,
      select: count(c.id)
    )
    |> Repo.one()
  end

  @impl true
  def count_opening_today(user) do
    today = Date.utc_today()

    from(c in Capsule,
      where: c.user_id == ^user.id and c.deliver_on == ^today and is_nil(c.opened_at),
      select: count(c.id)
    )
    |> Repo.one()
  end

  @impl true
  def get_capsule!(id, user) do
    from(c in Capsule, where: c.id == ^id and c.user_id == ^user.id)
    |> Repo.one!()
  end

  @impl true
  def get_capsule(id, user) do
    from(c in Capsule, where: c.id == ^id and c.user_id == ^user.id)
    |> Repo.one()
  end

  @impl true
  def create_capsule(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.insert(changeset)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def update_capsule(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.update(changeset)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def delete_capsule(capsule) do
    Repo.transaction_on_primary(fn ->
      Repo.delete(capsule)
    end)
    |> handle_transaction_result()
  end

  @impl true
  def list_due_for_delivery(today) do
    from(c in Capsule,
      where: c.deliver_on <= ^today and is_nil(c.notified_at),
      order_by: [asc: c.deliver_on]
    )
    |> Repo.all()
  end

  # =====================
  # Private Helpers
  # =====================

  defp handle_transaction_result({:ok, {:ok, result}}), do: {:ok, result}
  defp handle_transaction_result({:ok, {:error, changeset}}), do: {:error, changeset}
  defp handle_transaction_result({:error, _} = error), do: error
end
