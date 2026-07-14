defmodule Mosslet.Capsules.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific time-capsule
  data access.

  Mirrors `Mosslet.Journal.Adapter`: business logic stays in the
  `Mosslet.Capsules` context, adapters only handle data access. The web
  adapter (`Mosslet.Capsules.Adapters.Web`) uses direct Postgres access via
  `Mosslet.Repo` and `Repo.transaction_on_primary/1` for writes.

  Capsule content (title/body) is browser-encrypted with the user_key — the
  server only ever touches opaque ciphertext plus the plaintext `deliver_on`
  metadata.
  """

  alias Mosslet.Capsules.Capsule

  @callback list_sealed(user :: any(), today :: Date.t()) :: [Capsule.t()]
  @callback list_delivered(user :: any(), today :: Date.t()) :: [Capsule.t()]
  @callback list_opening_today(user :: any(), today :: Date.t()) :: [Capsule.t()]
  @callback count_sealed(user :: any(), today :: Date.t()) :: non_neg_integer()
  @callback count_opening_today(user :: any(), today :: Date.t()) :: non_neg_integer()
  @callback get_capsule!(id :: binary(), user :: any()) :: Capsule.t()
  @callback get_capsule(id :: binary(), user :: any()) :: Capsule.t() | nil

  @callback create_capsule(changeset :: Ecto.Changeset.t()) ::
              {:ok, Capsule.t()} | {:error, Ecto.Changeset.t()}

  @callback update_capsule(changeset :: Ecto.Changeset.t()) ::
              {:ok, Capsule.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_capsule(capsule :: Capsule.t()) ::
              {:ok, Capsule.t()} | {:error, Ecto.Changeset.t()}

  # Delivery worker: capsules due for delivery (deliver_on <= today) that have
  # not yet fired their "opening today" notification.
  @callback list_due_for_delivery(today :: Date.t()) :: [Capsule.t()]
end
