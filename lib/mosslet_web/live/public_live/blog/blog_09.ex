defmodule MossletWeb.PublicLive.Blog.Blog09 do
  @moduledoc false
  use MossletWeb, :live_view
  alias MossletWeb.PublicLive.Blog.Components

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:blog}
      container_max_width={@max_width}
      key={@key}
    >
      <Components.blog_article
        date="November 27, 2025"
        title="Unlock Sessions: Privacy Meets Convenience This Holiday Season"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          The autumn leaves are falling and the coziness is here — a time for gathering with loved ones, sharing memories, and yes, spending a bit more time on our devices connecting with friends and family near and far. At MOSSLET, we've been thinking about how to make your experience both secure and convenient this holiday season.
        </p>

        <p>
          Today we're excited to share how our unlock session feature works, and why it's a perfect example of how privacy and convenience can work together rather than against each other.
        </p>

        <hr />
        <h2 id="the-problem-with-sessions">
          <a href="#the-problem-with-sessions">
            The problem with sessions
          </a>
        </h2>
        <p>
          Here's the thing about web sessions: they're a necessary trade-off between security and usability. Most platforms handle this by keeping you logged in forever with a simple cookie — convenient, but if someone gets access to your device or that cookie, they have full access to your account.
        </p>
        <p>
          At MOSSLET, your data is encrypted with a key derived from your password. This is what makes your information truly private — not even we can read it without your password! But this creates a challenge: if your session expires and your encryption key is cleared from memory, you'd normally have to do a full login again.
        </p>
        <p>
          Enter the unlock session — our solution that gives you the best of both worlds.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/nov_27_2025_usfys.jpg"}
              class="w-full"
              alt="Autumn leaves unlock session"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@melkszr/illustrations"
              class="ml-1"
            >
              Esma melike Sezer
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="how-it-works">
          <a href="#how-it-works">
            How it works
          </a>
        </h2>
        <p>
          When you check "remember me" during login, we set an encrypted cookie that remembers who you are for up to 60 days. But here's where it gets interesting: your encryption key (derived from your password) lives in your browser session, which expires more quickly for security reasons.
        </p>
        <p>
          So what happens when your session key expires but your remember me cookie is still valid? Instead of making you go through the full login process again, we simply ask for your password to unlock your session. Think of it like coming home after the holidays — you still have your house key, but you need to enter your code to turn off the alarm.
        </p>
        <ul>
          <li>
            <strong>Your identity is remembered:</strong>
            The remember me cookie keeps you authenticated
          </li>
          <li>
            <strong>Your data stays protected:</strong>
            Without your password, your encrypted data remains locked
          </li>
          <li>
            <strong>Quick re-entry:</strong>
            Just enter your password — no email, no username, no 2FA (you already did that)
          </li>
        </ul>

        <hr />
        <h2 id="privacy-by-design">
          <a href="#privacy-by-design">
            Privacy by design
          </a>
        </h2>
        <p>
          This approach reflects our core philosophy: privacy shouldn't come at the cost of a frustrating user experience. Here's why the unlock session matters:
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            Security Benefits
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-2">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                Encryption keys aren't stored long-term — they're derived fresh from your password
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                Even if someone steals your cookie, they can't access your encrypted data without your password
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>Session keys expire regularly, limiting the window of vulnerability</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>You stay in control — only your password can unlock your data</span>
            </div>
          </div>
        </div>

        <p>
          Compare this to how most platforms work: once you're logged in, everything is accessible until you explicitly log out. They might tout "secure encryption" but if the keys are always available, that encryption is more like a screen door than a vault.
        </p>

        <hr />
        <h2 id="convenience-without-compromise">
          <a href="#convenience-without-compromise">
            Convenience without compromise
          </a>
        </h2>
        <p>
          We know what you're thinking: "But I don't want to enter my password every time!" And you won't have to — not every time. The session key persists through normal browsing. It's only when your session naturally expires (or you close your browser without the remember me option) that you'll need to unlock again.
        </p>
        <p>
          When that moment comes, it's a quick password entry and you're back in. No hunting for your email confirmation, no re-entering your 2FA code, no starting from scratch. Just a gentle reminder that your privacy is being actively protected.
        </p>
        <p>
          It's like the difference between locking your front door every time you leave (annoying) versus having a door that locks automatically after a reasonable amount of time (smart security).
        </p>

        <hr />
        <h2 id="this-holiday-season">
          <a href="#this-holiday-season">
            This holiday season
          </a>
        </h2>
        <p>
          As you gather with friends and family, share photos from Thanksgiving, plan holiday get-togethers, and connect with loved ones you haven't seen in a while, we hope MOSSLET can be a place where you feel both welcome and secure.
        </p>
        <p>
          The unlock session feature is just one small example of how we're trying to do things differently. We believe you shouldn't have to choose between privacy and a pleasant experience. You deserve both.
        </p>
        <p>
          Thank you for being part of our community and for believing that social media can be better. From all of us at <a href="/">MOSSLET</a>, we wish you a warm and wonderful autumn season filled with connection, joy, and just the right amount of privacy. 🍂
        </p>

        <p>
          Tell a friend about ethical social media and
          <a href="/auth/register">
            switch to MOSSLET
          </a>
          today to start getting the privacy and convenience you deserve.
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
       "Blog | Unlock Sessions: Privacy Meets Convenience This Holiday Season"
     )
     |> assign_new(:meta_description, fn ->
       "Learn how MOSSLET's unlock session feature balances privacy with convenience. When your session key expires, the remember me cookie keeps you authenticated while your encrypted data stays protected until you re-enter your password. Privacy and convenience working together this holiday season."
     end)}
  end
end
