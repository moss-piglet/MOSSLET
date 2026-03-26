defmodule MossletWeb.PublicLive.Blog.Blog15 do
  @moduledoc false
  use MossletWeb, :live_view
  alias MossletWeb.PublicLive.Blog.Components

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:blog}
      container_max_width={@max_width}
    >
      <Components.blog_article
        date="March 26, 2026"
        title="True Zero-Knowledge Messaging Is Here"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          I am so excited to finally share this with you: MOSSLET now has end-to-end encrypted messaging. We call it Conversations, and it's the private messaging feature we've wanted to build since day one.
        </p>
        <p>
          Every message you send is encrypted on your device before it ever leaves. Every image, too. Not even we can read what you write to each other. That's not a marketing promise — it's a cryptographic guarantee.
        </p>

        <hr />
        <h2 id="why-now">
          <a href="#why-now">
            Why this matters right now
          </a>
        </h2>
        <p>
          Let me give you some context for why we're so fired up about this.
        </p>
        <p>
          On May 8, Meta will
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://fortune.com/2026/03/17/tiktok-meta-no-privacy-controls-why-explainer/"
          >
            roll back their end-to-end encryption
          </a>
          on Instagram direct messages. Their stated reason is child safety (after being found guilty in court of harming them). But let's be honest about what actually happened: one of the largest messaging platforms in the world decided that being able to read your private conversations was more important than protecting them.
        </p>
        <p>
          This is the false choice Big Tech keeps presenting: safety <em>or</em>
          privacy. Pick one. You can't have both.
        </p>
        <p>
          We reject that framing entirely.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/mar_26_2026_e2ee.jpg"}
              class="w-full"
              alt="End-to-end encrypted messaging illustration. Two people communicating privately with a lock symbol between them."
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@rizki_09/illustrations"
              class="ml-1"
            >
              Rizki Ardia
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="how-it-works">
          <a href="#how-it-works">
            How Conversations actually works
          </a>
        </h2>
        <p>
          Here's the technical reality, as simply as I can explain it.
        </p>
        <p>
          When you start a conversation with one of your connections, a unique symmetric key is generated for that conversation. This key gets encrypted separately for each participant using their public key — so only you and the person you're talking to can ever unlock it.
        </p>
        <p>
          Every message is encrypted with that conversation key using
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://nacl.cr.yp.to/"
          >
            NaCl's secretbox
          </a>
          (XSalsa20-Poly1305) before it leaves your device. The server receives an encrypted blob, stores an encrypted blob, and delivers an encrypted blob. At no point does our server see plaintext. It literally can't.
        </p>
        <p>
          This is what "zero-knowledge" actually means. It's not a buzzword — it's an architecture. We designed the system so we
          <em>cannot</em>
          access your messages, even if we wanted to, even if someone compelled us to. There's no secret backdoor, no admin panel that lets us peek. The math won't allow it.
        </p>

        <div class="my-8 overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900">
          <div class="bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-700 dark:to-emerald-700 px-4 sm:px-6 py-4">
            <h3 class="text-white font-semibold text-lg">
              Message Encryption Flow
            </h3>
            <p class="text-teal-100 text-sm mt-1">
              What happens when you send a message
            </p>
          </div>
          <div class="p-4 sm:p-6">
            <div class="flex flex-col sm:flex-row sm:flex-wrap sm:justify-center items-center gap-3 text-sm">
              <div class="w-full sm:w-auto px-4 py-3 bg-amber-100 dark:bg-amber-900/30 rounded-lg text-center border border-amber-200 dark:border-amber-800">
                <div class="font-mono text-amber-800 dark:text-amber-300 text-xs">1. YOU TYPE</div>
                <div class="font-semibold text-amber-900 dark:text-amber-200 mt-1">
                  Plaintext message
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg text-center border border-blue-200 dark:border-blue-800">
                <div class="font-mono text-blue-800 dark:text-blue-300 text-xs">2. YOUR DEVICE</div>
                <div class="font-semibold text-blue-900 dark:text-blue-200 mt-1">
                  Encrypts with conversation key
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-purple-100 dark:bg-purple-900/30 rounded-lg text-center border border-purple-200 dark:border-purple-800">
                <div class="font-mono text-purple-800 dark:text-purple-300 text-xs">
                  3. OUR SERVER
                </div>
                <div class="font-semibold text-purple-900 dark:text-purple-200 mt-1">
                  Stores encrypted blob
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg text-center border border-emerald-200 dark:border-emerald-800">
                <div class="font-mono text-emerald-800 dark:text-emerald-300 text-xs">
                  4. RECIPIENT
                </div>
                <div class="font-semibold text-emerald-900 dark:text-emerald-200 mt-1">
                  Decrypts with their key
                </div>
              </div>
            </div>
            <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700">
              <p class="text-xs text-slate-500 dark:text-slate-400">
                <strong class="text-slate-700 dark:text-slate-300">Key point:</strong>
                The conversation key is encrypted per-participant using asymmetric encryption. Only you and the recipient can unlock it — our server never has access to the plaintext key or your messages.
              </p>
            </div>
          </div>
        </div>

        <hr />
        <h2 id="safety-without-surveillance">
          <a href="#safety-without-surveillance">
            Safety without surveillance
          </a>
        </h2>
        <p>
          Now here's where it gets interesting, and where we differ from the Big Tech approach.
        </p>
        <p>
          Meta argues they need to read your messages to keep people safe. We think that's a false equivalence. You can build real safety features without building a surveillance apparatus.
        </p>
        <p>
          When you share an image in a conversation, it goes through our image safety system
          <em>before</em>
          encryption. First, we send a downsized copy to a vision AI model via
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://openrouter.ai/"
          >
            OpenRouter
          </a>
          — configured with a contractual <code>data_collection: "deny"</code>
          policy, meaning the provider cannot store, log, or train on any image data we send. If that API is unavailable, we fall back to our own local classifier running
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/elixir-nx/bumblebee"
          >
            Bumblebee
          </a>
          on ephemeral servers. Either way, the check returns a simple pass/fail result. If the image is flagged, it doesn't get sent. If it passes, it gets encrypted and delivered.
        </p>
        <p>
          Here's the crucial difference: the safety check happens at the point of sending, not by scanning what's already in your private conversation. We never store the image unencrypted. We never log what was in it. Our provider contracts explicitly prohibit data retention. The check runs, produces a binary result, and the original is gone. The encrypted version is what gets stored and delivered to the recipient.
        </p>

        <div class="my-8 p-6 rounded-xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800">
          <h3 class="text-emerald-700 dark:text-emerald-400 font-bold mb-3">
            How image safety works in Conversations
          </h3>
          <div class="text-sm text-emerald-800 dark:text-emerald-300 space-y-2">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">1.</span>
              <span>You attach an image to your message</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">2.</span>
              <span>
                A downsized copy is sent to a vision AI via OpenRouter (configured with a no-store, no-log, no-train contract)
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">3.</span>
              <span>
                If the API is unavailable, we fall back to our own Bumblebee classifier on ephemeral servers
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">4.</span>
              <span>If it passes: the image is encrypted and sent to the recipient</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">5.</span>
              <span>If it's flagged: the image is rejected and never stored</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">6.</span>
              <span>Either way: no image data is retained — not by us, not by our providers</span>
            </div>
          </div>
        </div>

        <p>
          This approach proves you can have both privacy and safety. You don't need to build a system that reads everyone's messages to catch the bad ones. You can check at the gate and still keep everything locked.
        </p>

        <hr />
        <h2 id="what-you-can-do">
          <a href="#what-you-can-do">
            Everything Conversations can do
          </a>
        </h2>
        <p>
          We didn't just build encryption and call it a day. Conversations is a full-featured messaging experience:
        </p>
        <ul>
          <li>
            <strong>Text messages with rich formatting:</strong>
            Write naturally — your messages support markdown so you can add emphasis, links, and structure.
          </li>
          <li>
            <strong>Encrypted image sharing:</strong>
            Send photos that are encrypted with the conversation key. Add alt text for accessibility and crop images before sending.
          </li>
          <li>
            <strong>Real-time delivery:</strong>
            Messages arrive instantly via WebSocket. You'll see typing indicators when the other person is composing a reply.
          </li>
          <li>
            <strong>Smart compose and delete:</strong>
            Our privacy-first spell checker and dictionary help you get it right before you send. Changed your mind? Delete a message. You stay in control.
          </li>
          <li>
            <strong>Archive conversations:</strong>
            Clean up your inbox without losing anything. Archived conversations are always there if you need them.
          </li>
          <li>
            <strong>Blocking:</strong>
            If someone makes you uncomfortable, block them. It's immediate and comprehensive — they can't message you and won't know why.
          </li>
          <li>
            <strong>Unread badge:</strong>
            A calm, subtle indicator lets you know when new messages are waiting — informative without feeling like an emergency.
          </li>
        </ul>

        <p>
          All of this is built on top of the same encryption layer. Every feature, every interaction, every byte — encrypted end-to-end.
        </p>

        <hr />
        <h2 id="the-bigger-picture">
          <a href="#the-bigger-picture">
            The bigger picture
          </a>
        </h2>
        <p>
          Here's what frustrates me about the current state of messaging. Billions of people use apps like Instagram DMs, Facebook Messenger, and WhatsApp every day. These platforms have the resources to build the most secure messaging systems in the world. And yet they keep finding reasons not to.
        </p>
        <p>
          Instagram's decision to remove default encryption from their DMs is particularly telling. They framed it as protecting kids. But what they built is a system where Meta employees and law enforcement (and others?) can read your private conversations. Is that really safer? Or is it just a different kind of surveillance dressed up as care?
        </p>
        <p>
          We think the answer is obvious: <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.schneier.com/essays/archives/2016/04/the_value_of_encrypt.html"
          >encryption (privacy) keeps you safe</a>. Real safety is systemic and comes from caring about safety and then giving people the tools to protect themselves — blocking, reporting, image safety checks — not from having a corporation read your private thoughts (Instagram was harming kids long before they added end-to-end encryption to their DMs).
        </p>
        <p>
          And let's not forget the business model at play. Meta makes money by understanding you as deeply as possible. Every unencrypted message is another data point, another signal for their advertising machine. When they argue against encryption, they're not just arguing for safety — they're arguing for access to your most intimate digital conversations.
        </p>

        <hr />
        <h2 id="open-source">
          <a href="#open-source">
            Don't take our word for it
          </a>
        </h2>
        <p>
          Everything we've described here is verifiable. MOSSLET is <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/MOSSLET"
          >open source</a>. You can read the encryption code yourself. You can see exactly how conversation keys are generated, how messages are encrypted, how the image safety pipeline works. No trust required — just math.
        </p>
        <p>
          That's the standard we think every platform should be held to. If a company tells you your messages are private, they should be able to show you the code that proves it. If they can't — or won't — ask yourself why.
        </p>

        <hr />
        <h2 id="try-it">
          <a href="#try-it">
            Start a conversation
          </a>
        </h2>
        <p>
          If you're already on MOSSLET, Conversations is live right now. Head to your conversations from the sidebar and start a chat with any of your connections. You'll see the lock icon confirming everything is end-to-end encrypted.
        </p>
        <p>
          If you're not on MOSSLET yet — <a href="/auth/register">come join us</a>. Your first 14 days are free, and you can start having truly private conversations from the moment you sign up.
        </p>
        <p>
          Your words belong to you. Not to us. Not to advertisers. Not to anyone with a warrant and a willingness to ask nicely. Just you, and the people you choose to share them with. 🔒🌱
        </p>
      </Components.blog_article>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(
       :page_title,
       "Blog | True Zero-Knowledge Messaging Is Here"
     )
     |> assign_new(:meta_description, fn ->
       "MOSSLET now has end-to-end encrypted messaging. Every message is encrypted on your device before it leaves — we literally can't read what you write. True zero-knowledge architecture with image safety checks that protect without surveillance. Privacy and safety aren't a trade-off."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/mar_26_2026_e2ee.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "End-to-end encrypted messaging illustration")}
  end
end
