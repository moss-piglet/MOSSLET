defmodule Mosslet.Nudges do
  @moduledoc """
  The content-free "thinking of you" nudge system (EPIC #377, task #399).

  A nudge is a one-tap, wordless hello sent to a confirmed connection. It is
  **pure metadata** — `from_user_id`, `to_user_id`, and timestamps — so there is
  nothing for the server to read. This mirrors the rituals/presence
  plaintext-metadata model, NOT the `UserConnection` encrypted-fields model.

  ## Zero-knowledge boundary

  The nudge ROW never stores the sender's name. On the recipient's dashboard,
  the sender is identified client-side by reusing the recipient's already-sealed
  connection data via the `DecryptNudge` JS hook (the same ZK path as every
  connection card). The server only ever sees opaque UUIDs and blobs.

  ## Calm by design

  * Rate-limited: at most one nudge per connection per few hours.
  * Realtime in-app when the recipient is present; otherwise a single calm,
    generic, metadata-only email (max 1/day), collapsed across senders.
  * Recipient opt-out (`users.nudges_enabled`, default on) suppresses delivery.
  * No counts, no streaks, no comparative metrics.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Nudges.Nudge
  alias Mosslet.Repo

  # A connection may only be nudged once within this window — keeps the gesture
  # calm and prevents buzzer-spamming.
  @rate_limit_hours 3

  # How many recent unseen nudges to surface on the dashboard.
  @unseen_limit 12

  @doc """
  Subscribe the current process to a user's realtime nudge stream.

  Reuses the per-user `accounts:` topic that the dashboard and connections
  LiveViews already subscribe to (`Accounts.private_subscribe/1`).
  """
  def subscribe(%User{id: user_id}), do: subscribe(user_id)

  def subscribe(user_id) when is_binary(user_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, topic(user_id))
  end

  @doc """
  Send a content-free nudge from `from_user` to the confirmed connection whose
  peer user id is `to_user_id`.

  Guardrails, enforced server-side:

    * the two users must share a **confirmed** connection,
    * the recipient must not have opted out (`nudges_enabled`),
    * the sender may not nudge the same recipient more than once per
      `#{@rate_limit_hours}h` (rate limit / dedupe).

  On success the nudge is persisted (metadata only) and broadcast to the
  recipient's per-user topic. If the recipient is offline, a calm, generic
  email is enqueued (never the sender's name — keeps the email ZK-safe).

  Returns `{:ok, nudge}` or `{:error, reason}` where reason is one of
  `:not_connected`, `:opted_out`, `:rate_limited`, `:self`, or a changeset.
  """
  def send_nudge(%User{} = from_user, to_user_id) when is_binary(to_user_id) do
    cond do
      from_user.id == to_user_id ->
        {:error, :self}

      not connected?(from_user.id, to_user_id) ->
        {:error, :not_connected}

      not recipient_accepts_nudges?(to_user_id) ->
        {:error, :opted_out}

      recently_nudged?(from_user.id, to_user_id) ->
        {:error, :rate_limited}

      true ->
        do_send_nudge(from_user.id, to_user_id)
    end
  end

  defp do_send_nudge(from_user_id, to_user_id) do
    attrs = %{from_user_id: from_user_id, to_user_id: to_user_id}

    {:ok, result} =
      Repo.transaction_on_primary(fn ->
        %Nudge{}
        |> Nudge.changeset(attrs)
        |> Repo.insert()
      end)

    case result do
      {:ok, nudge} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          topic(to_user_id),
          {:nudge_received, nudge}
        )

        maybe_enqueue_email(to_user_id)
        {:ok, nudge}

      {:error, _changeset} = error ->
        error
    end
  end

  # Offline fallback: if the recipient isn't currently present in-app, enqueue a
  # single, calm, generic email (rate-limited to 1/day, collapsed across
  # senders). The GenServer re-checks presence + daily cap at send time, so this
  # stays quiet even under a burst. Never carries the sender's name.
  defp maybe_enqueue_email(to_user_id) do
    unless MossletWeb.Presence.user_active_in_app?(to_user_id) do
      Mosslet.Notifications.NudgeEmailNotificationsGenServer.queue_nudge_notification(to_user_id)
    end

    :ok
  end

  @doc """
  The recipient's recent **unseen** nudges (most recent first).

  Metadata-only rows — the caller resolves each sender's name client-side via
  the recipient's sealed connection data.
  """
  def list_unseen_nudges(user_id, limit \\ @unseen_limit) when is_binary(user_id) do
    Nudge
    |> where([n], n.to_user_id == ^user_id and is_nil(n.seen_at))
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Fetch a single nudge by id (nil if not found / malformed)."
  def get_nudge(nil), do: nil

  def get_nudge(id) when is_binary(id) do
    Repo.get(Nudge, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  @doc """
  Mark a single nudge as seen (idempotent, scoped to the recipient so a user can
  only ack their own nudges). Returns `{:ok, nudge}` or `{:error, :not_found}`.
  """
  def mark_seen(nudge_id, %User{id: user_id}) when is_binary(nudge_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, result} =
      Repo.transaction_on_primary(fn ->
        Nudge
        |> where([n], n.id == ^nudge_id and n.to_user_id == ^user_id)
        |> Repo.update_all(set: [seen_at: now, updated_at: now])
      end)

    case result do
      {1, _} -> {:ok, get_nudge(nudge_id)}
      _ -> {:error, :not_found}
    end
  end

  @doc "Mark ALL of a recipient's unseen nudges as seen. Returns the count."
  def mark_all_seen(%User{id: user_id}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, {count, _}} =
      Repo.transaction_on_primary(fn ->
        Nudge
        |> where([n], n.to_user_id == ^user_id and is_nil(n.seen_at))
        |> Repo.update_all(set: [seen_at: now, updated_at: now])
      end)

    count
  end

  @doc """
  Has `from_user_id` nudged `to_user_id` within the rate-limit window? Used both
  as a send guard and to disable/relabel the send button in the UI.
  """
  def recently_nudged?(from_user_id, to_user_id)
      when is_binary(from_user_id) and is_binary(to_user_id) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@rate_limit_hours, :hour)
      |> DateTime.truncate(:second)

    Nudge
    |> where([n], n.from_user_id == ^from_user_id and n.to_user_id == ^to_user_id)
    |> where([n], n.inserted_at > ^cutoff)
    |> Repo.exists?()
  end

  def recently_nudged?(_from_user_id, _to_user_id), do: false

  @doc "The rate-limit window, in hours (for UI copy / tests)."
  def rate_limit_hours, do: @rate_limit_hours

  # ── Guards ───────────────────────────────────────────────────────────────

  defp connected?(user_id, peer_id) do
    user_id
    |> Accounts.get_all_confirmed_user_connections()
    |> Enum.any?(fn uconn ->
      peer_id == if(uconn.user_id == user_id, do: uconn.reverse_user_id, else: uconn.user_id)
    end)
  end

  defp recipient_accepts_nudges?(to_user_id) do
    case Accounts.get_user(to_user_id) do
      %User{nudges_enabled: enabled} -> enabled
      _ -> false
    end
  end

  defp topic(user_id), do: "accounts:#{user_id}"
end
