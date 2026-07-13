defmodule Mosslet.Rituals.Jobs.PromptBroadcastWorker do
  @moduledoc """
  Selects and broadcasts the next shared ritual prompt (EPIC #377, task #378).

  Scheduled on a calm 3x/week cron (Tue/Thu/Sat) — see `config/config.exs`.
  This is intentionally NOT a daily/compulsive trigger. Because Oban uses a
  global peer, the job runs exactly once cluster-wide per tick, so the whole
  network sees the SAME prompt go live at the same time — which is the entire
  point (shared coordination signal).

  The work itself is metadata-only: the server picks a non-secret prompt string
  and PubSub-notifies subscribers. Answers remain zero-knowledge.
  """
  use Oban.Worker, queue: :timeline, max_attempts: 3

  alias Mosslet.Rituals

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "broadcast"}}) do
    case Rituals.broadcast_next_prompt() do
      {:ok, _broadcast} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  def perform(%Oban.Job{}), do: :ok
end
