defmodule MossletWeb.PublicLive.Blog.Blog13 do
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
        date="January 15, 2026"
        title="How We Built Privacy-First AI (And Why It Matters)"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          We get this question a lot: "Wait, you have AI features? How is that private?"
        </p>
        <p>
          It's a fair question! The AI industry has trained us to expect a trade-off — cool features in exchange for our data getting hoovered up and used to train models that benefit Big Tech shareholders. But here's the thing: it doesn't have to be that way.
        </p>
        <p>
          Today I want to pull back the curtain on exactly how we've built AI into MOSSLET without compromising on privacy. No vague promises. No marketing speak. Just the technical reality of how this actually works.
        </p>

        <hr />
        <h2 id="the-problem-with-ai-today">
          <a href="#the-problem-with-ai-today">
            The problem with AI today
          </a>
        </h2>
        <p>
          Most AI-powered apps work like this: you upload a photo or type some text, it gets sent to a server farm, processed by a model that was trained on billions of other people's data, and then your input becomes part of that training data for the next version. Your journal entry about your anxiety becomes a data point. Your handwritten letter to your grandmother becomes training material.
        </p>
        <p>
          The companies doing this often bury it in terms of service nobody reads. "By using our service, you grant us a perpetual, worldwide license to..." — you know the drill.
        </p>
        <p>
          We wanted something different. We wanted AI that <em>helps</em> without <em>harvesting</em>.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/jan_15_2026_hwbpfai.jpg"}
              class="w-full"
              alt="Privacy-first AI illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@triwiranto/illustrations"
              class="ml-1"
            >
              Tri wiranto
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="our-approach">
          <a href="#our-approach">
            Our approach: three layers of protection
          </a>
        </h2>
        <p>
          We use AI for a handful of specific features: generating journaling prompts, reading handwritten journal pages, checking images for safety, and creating mood insights from your writing patterns. Here's how we keep each of these private.
        </p>

        <h3 class="text-lg font-semibold mt-6 mb-3">Layer 1: Send only what's necessary</h3>
        <p>
          When you tap "Inspire me" for a journaling prompt, we don't send your previous entries, your name, or your history. We send your current mood — that's it. One word like "anxious" or "hopeful." The AI generates a thoughtful prompt from that single piece of context.
        </p>
        <p>
          For mood insights, we send dates, mood labels, and word counts. "January 10: grateful, 342 words." That's enough for the AI to spot patterns like "you write more on weekends" without ever seeing what you actually wrote.
        </p>

        <h3 class="text-lg font-semibold mt-6 mb-3">Layer 2: Process and delete</h3>
        <p>
          Handwritten journal uploads are the trickiest case — the AI needs to see your actual handwriting to digitize it. Here's our approach: the image gets sent, processed once, and immediately deleted. The extracted text gets encrypted with your personal key before it ever touches our database. We don't store the original image. We don't keep logs of what was in it. It's processed and gone.
        </p>

        <h3 class="text-lg font-semibold mt-6 mb-3">Layer 3: Contractual data protection</h3>
        <p>
          Even when we do send data to AI providers, we use services that contractually guarantee they won't train on your data. We route requests through
          <a target="_blank" rel="noopener noreferrer" href="https://openrouter.ai/">OpenRouter</a>
          with explicit <code>data_collection: "deny"</code>
          flags. This isn't just a polite request — it's a contractual agreement that your data won't be used for model training.
        </p>

        <div class="my-8 p-6 rounded-xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800">
          <h3 class="text-emerald-700 dark:text-emerald-400 font-bold mb-3">
            What "data_collection: deny" actually means
          </h3>
          <div class="text-sm text-emerald-800 dark:text-emerald-300 space-y-2">
            <p>
              When we send a request to process your handwritten journal page, the AI provider receives the image, processes it, returns the text, and that's the end of the interaction. They're contractually prohibited from:
            </p>
            <ul class="list-disc pl-5 space-y-1">
              <li>Storing your image or the extracted text</li>
              <li>Using your data to train or improve their models</li>
              <li>Logging the content of your request</li>
              <li>Sharing your data with third parties</li>
            </ul>
            <p class="mt-3">
              It's the difference between asking a friend to read something for you versus posting it on a billboard.
            </p>
          </div>
        </div>

        <hr />
        <h2 id="local-ai-backup">
          <a href="#local-ai-backup">
            Our local AI backup
          </a>
        </h2>
        <p>
          Here's something we're particularly proud of: we also run AI models directly on our own servers using <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/elixir-nx/bumblebee"
          >Bumblebee</a>, an Elixir machine learning library. This gives us a fallback that never leaves our infrastructure.
        </p>
        <p>
          For image safety checks, we first try an external API with all the protections described above. If that service is unavailable (outage, rate limiting, etc.), we fall back to our local model. It runs on our servers, processes your image, and returns a simple "safe" or "not safe" — no external API call required.
        </p>
        <p>
          This hybrid approach means we can offer AI features without being completely dependent on external providers, and for many use cases, your data never leaves our servers at all.
        </p>

        <hr />
        <h2 id="what-about-webllm">
          <a href="#what-about-webllm">
            "Why not run AI in my browser?"
          </a>
        </h2>
        <p>
          Some privacy advocates suggest running AI models directly in users' browsers — no server involved at all. Safari 26 even added WebGPU support that makes this technically possible. We considered it!
        </p>
        <p>
          But here's the reality: current vision models that can read handwriting well are 2-8 gigabytes. Asking you to download gigabytes of model weights before you can use a feature isn't a great experience. Your phone would get hot, your battery would drain, and the quality would be worse than what we can offer server-side.
        </p>
        <p>
          Maybe someday the models will be small enough and fast enough that browser-based AI makes sense. When that day comes, we'll be excited to explore it. For now, our server-side approach with strong contractual protections offers the best balance of privacy, quality, and usability.
        </p>

        <hr />
        <h2 id="transparency-in-practice">
          <a href="#transparency-in-practice">
            Transparency in practice
          </a>
        </h2>
        <p>
          Let me be specific about what happens with each AI feature:
        </p>

        <div class="my-8 overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900">
          <div class="bg-gradient-to-r from-amber-500 to-orange-500 dark:from-amber-600 dark:to-orange-600 px-4 sm:px-6 py-4">
            <h3 class="text-white font-semibold text-lg">
              AI Feature Data Flow
            </h3>
            <p class="text-amber-100 text-sm mt-1">
              What gets sent, where it goes, and what happens to it
            </p>
          </div>
          <div class="divide-y divide-slate-200 dark:divide-slate-700">
            <div class="p-4 sm:p-6">
              <h4 class="font-semibold text-slate-900 dark:text-slate-100">✨ Journaling Prompts</h4>
              <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
                <strong>Sent:</strong> Your current mood (one word) or nothing<br />
                <strong>Not sent:</strong> Your entries, history, name, or any personal data<br />
                <strong>Stored:</strong> Nothing — prompts are generated fresh each time
              </p>
            </div>
            <div class="p-4 sm:p-6">
              <h4 class="font-semibold text-slate-900 dark:text-slate-100">📷 Handwriting OCR</h4>
              <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
                <strong>Sent:</strong> Your photo (resized to 1280px max)<br />
                <strong>Processing:</strong> Image → text extraction → immediate deletion<br />
                <strong>Stored:</strong> Only the encrypted text (original image deleted)
              </p>
            </div>
            <div class="p-4 sm:p-6">
              <h4 class="font-semibold text-slate-900 dark:text-slate-100">🔮 Mood Insights</h4>
              <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
                <strong>Sent:</strong> Dates, mood labels, and word counts only<br />
                <strong>Not sent:</strong> The actual content of any entry<br />
                <strong>Stored:</strong> Encrypted insight text (only you can read it)
              </p>
            </div>
            <div class="p-4 sm:p-6">
              <h4 class="font-semibold text-slate-900 dark:text-slate-100">🛡️ Image Safety Checks</h4>
              <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
                <strong>First try:</strong> Local model on our servers (no external call)<br />
                <strong>Fallback:</strong> External API with data_collection: deny<br />
                <strong>Stored:</strong> Nothing — just a pass/fail result
              </p>
            </div>
          </div>
        </div>

        <hr />
        <h2 id="why-this-matters">
          <a href="#why-this-matters">
            Why this matters
          </a>
        </h2>
        <p>
          The AI gold rush has convinced a lot of people that privacy and AI are incompatible — that you have to choose between useful features and keeping your data safe. That's a false choice created by companies whose business model depends on harvesting your information.
        </p>
        <p>
          We're proving it doesn't have to be that way. You can have AI-powered journaling prompts without your thoughts becoming training data. You can digitize your handwritten journals without those intimate reflections being stored on someone else's servers. You can get mood insights without an algorithm building a psychological profile of you.
        </p>
        <p>
          Privacy-first AI isn't just possible — it's here, and it works.
        </p>

        <hr />
        <h2 id="try-it-yourself">
          <a href="#try-it-yourself">
            Try it yourself
          </a>
        </h2>
        <p>
          The best way to understand privacy-first AI is to experience it. Create a
          <a href="/auth/register">free MOSSLET account</a>
          with our hassle-free 14-day free trial, open Journal, and try the "Inspire me" button. Upload a photo of some handwriting. Watch how it just... works, without asking you to agree to hand over your data.
        </p>
        <p>
          That's what ethical software feels like. And honestly? It feels pretty good.
        </p>
        <p>
          Questions about how any of this works? I love talking about this stuff — reach out anytime. Building in public means being accountable, and I'm happy to explain any technical detail you're curious about.
        </p>
        <p>
          Here's to AI that helps without harvesting. 🌱
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
       "Blog | How We Built Privacy-First AI (And Why It Matters)"
     )
     |> assign_new(:meta_description, fn ->
       "A deep dive into how MOSSLET implements AI features without compromising privacy. Learn about our three-layer approach: minimal data transmission, process-and-delete workflows, and contractual data protection. Privacy-first AI isn't just possible — it's here."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/jan_15_2026_hwbpfai.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Privacy-first AI illustration")}
  end
end
