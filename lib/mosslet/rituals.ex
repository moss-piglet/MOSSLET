defmodule Mosslet.Rituals do
  @moduledoc """
  The shared connection **ritual prompt** system (EPIC #377, task #378).

  This is the "quiet Tuesday" retention trigger: a gentle prompt broadcast on a
  calm 2-3x/week cadence to every connected network, IDENTICALLY. Because
  everyone in a network gets the same prompt, answering it by POSTING becomes a
  coordination signal — "my people got this too, so there's probably something
  new to come back and see."

  ## Zero-knowledge boundary

  A ritual prompt is **non-secret metadata**: the server freely selects the
  active prompt (from `Mosslet.Rituals.Prompts`) and broadcasts *which* prompt
  is live and *when*. The server NEVER reads the ANSWER — the posted answer
  flows through the existing zero-knowledge timeline path (browser-encrypted
  with a `post_key`, sealed per-recipient via `user_post`). Posts may optionally
  be stamped with the broadcast id (pure metadata) so a network can see
  "responses to this prompt".

  ## Calm by design

  * Cadence is 2-3x/week, never daily/compulsive.
  * Delivery is a batched PubSub signal (no real-time dopamine pings).
  * Opt-in per user (`users.ritual_prompts_enabled`).
  * No streaks, counts, or comparative metrics.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Rituals.{Prompts, PromptBroadcast}

  @topic "ritual_prompt"

  # How long a broadcast prompt stays "active" before it goes quiet (until the
  # next scheduled broadcast replaces it). Kept a little longer than the max gap
  # between broadcasts so there's always a gentle prompt available, never a
  # sense of "you missed it".
  @active_for_days 4

  # How many recent prompts to avoid repeating when selecting the next one.
  @recent_window 12

  @doc """
  Subscribe to ritual prompt broadcasts.

  The prompt is identical for everyone, so this is a single global topic rather
  than per-user — there is nothing user-specific (or secret) about a prompt.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, @topic)
  end

  @doc """
  The currently active prompt broadcast, or `nil` if none is live.

  "Active" = the most recent broadcast whose window hasn't closed yet.
  """
  def active_prompt(now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    PromptBroadcast
    |> where([b], b.broadcast_at <= ^now)
    |> where([b], is_nil(b.expires_at) or b.expires_at > ^now)
    |> order_by([b], desc: b.broadcast_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc "Fetch a specific broadcast by id (nil if not found)."
  def get_prompt_broadcast(nil), do: nil

  def get_prompt_broadcast(id) do
    Repo.get(PromptBroadcast, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  @doc """
  Resolve the non-secret prompt TEXT for a broadcast id, memoized per-process.

  Used when rendering timeline/profile/post cards stamped with a
  `ritual_prompt_id` so a network can see "this is a response to the shared
  prompt". The broadcast pool is tiny and the prompt text is non-secret
  metadata, so we cache resolved values in the process dictionary for the life
  of the (LiveView) process. This keeps the timeline render free of N+1 queries
  even when many posts answer the same prompt.

  Returns the prompt string, or `nil` when the id is nil/unknown.
  """
  def cached_prompt_text(nil), do: nil

  def cached_prompt_text(id) when is_binary(id) do
    cache = Process.get(:ritual_prompt_text_cache, %{})

    case Map.fetch(cache, id) do
      {:ok, text} ->
        text

      :error ->
        text =
          case get_prompt_broadcast(id) do
            %PromptBroadcast{prompt: prompt} -> prompt
            _ -> nil
          end

        Process.put(:ritual_prompt_text_cache, Map.put(cache, id, text))
        text
    end
  end

  def cached_prompt_text(_), do: nil

  @doc """
  Select and broadcast the next ritual prompt.

  Picks a fresh prompt from the curated pool (avoiding recent repeats), records
  it, and notifies subscribers via PubSub. Called by
  `Mosslet.Rituals.Jobs.PromptBroadcastWorker` on a calm cron cadence.

  Returns `{:ok, %PromptBroadcast{}}` or `{:error, changeset}`.
  """
  def broadcast_next_prompt(now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)
    prompt = Prompts.random(exclude: recent_prompt_texts())
    theme = theme_for_prompt(prompt)
    expires_at = DateTime.add(now, @active_for_days, :day)

    attrs = %{
      prompt: prompt,
      theme: theme,
      broadcast_at: now,
      expires_at: expires_at
    }

    {:ok, result} =
      Repo.transaction_on_primary(fn ->
        %PromptBroadcast{}
        |> PromptBroadcast.changeset(attrs)
        |> Repo.insert()
      end)

    case result do
      {:ok, broadcast} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          @topic,
          {:ritual_prompt, broadcast}
        )

        {:ok, broadcast}

      {:error, _changeset} = error ->
        error
    end
  end

  @doc "The most recent broadcast prompt strings, for repeat-avoidance."
  def recent_prompt_texts(limit \\ @recent_window) do
    PromptBroadcast
    |> order_by([b], desc: b.broadcast_at)
    |> limit(^limit)
    |> select([b], b.prompt)
    |> Repo.all()
  end

  @doc """
  Has this user already answered the given prompt broadcast (i.e. created a
  post stamped with its id)? Metadata-only check — we never read the post body.
  Used to swap the prompt card for a warm "you shared yours" state instead of
  re-asking on every visit.
  """
  def answered?(user_id, broadcast_id) when is_binary(user_id) and is_binary(broadcast_id) do
    Mosslet.Timeline.Post
    |> where([p], p.user_id == ^user_id and p.ritual_prompt_id == ^broadcast_id)
    |> Repo.exists?()
  end

  def answered?(_user_id, _broadcast_id), do: false

  defp theme_for_prompt(prompt) do
    Enum.find_value(Prompts.prompts_by_theme(), fn {theme, prompts} ->
      if prompt in prompts, do: theme
    end)
  end
end
