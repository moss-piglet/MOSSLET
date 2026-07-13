defmodule Mosslet.Rituals.Prompts do
  @moduledoc """
  Curated pool of SHARED ritual prompts — the connection-facing prompts for
  the "quiet Tuesday" trigger (see EPIC #377, task #378).

  These are fundamentally different from `Mosslet.Journal.AI` prompts:

    * Journal prompts are SELF-directed. The answer is a private, encrypted
      journal entry seen by no one. The voice is inward and reflective.

    * Ritual prompts (this module) are SOCIAL. The answer is a POST shared with
      your connections on the timeline. The voice is lighter, warmer, and
      shareable — an easy, low-pressure invitation to show your people a small
      slice of your day. Everyone in a network receives the SAME prompt, so
      answering-by-posting is a coordination signal ("my people got this too →
      there's probably something new to come back and see").

  ## Zero-knowledge

  A ritual prompt is **non-secret metadata** — a plain string the server may
  freely select and broadcast. The server never reads the *answer*; the posted
  answer flows through the existing ZK timeline path (browser-encrypted with a
  `post_key`, sealed per recipient via `user_post`). Nothing here touches
  plaintext content.

  ## Design intent

  Prompts must be:

    * **Easy** — answerable in one photo or one sentence, from anywhere.
    * **Warm, never clinical** — an invitation, not an assignment.
    * **Non-comparative** — never invite performance, ranking, or "how am I
      doing?" framing. We want "I want to check in on my people", not
      "I wonder how I measure up".
    * **Calm** — no guilt, no streak pressure, no FOMO.

  The pool is intentionally large (rotated 2–3×/week) so freshness holds for
  years without any per-user generation.
  """

  @themes [
    "everyday moments",
    "gratitude",
    "where you are",
    "small joys",
    "people you love",
    "looking forward",
    "playful",
    "comfort"
  ]

  def themes, do: @themes

  # Grouped so cadence/rotation can vary voice across a week and so review is
  # easy. Keep additions in the same warm, shareable, non-comparative voice.
  @prompts_by_theme %{
    "everyday moments" => [
      "What's one small good thing that happened today?",
      "Show us a tiny detail from your day.",
      "What did today smell or sound like?",
      "What's the last thing that made you pause?",
      "Share a snapshot of something in front of you right now.",
      "What's been the quiet soundtrack to your day?",
      "What did your hands do today?",
      "One photo of your day, no caption needed."
    ],
    "gratitude" => [
      "Who did something kind for you lately?",
      "What are you quietly thankful for today?",
      "Name a small comfort you're grateful for right now.",
      "What's a little thing someone did that you noticed?",
      "What made today a bit easier?",
      "Who are you glad to have in your corner?"
    ],
    "where you are" => [
      "A photo of where you are right now.",
      "What does your view look like today?",
      "Show us your favorite spot lately.",
      "Where did you spend most of your time today?",
      "What's the weather doing where you are?",
      "Share the coziest corner near you."
    ],
    "small joys" => [
      "What's the best thing you ate today?",
      "What song has been stuck in your head?",
      "Share something that made you laugh recently.",
      "What's a small treat you gave yourself?",
      "What's bringing you a little joy this week?",
      "Show us something that made you smile."
    ],
    "people you love" => [
      "Who are you thinking of today?",
      "Share a moment with someone you love.",
      "Who did you talk to that brightened your day?",
      "What's something a friend or family member did lately?",
      "Who do you wish you could see right now?",
      "Send a little hello to your people."
    ],
    "looking forward" => [
      "What are you looking forward to this week?",
      "What's a small plan that's got you a bit excited?",
      "What's something on the horizon you can't wait for?",
      "What would make tomorrow a good day?",
      "What's next on your 'someday soon' list?",
      "What are you slowly getting ready for?"
    ],
    "playful" => [
      "If today were a color, which one and why?",
      "Show us the most 'you' thing in the room.",
      "What's a tiny victory worth celebrating today?",
      "Describe your day in three words.",
      "What would the title of today's chapter be?",
      "Share the last photo in your camera roll (if you dare)."
    ],
    "comfort" => [
      "What's helping you feel grounded lately?",
      "What does 'cozy' look like for you today?",
      "What's your go-to comfort right now?",
      "How are you really doing today — in a word or a photo?",
      "What's something gentle you did for yourself?",
      "What's keeping you steady this week?"
    ]
  }

  def prompts_by_theme, do: @prompts_by_theme

  @doc "The full flat pool of shared ritual prompts."
  def all do
    @prompts_by_theme |> Map.values() |> List.flatten()
  end

  @doc "Prompts for a single theme (empty list if the theme is unknown)."
  def for_theme(theme), do: Map.get(@prompts_by_theme, theme, [])

  @doc """
  A random ritual prompt. Accepts an optional `:exclude` list (e.g. recently
  broadcast prompts) so the broadcaster in #378 can avoid immediate repeats.
  """
  def random(opts \\ []) do
    exclude = Keyword.get(opts, :exclude, [])

    case Enum.reject(all(), &(&1 in exclude)) do
      [] -> Enum.random(all())
      candidates -> Enum.random(candidates)
    end
  end
end
