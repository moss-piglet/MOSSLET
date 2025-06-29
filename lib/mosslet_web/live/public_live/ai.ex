defmodule MossletWeb.PublicLive.Ai do
  @moduledoc false
  use MossletWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="mx-auto max-w-2xl space-y-16 divide-y divide-gray-100 lg:mx-0 lg:max-w-none">
          <div class="grid grid-cols-1 gap-x-8 gap-y-10">
            <div>
              <h2 class="text-3xl font-bold tracking-tight text-zinc-900">AI features</h2>
              <p class="mt-4 leading-7 text-zinc-600">
                We currently feature access to industry-leading Large Language Models (LLMs), like ChatGPT. These are essentially language-generation systems that are able to provide responses to questions and "converse" with you.
              </p>
            </div>
            <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:col-span-2 lg:gap-8">
              <span class="group">
                <div class="group-hover:bg-emerald-50 sm:group-hover:scale-105 transition rounded-2xl bg-gray-50 p-10">
                  <h3 class=" text-base font-semibold leading-7 text-emerald-600 inline-flex items-center align-middle">
                    <.icon
                      name="hero-cpu-chip-solid"
                      class="h-5 w-5 mr-1 inline-flex items-center align-middle"
                    /> Conversational
                  </h3>
                  <dl class="mt-3 space-y-1 text-sm leading-6 text-zinc-600">
                    <div class="mt-1">
                      <p>
                        Create unlimited real-time conversations with control over the model and its settings.
                      </p>
                    </div>
                  </dl>
                </div>
              </span>
              <span class="group">
                <div class="group-hover:bg-emerald-50 sm:group-hover:scale-105 transition rounded-2xl bg-gray-50 p-10">
                  <h3 class=" text-base font-semibold leading-7 text-emerald-600">
                    <.icon name="hero-banknotes-solid" class="h-5 w-5 mr-1 inline-flex items-center" />
                    Tokens
                  </h3>
                  <dl class="mt-3 space-y-1 text-sm leading-6 text-zinc-600">
                    <div class="mt-1">
                      <p>
                        Receive monthly tokens and upgrade/downgrade at any time.
                      </p>
                    </div>
                  </dl>
                </div>
              </span>
            </div>
          </div>
        </div>

        <h2 class="mt-16 text-2xl font-bold tracking-tight text-gray-900">How it works (so far)</h2>
        <span class="space-y-6 leading-6">
          <p class="mt-6">
            To create a Conversation, you need to first sign up for a paid subscription. Each paid subscription tier comes with a number of tokens that are used to give you access to the AI systems.
          </p>

          <p>
            Once you have your subscription in place, you can create a Conversation. Upon doing so, you can pick from our currently offered selection of chat models, with "gpt-4" being the most advanced, and set a name for the Conversation and fine-tune the model settings (this can be adjusted at any time).
          </p>

          <p>
            Once in the conversation you can edit the system message, which defaults to "You are a helpful assistant" — altering the system message will change the "personality" or "behavior" of the model. Then, simply type your first message and wait for a response. You will see responses streamed back in real-time with a real-time update of your remaining tokens for the month and a final token count of that message response (how many tokens it cost).
          </p>

          <p>
            <img
              src="https://videoapi-muybridge.vimeocdn.com/animated-thumbnails/image/1cfe76f5-8710-44a9-9eae-eea1175193e4.gif?ClientID=vimeo-core-prod&amp;Date=1697827053&amp;Signature=5e66d2786242c31a5b4211d84fde8a1a9aa68423"
              style="max-width: 100%"
            />
          </p>

          <p>
            It's important to note that the entire Conversation (message chain) is sent each time to the LLM, which enables richer conversations, but also could increase the rate at which you use your monthly tokens.
          </p>

          <p>
            To conserve tokens, it's recommended that you create new conversations for new questions you have, or simply delete any older messages in the Conversation. This keeps the size of the Conversation (message chain) to a minimum, potentially reducing the amount of tokens it uses.
          </p>

          <p>
            You can also cancel a response from the chatbot in real-time to stop any responses that you feel are running on for too long. Tip: you can ask questions like "Please provide a BRIEF answer to what is the moon?" to increase the likelihood of a shorter response.
          </p>

          <h3 class="text-lg font-bold">
            More on tokens
          </h3>

          <p>
            Tokens are how the LLMs "see" the data and how the companies behind their services charge for them. So, rather than paying for the number of words or characters of text, we pay based on the number of tokens used in an exchange with a LLM. Here's a <.link
              navigate="https://www.theguardian.com/technology/ng-interactive/2023/nov/01/how-ai-chatbots-like-chatgpt-or-bard-work-visual-explainer"
              class="text-emerald-600 hover:text-emerald-500"
              rel="_noopener"
              target="_blank"
            >great visual explainer of how it all works</.link>.
          </p>

          <p>
            If that sounds confusing or crazy, it gets better (worse). A token roughly translates to about 4-characters of text (including spaces and symbols). Some translations suggest that 1,000 tokens is about 750 words.
          </p>

          <p>
            We don't want you to have to worry or think about any of that. So, when you pay for a subscription, you get a set amount of monthly tokens to use that resets each month for as long as your subscription remains active.
          </p>

          <h3 class="text-lg font-bold">
            Conversation privacy
          </h3>

          <p>
            Privacy, and awareness of your privacy, is important to us, so we wanted to point out where things differ slightly from the rest of the features on Mosslet.
          </p>

          <p>
            Typically, your data on Mosslet is asymmetrically encrypted. Meaning that there's no way for us to ever know the actual content of it.
          </p>

          <p>
            However, with the AI Conversations, the data is symmetrically encrypted. This means that it is encrypted at-rest and in-transit with strong encryption and is safe and secure. But, in the event of a legal request from a governing authority, it would be possible for us to decrypt the Conversation data and hand it over — like the message content for a Conversation.
          </p>

          <p>
            If you are concerned about potential legal requests for your Conversation data (we've never received one), or you are in a highly sensitive position, you may want to consider deleting the messages or Conversations from your Conversation page.
          </p>

          <p>
            Ultimately, your Conversation data is private, secure, and NOT used to train the models.
          </p>

          <h3 class="text-lg font-bold">
            Into the future
          </h3>

          <p>
            We're really excited for the possibilities with Conversations and the new information lanes it opens up for people. We've got lots more AI ideas and features in the works, always with a focus on safety and privacy, and we look forward to sharing them with you, stay tuned!
          </p>

          <p class="text-zinc-500">
            <em>We hope you join us on this road to a better (online) life.</em>
          </p>

          <p>Mark & Ryan</p>
          Creator & Co-founders of Mosslet / Moss Piglet
        </span>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
