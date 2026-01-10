defmodule Mosslet.Journal.AI do
  @moduledoc """
  AI-powered features for journaling.

  Provides:
  - Journaling prompts - AI-generated reflection questions
  - Content moderation helper - Feedback on post appropriateness before sharing
  - Mood insights - Weekly AI-generated summaries of emotional patterns
  """

  @model "openrouter:openai/gpt-4o-mini"
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

    case ReqLLM.generate_text(@model, "Generate a journaling prompt",
           system_prompt: system_prompt
         ) do
      {:ok, response} ->
        {:ok, ReqLLM.Response.text(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def check_content_appropriateness(content) do
    system_prompt = """
    You are a content moderation assistant. Analyze the following text that someone wants to share publicly.

    Provide brief, helpful feedback on:
    1. Whether it seems appropriate for public sharing
    2. Any potentially sensitive information (personal details, locations, etc.)
    3. Tone and how it might be perceived by others

    Be supportive and non-judgmental. The goal is to help, not criticize.
    Keep your response concise (2-4 sentences max).
    """

    case ReqLLM.generate_text(@model, content, system_prompt: system_prompt) do
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
    You are a content moderator for a social platform. Evaluate if this content is appropriate for PUBLIC sharing.

    ALLOW (respond with APPROVED):
    - Opinions, even strong or critical ones
    - Disagreements and debates
    - Personal experiences and stories
    - News discussion and commentary
    - Venting or expressing frustration (without targeting individuals)
    - Satire and humor
    - Political opinions

    BLOCK (respond with BLOCKED and a brief reason):
    - Direct harassment or targeted attacks on specific individuals
    - Hate speech targeting protected groups (race, religion, gender, sexuality, disability)
    - Explicit calls for violence
    - Doxxing or sharing private information about others
    - Spam or scam content
    - Illegal content

    Respond with ONLY one of these formats:
    APPROVED
    or
    BLOCKED: [brief reason in 10 words or less]

    Be lenient - when in doubt, approve. We value free expression.
    """

    case ReqLLM.generate_text(@model, content, system_prompt: system_prompt) do
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

      case ReqLLM.generate_text(@model, "Analyze these mood patterns",
             system_prompt: system_prompt
           ) do
        {:ok, response} ->
          {:ok, ReqLLM.Response.text(response)}

        {:error, reason} ->
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

  def fallback_prompts do
    [
      "What made you smile today, even if just for a moment?",
      "What's something you're looking forward to?",
      "Describe a recent moment when you felt truly present.",
      "What's a small win you can celebrate today?",
      "Who in your life are you grateful for, and why?",
      "What's something you'd like to let go of?",
      "What would you tell your past self from a year ago?",
      "What's giving you energy lately? What's draining it?",
      "Describe your ideal tomorrow. What would make it great?",
      "What's a lesson you've learned recently?"
    ]
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

    case ReqLLM.generate_text(@model, [message], system_prompt: system_prompt) do
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
