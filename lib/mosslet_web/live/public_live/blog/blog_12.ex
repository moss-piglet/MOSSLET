defmodule MossletWeb.PublicLive.Blog.Blog12 do
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
        date="January 07, 2026"
        title="Introducing Journal: Your Private Space for Reflection"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          I am a parent. And like most parents, I think a lot about what kind of world my kids are growing up in. A world where every thought shared online becomes data to be harvested. Where moments of vulnerability become training data for algorithms designed to manipulate. Where there's nowhere left to just... be.
        </p>

        <p>
          That's why today I'm excited to introduce Journal — a completely private space for reflection, built right into MOSSLET. No connections required. No sharing. No surveillance. Just you and your thoughts.
        </p>

        <hr />
        <h2 id="why-we-built-journal">
          <a href="#why-we-built-journal">
            Why we built Journal
          </a>
        </h2>
        <p>
          Here's something we've been hearing a lot: "I love what MOSSLET stands for, but I don't really want to share stuff with other people. I just want a private space online."
        </p>
        <p>
          And honestly? That makes complete sense. Not everyone wants a social network. Some people just want a corner of the internet that's actually
          <em>theirs</em>
          — a place to write, reflect, and process without worrying about who's watching or what some algorithm is learning about them.
        </p>
        <p>
          So we built Journal for exactly that. Whether you're on MOSSLET to connect with family and friends, or you just want a privacy-first digital sanctuary for your own thoughts, Journal is here for you.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/jan_07_2026_ijpsr.jpg"}
              class="w-full"
              alt="Journal feature illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@evaaa_wahyuni"
              class="ml-1"
            >
              Eva Wahyuni
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="everything-you-need">
          <a href="#everything-you-need">
            Everything you need, nothing you don't
          </a>
        </h2>
        <p>
          Journal is designed to get out of your way and let you write. Here's what you can do:
        </p>
        <ul>
          <li>
            <strong>Write freely:</strong>
            Create entries with optional titles, track your mood from 35+ different options (joyful, anxious, nostalgic, creative — whatever fits), and watch your word count grow as you reflect.
          </li>
          <li>
            <strong>Organize with Books:</strong>
            Group related entries into books — maybe one for travel memories, another for gratitude practice, a third for working through something difficult. Each book gets its own cover color (or upload a photo) and description.
          </li>
          <li>
            <strong>Track your progress:</strong>
            See your total entries, word count, and current writing streak right on your dashboard. Small wins matter.
          </li>
          <li>
            <strong>Star your favorites:</strong>
            Mark entries that mean something special so you can find them again easily.
          </li>
          <li>
            <strong>Privacy screen:</strong>
            Quickly hide the content of your journals if someone enters the room, with a visual countdown until your password will be required to reveal them again.
          </li>
          <li>
            <strong>Auto-save:</strong>
            Your writing saves automatically as you go. No more losing thoughts to a browser crash or forgotten save button.
          </li>
        </ul>

        <p>
          We kept the interface distraction-free on purpose. When you're writing, you're <em>just</em>
          writing. When you're reading past entries, you're in a calm, focused space. No notifications competing for your attention. No suggested content. Just your own words.
        </p>

        <hr />
        <h2 id="ai-that-actually-helps">
          <a href="#ai-that-actually-helps">
            AI that actually helps (without spying)
          </a>
        </h2>
        <p>
          Here's where it gets interesting. We've added some AI-powered features to Journal, but we've done it in a way that respects your privacy completely.
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            AI Features in Journal
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-3">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✨</span>
              <span>
                <strong>Journaling prompts:</strong>
                Stuck on what to write? Tap "Inspire me" and get a thoughtful, personalized prompt tailored to your current mood. Great for days when you want to write but don't know where to start.
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">🔮</span>
              <span>
                <strong>Mood insights:</strong>
                After you've written a few entries, we'll generate a gentle, supportive summary of patterns we notice in your journaling — like "You've been writing more on weekends and seem most creative after morning entries." It's like having a thoughtful friend reflect back what they've noticed.
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">📷</span>
              <span>
                <strong>Handwritten journal upload:</strong>
                Prefer writing by hand? Take a photo of your handwritten pages and we'll digitize them for you. The AI reads your handwriting, even detects dates, and converts it into a searchable, encrypted entry.
              </span>
            </div>
          </div>
        </div>

        <p>
          Now, I know what you're thinking. AI usually means your data getting sent to some server, analyzed, stored, and used to train models that benefit everyone except you.
        </p>
        <p>
          Not here. Here's how we've done it differently:
        </p>

        <hr />
        <h2 id="privacy-first-ai">
          <a href="#privacy-first-ai">
            Privacy-first AI
          </a>
        </h2>
        <p>
          Every AI feature in Journal follows a simple principle: <em>your data stays yours</em>.
        </p>
        <ul>
          <li>
            <strong>Prompts are generated without your content:</strong>
            When you ask for a journaling prompt, we only send your current mood (if you've set one) — not your entries, not your history, nothing personal. The AI generates a prompt based on that single piece of context.
          </li>
          <li>
            <strong>Mood insights use minimal data:</strong>
            We send only dates, moods, and word counts to generate insights — never the actual content of what you've written. The pattern "March 15: happy, 450 words" tells the AI enough to notice trends without revealing what you actually said.
          </li>
          <li>
            <strong>Handwriting processing is immediate:</strong>
            When you upload a photo of your handwriting, it's processed once to extract the text, then immediately deleted. The extracted text is encrypted with your personal key before it ever touches our database. The original image? Gone.
          </li>
          <li>
            <strong>No training on your data:</strong>
            We don't use your journal entries, prompts, or insights to train AI models. Ever. Your reflections are not our oil.
          </li>
        </ul>

        <div class="my-8 overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900">
          <div class="bg-gradient-to-r from-emerald-600 to-teal-600 dark:from-emerald-700 dark:to-teal-700 px-4 sm:px-6 py-4">
            <h3 class="text-white font-semibold text-lg">
              How Journal Encryption Works
            </h3>
            <p class="text-emerald-100 text-sm mt-1">
              Your entries are encrypted with your personal key — only you can read them
            </p>
          </div>
          <div class="p-4 sm:p-6">
            <div class="flex flex-col sm:flex-row sm:flex-wrap sm:justify-center items-center gap-3 text-sm">
              <div class="w-full sm:w-auto px-4 py-3 bg-amber-100 dark:bg-amber-900/30 rounded-lg text-center border border-amber-200 dark:border-amber-800">
                <div class="font-mono text-amber-800 dark:text-amber-300 text-xs">1. WRITE</div>
                <div class="font-semibold text-amber-900 dark:text-amber-200 mt-1">
                  Your Entry
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg text-center border border-blue-200 dark:border-blue-800">
                <div class="font-mono text-blue-800 dark:text-blue-300 text-xs">2. ENCRYPT</div>
                <div class="font-semibold text-blue-900 dark:text-blue-200 mt-1">
                  With Your Key
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-purple-100 dark:bg-purple-900/30 rounded-lg text-center border border-purple-200 dark:border-purple-800">
                <div class="font-mono text-purple-800 dark:text-purple-300 text-xs">3. STORE</div>
                <div class="font-semibold text-purple-900 dark:text-purple-200 mt-1">
                  Encrypted Blob
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg text-center border border-emerald-200 dark:border-emerald-800">
                <div class="font-mono text-emerald-800 dark:text-emerald-300 text-xs">4. DECRYPT</div>
                <div class="font-semibold text-emerald-900 dark:text-emerald-200 mt-1">
                  Only By You
                </div>
              </div>
            </div>
            <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700">
              <p class="text-xs text-slate-500 dark:text-slate-400">
                <strong class="text-slate-700 dark:text-slate-300">Key point:</strong>
                Unlike posts shared with connections, journal entries use <em>only</em>
                your personal encryption key. There's no shared key, no recipient list — just you. Even we can't read what you've written.
              </p>
            </div>
          </div>
        </div>

        <hr />
        <h2 id="what-we-actually-store">
          <a href="#what-we-actually-store">
            What we actually store
          </a>
        </h2>
        <p>
          Transparency matters, so let me be specific about what lives in our database for each journal entry:
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            What's Encrypted vs. What's Not
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-2">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">🔒</span>
              <span>
                <strong>Encrypted:</strong> Title, body, mood — the actual content of your thoughts
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-slate-400 font-bold">📊</span>
              <span>
                <strong>Functional metadata:</strong>
                Entry date, word count, favorite status, book assignment — things we need to show you your journal, but that reveal nothing meaningful about your inner life
              </span>
            </div>
          </div>
        </div>

        <p>
          The word count lets us show you stats. The date lets us sort entries. The book ID lets us organize them. But the words themselves — your actual reflections — those are encrypted noise to anyone who isn't you.
        </p>
        <p>
          Even the AI-generated mood insights get encrypted with your personal key before storage. If someone got our database, they'd find encrypted blobs. The insight text only becomes readable when
          <em>you</em>
          unlock it with your password.
        </p>

        <hr />

        <h2 id="a-place-that-is-yours">
          <a href="#a-place-that-is-yours">
            A place that is yours
          </a>
        </h2>
        <p>
          I started building MOSSLET because I wanted a safe place for my family to share moments without becoming data to be mined. Journal extends that mission to something even more fundamental: a safe place for your own thoughts.
        </p>
        <p>
          In a world where every platform wants to know what you're thinking so they can sell that information to advertisers, Journal is a small act of rebellion. A place where your reflections stay yours. Where AI helps without harvesting. Where privacy isn't a marketing claim — it's a cryptographic reality.
        </p>
        <p>
          Whether you're processing something difficult, practicing gratitude, tracking your creative projects, or just want somewhere to dump your thoughts at the end of a long day, Journal is here for you.
        </p>
        <p>
          Ready to claim your private corner of the internet?
          <a href="/auth/register">
            Join MOSSLET
          </a>
          and start your journal today.
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
       "Blog | Introducing Journal: Your Private Space for Reflection"
     )
     |> assign_new(:meta_description, fn ->
       "Introducing Journal — a completely private journaling feature in MOSSLET. Write freely with encrypted entries only you can read. AI-powered prompts and mood insights help without harvesting your data. Organize with books, upload handwritten pages, and track your writing streak. Your thoughts, truly yours."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/jan_07_2026_ijpsr.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Journal feature illustration")}
  end
end
