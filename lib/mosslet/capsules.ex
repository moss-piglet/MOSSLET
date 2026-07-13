defmodule Mosslet.Capsules do
  @moduledoc """
  The Capsules context — encrypted "letters to your future self".

  A time capsule is a private letter you write now, seal with a future
  delivery date, and receive back on that date. Deeply personal, and only
  possible on a zero-knowledge network.

  ## Zero-knowledge boundary

  Capsule content (title/body) is encrypted in the BROWSER with the user's
  personal key (user_key) via WASM — identical to journal entries. The server
  stores opaque ciphertext and NEVER sees the plaintext.

  The ONLY server-visible/queryable field is `deliver_on` (a date) plus
  lifecycle metadata (`sealed_at`, `notified_at`, `opened_at`, `stationery`).
  Visibility (sealed vs delivered) and the calm "a capsule opens today"
  notification are gated on this metadata alone.

  Platform-aware adapters (mirrors `Mosslet.Journal`):
    * Web (Fly.io): `Mosslet.Capsules.Adapters.Web` (direct Postgres)
    * Native: `Mosslet.Capsules.Adapters.Native` (API + cache) — future
  """

  alias Mosslet.Capsules.Capsule
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils
  alias Mosslet.Platform

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Capsules.Adapters.Web
    end
  end

  # =====================
  # Queries
  # =====================

  @doc "Sealed capsules — not yet due (deliver_on in the future)."
  def list_sealed(user), do: adapter().list_sealed(user)

  @doc "Delivered capsules — due now or in the past (deliver_on <= today)."
  def list_delivered(user), do: adapter().list_delivered(user)

  @doc "Capsules whose delivery date is exactly today."
  def list_opening_today(user), do: adapter().list_opening_today(user)

  def count_sealed(user), do: adapter().count_sealed(user)

  @doc "Count of capsules opening today that the user has not yet opened."
  def count_opening_today(user), do: adapter().count_opening_today(user)

  def get_capsule!(id, user), do: adapter().get_capsule!(id, user)
  def get_capsule(id, user), do: adapter().get_capsule(id, user)

  # =====================
  # Writes
  # =====================

  @doc """
  Creates a capsule from browser-encrypted fields (ZK write path).

  The browser has already encrypted title/body with the user_key. `attrs`
  carries `encrypted_title`, `encrypted_body`, plus plaintext metadata
  (`deliver_on`, `stationery`, `word_count`).
  """
  def create_capsule_zk(user, attrs) do
    changeset = Capsule.changeset_zk(%Capsule{}, Map.put(attrs, "user_id", user.id))
    adapter().create_capsule(changeset)
  end

  @doc """
  Marks a capsule as opened (metadata-only). No-op if already opened.
  """
  def mark_opened(%Capsule{} = capsule, user) do
    cond do
      capsule.user_id != user.id ->
        {:error, :unauthorized}

      capsule.opened_at ->
        {:ok, capsule}

      true ->
        capsule
        |> Capsule.open_changeset()
        |> adapter().update_capsule()
    end
  end

  def delete_capsule(%Capsule{} = capsule, user) do
    if capsule.user_id == user.id do
      adapter().delete_capsule(capsule)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns whether a capsule is currently deliverable (readable) based purely
  on its `deliver_on` metadata.
  """
  def delivered?(%Capsule{deliver_on: nil}), do: false

  def delivered?(%Capsule{deliver_on: deliver_on}) do
    Date.compare(deliver_on, Date.utc_today()) != :gt
  end

  # =====================
  # Delivery worker support
  # =====================

  @doc "Capsules due for delivery that have not yet fired their notification."
  def list_due_for_delivery(today \\ Date.utc_today()) do
    adapter().list_due_for_delivery(today)
  end

  @doc """
  Marks a capsule as having fired its delivery notification (idempotency gate
  for the delivery worker). Metadata-only.
  """
  def mark_notified(%Capsule{} = capsule) do
    capsule
    |> Ecto.Changeset.change(notified_at: DateTime.truncate(DateTime.utc_now(), :second))
    |> adapter().update_capsule()
  end

  # =====================
  # Decryption (web fallback / non-ZK contexts)
  # =====================

  @doc """
  Server-side decrypt helper (used only where a non-ZK read is unavoidable,
  e.g. native/offline). The browser ZK read path is preferred on web.
  """
  def decrypt_capsule(%Capsule{} = capsule, user, key) do
    title =
      if capsule.title, do: EncryptedUtils.decrypt_user_data(capsule.title, user, key), else: nil

    body = EncryptedUtils.decrypt_user_data(capsule.body, user, key)

    %{capsule | title: title, body: body}
  end
end
