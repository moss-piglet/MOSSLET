defmodule Mosslet.Repo.Migrations.CreateRitualPromptBroadcasts do
  use Ecto.Migration

  # Shared connection ritual prompt system (EPIC #377, task #378).
  #
  # A ritual prompt is NON-SECRET metadata: a plain string the server freely
  # selects (from the curated `Mosslet.Rituals.Prompts` pool) and broadcasts to
  # every connected network on a calm 2-3x/week cadence. The value is that the
  # prompt is IDENTICAL for everyone, so answering-by-posting becomes a shared
  # coordination signal ("my people got this too").
  #
  # The server NEVER reads the ANSWER: the posted answer flows through the
  # existing zero-knowledge timeline path (browser-encrypted with a post_key,
  # sealed per-recipient via user_post). We only optionally stamp the resulting
  # post with the broadcast id (`posts.ritual_prompt_id`) — pure metadata that
  # lets a network see "responses to this prompt".
  #
  # All operations are online-safe on Fly PostgreSQL (new table + nullable
  # column adds).
  def change do
    create table(:ritual_prompt_broadcasts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # The non-secret prompt string that was broadcast, plus its theme (for
      # rotation/variety). Stored in plaintext — the prompt is a QUESTION, not
      # an answer, and leaks nothing.
      add :prompt, :text, null: false
      add :theme, :string

      # When this prompt went live and when it stops being the "active" prompt
      # (roughly until the next scheduled broadcast). Both plaintext timestamps.
      add :broadcast_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime

      timestamps()
    end

    # "Which prompt is active now" = most recent broadcast_at that hasn't
    # expired. Index supports that ordered lookup cheaply.
    create index(:ritual_prompt_broadcasts, [:broadcast_at])

    # Opt-in preference (calm, non-compulsive). Default false: users choose to
    # receive ritual prompts in their notification settings.
    alter table(:users) do
      add :ritual_prompts_enabled, :boolean, null: false, default: false
    end

    # Non-secret stamp linking an answering POST back to the prompt it responds
    # to. Nullable; nilified if the broadcast row is ever removed.
    alter table(:posts) do
      add :ritual_prompt_id,
          references(:ritual_prompt_broadcasts, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:posts, [:ritual_prompt_id])
  end
end
