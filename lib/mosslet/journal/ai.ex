defmodule Mosslet.Journal.AI do
  @moduledoc """
  AI-powered features for journaling.

  Provides:
  - Journaling prompts - AI-generated reflection questions
  - Content moderation helper - Feedback on post appropriateness before sharing
  - Mood insights - Weekly AI-generated summaries of emotional patterns

  Uses privacy-first providers via OpenRouter (Together AI).
  """

  alias Mosslet.AI.Config

  @daily_prompt_limit 20
  @prompt_cooldown_seconds 10
  @ets_table :journal_ai_rate_limits

  def daily_prompt_limit, do: @daily_prompt_limit
  def prompt_cooldown_seconds, do: @prompt_cooldown_seconds

  def ensure_ets_table do
    case :ets.whereis(@ets_table) do
      :undefined -> :ets.new(@ets_table, [:set, :public, :named_table])
      _ -> @ets_table
    end
  end

  def can_generate_prompt?(user_id) do
    ensure_ets_table()
    today = Date.utc_today()
    cache_key = {user_id, today}

    case :ets.lookup(@ets_table, cache_key) do
      [] -> {:ok, @daily_prompt_limit}
      [{_, count}] when count < @daily_prompt_limit -> {:ok, @daily_prompt_limit - count}
      _ -> {:error, :limit_reached}
    end
  end

  def increment_prompt_count(user_id) do
    ensure_ets_table()
    today = Date.utc_today()
    cache_key = {user_id, today}

    case :ets.lookup(@ets_table, cache_key) do
      [] -> :ets.insert(@ets_table, {cache_key, 1})
      [{_, count}] -> :ets.insert(@ets_table, {cache_key, count + 1})
    end
  end

  def get_remaining_prompts(user_id) do
    case can_generate_prompt?(user_id) do
      {:ok, remaining} -> remaining
      {:error, :limit_reached} -> 0
    end
  end

  def generate_prompt(opts \\ []) do
    mood = Keyword.get(opts, :mood)
    theme = Keyword.get(opts, :theme)

    system_prompt = """
    You are a thoughtful journaling companion. Generate a single reflective journaling prompt.

    Guidelines:
    - Be warm and inviting, not clinical
    - Encourage self-reflection and introspection
    - Keep prompts open-ended to allow free expression
    - Vary between gratitude, growth, relationships, goals, and emotions
    - Keep the prompt to 1-2 sentences
    #{if mood, do: "- The user is currently feeling #{mood}, tailor the prompt accordingly", else: ""}
    #{if theme, do: "- Focus on the theme: #{theme}", else: ""}

    Respond with ONLY the journaling prompt, nothing else.
    """

    case ReqLLM.generate_text(
           Config.text_model(),
           "Generate a journaling prompt",
           Config.text_opts(system_prompt: system_prompt)
         ) do
      {:ok, response} ->
        {:ok, ReqLLM.Response.text(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Moderates content for public posts. Returns {:ok, :approved} if content is appropriate,
  or {:error, reason} if content violates community guidelines.

  This is specifically for public posts where we want to maintain civil discourse.
  Critical opinions, disagreements, and strong viewpoints are allowed - just like
  speaking in public in real life. Only genuinely harmful content is blocked.
  """
  def moderate_public_post(content) do
    system_prompt = """
    You are a content moderator for a social platform focused on healthy public discourse.

    ALLOW (respond with APPROVED):
    - Opinions, even strong or unpopular ones
    - Disagreements, debates, and criticism of ideas/organizations/public figures
    - Personal experiences, stories, and venting about situations
    - News discussion and political commentary
    - Frustration expressed constructively (e.g., "I'm so frustrated with this situation")
    - Satire, humor, and sarcasm
    - Mild profanity used expressively (e.g., "that was a damn good movie")

    BLOCK (respond with BLOCKED and a brief reason):
    - Abusive language directed at people (e.g., "fuck you", "you're an idiot", personal insults)
    - Harassment, threats, or intimidation toward any individual or group
    - Hate speech targeting protected characteristics (race, religion, gender, sexuality, disability, etc.)
    - Calls for violence or harm
    - Doxxing or sharing others' private information (addresses, phone numbers, etc.)
    - Spam, scams, or deceptive content
    - Content promoting illegal activity

    KEY DISTINCTION: Venting about situations is fine ("fuck this traffic!"), but directing hostility at people is not ("fuck you!").

    Respond with ONLY:
    APPROVED
    or
    BLOCKED: [reason in 10 words or less]
    """

    case ReqLLM.generate_text(
           Config.text_model(),
           content,
           Config.text_opts(system_prompt: system_prompt, max_tokens: 1000)
         ) do
      {:ok, response} ->
        result = ReqLLM.Response.text(response) |> String.trim()

        cond do
          String.starts_with?(result, "APPROVED") ->
            {:ok, :approved}

          String.starts_with?(result, "BLOCKED:") ->
            reason = String.replace_prefix(result, "BLOCKED:", "") |> String.trim()
            {:error, reason}

          true ->
            {:ok, :approved}
        end

      {:error, _reason} ->
        {:ok, :approved}
    end
  end

  def generate_mood_insights(entries) when is_list(entries) do
    if Enum.empty?(entries) do
      {:ok,
       "Start journaling to see mood insights! Write a few entries and I'll help identify patterns."}
    else
      mood_data =
        entries
        |> Enum.map(fn entry ->
          date = Calendar.strftime(entry.entry_date, "%b %d")
          mood = entry.mood || "unspecified"
          word_count = entry.word_count || 0
          "#{date}: mood=#{mood}, words=#{word_count}"
        end)
        |> Enum.join("\n")

      system_prompt = """
      You are a compassionate journaling companion analyzing mood patterns.

      Based on the journal entry data below, provide a brief, supportive insight about patterns you notice.

      Guidelines:
      - Be warm and encouraging
      - Focus on positive observations when possible
      - Gently note any patterns worth attention
      - Keep response to 2-3 sentences
      - Don't make clinical assessments or diagnoses

      Journal data (date: mood, word count):
      #{mood_data}

      Respond with ONLY your insight, nothing else.
      """

      case ReqLLM.generate_text(
             Config.text_model(),
             "Analyze these mood patterns",
             Config.text_opts(system_prompt: system_prompt, max_tokens: 500)
           ) do
        {:ok, response} ->
          {:ok, ReqLLM.Response.text(response)}

        {:error, reason} ->
          require Logger
          Logger.error("Mood insights generation failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @prompt_themes [
    "gratitude",
    "personal growth",
    "relationships",
    "goals and dreams",
    "challenges and resilience",
    "self-care",
    "creativity",
    "mindfulness"
  ]

  def prompt_themes, do: @prompt_themes

  # Curated, private, introspective journaling prompts grouped by theme.
  # Used as a graceful fallback when AI prompt generation is unavailable
  # (see generate_prompt/1). These are SELF-directed — the answer is a private
  # journal entry seen by no one — so the voice is reflective and inward.
  #
  # For the SOCIAL, connection-facing ritual prompts (answer = a post shared
  # with your people), see Mosslet.Rituals.Prompts instead.
  @fallback_prompts_by_theme %{
    "gratitude" => [
      "What made you smile today, even if just for a moment?",
      "Who in your life are you grateful for, and why?",
      "Name three small comforts you often overlook.",
      "What's something your past self would be grateful you did?",
      "What part of your body or health are you thankful for today?",
      "Whose kindness are you still carrying with you?"
    ],
    "personal growth" => [
      "What's a lesson you've learned recently?",
      "What would you tell your past self from a year ago?",
      "In what small way are you different than you were last year?",
      "What belief have you outgrown?",
      "What's something you're getting better at, slowly?",
      "Where did you show up for yourself this week?"
    ],
    "relationships" => [
      "Who did you think about today, and why?",
      "When did you last feel truly understood?",
      "Is there someone you owe a kind word to?",
      "What does closeness feel like to you right now?",
      "Who makes you feel most like yourself?",
      "What's a conversation you're glad you had?"
    ],
    "goals and dreams" => [
      "What's something you're looking forward to?",
      "Describe your ideal tomorrow. What would make it great?",
      "If nothing were in the way, what would you start today?",
      "What's one tiny step toward something that matters to you?",
      "What does 'enough' look like for you right now?",
      "What quietly excites you about the months ahead?"
    ],
    "challenges and resilience" => [
      "What's something you'd like to let go of?",
      "What's weighing on you, and what would lighten it?",
      "When did you last surprise yourself with your own strength?",
      "What's a hard thing you're handling better than you expected?",
      "What do you need more of, and less of, right now?",
      "What would 'being gentle with yourself' look like today?"
    ],
    "self-care" => [
      "What's giving you energy lately? What's draining it?",
      "What's a small win you can celebrate today?",
      "How did you rest this week — and was it enough?",
      "What does your body need that you've been ignoring?",
      "What's one thing you can take off your plate?",
      "When did you last do something purely because it felt good?"
    ],
    "creativity" => [
      "What's an idea you can't stop thinking about?",
      "If today were a color, which would it be, and why?",
      "What would you make if no one would ever judge it?",
      "Describe something ordinary as if you'd never seen it before.",
      "What's a small thing you noticed today that others might miss?",
      "What are you curious about right now?"
    ],
    "mindfulness" => [
      "Describe a recent moment when you felt truly present.",
      "What can you see, hear, and feel right now?",
      "What's the mood you're carrying into this moment?",
      "Where did your mind keep wandering today?",
      "What's one thing you can slow down and savor?",
      "How does 'right now' actually feel, underneath the noise?"
    ]
  }

  def fallback_prompts_by_theme, do: @fallback_prompts_by_theme

  def fallback_prompts do
    @fallback_prompts_by_theme |> Map.values() |> List.flatten()
  end

  def random_fallback_prompt do
    Enum.random(fallback_prompts())
  end

  def extract_text_from_image(image_binary, mime_type) do
    alias ReqLLM.Message.ContentPart

    system_prompt = """
    You are an expert OCR assistant that extracts handwritten text from journal images.

    Guidelines:
    - Extract ALL visible handwritten text from the image accurately
    - Preserve paragraph breaks and line structure where sensible
    - Correct obvious spelling errors only if you're highly confident
    - If text is unclear, make your best interpretation
    - Do not add any commentary, explanations, or metadata
    - Return ONLY the extracted text, nothing else
    - If the image contains no readable text, respond with: [No readable text found]

    Privacy note: This content is private journal writing. Process it respectfully and return only the text.
    """

    content = [
      ContentPart.image(image_binary, mime_type),
      ContentPart.text("Please extract all the handwritten text from this journal image.")
    ]

    message = %ReqLLM.Message{role: :user, content: content}

    case ReqLLM.generate_text(
           Config.vision_model(),
           [message],
           Config.vision_opts(system_prompt: system_prompt)
         ) do
      {:ok, response} ->
        text = ReqLLM.Response.text(response)

        if text == "[No readable text found]" do
          {:error, :no_text_found}
        else
          {:ok, text}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
