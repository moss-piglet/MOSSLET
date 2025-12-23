defmodule MossletWeb.PublicLive.Blog.Blog11 do
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
        date="December 22, 2025"
        title="Introducing Our Referral Program: Share the Love, Get Paid"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          I am a parent. And like most parents, I want to build something meaningful — not just for my own kids, but for everyone's kids. That's why I built MOSSLET: a place where families can share moments without becoming the oil that makes a product that determines their behavior.
        </p>

        <p>
          Today I'm excited to share something we've been working on that I think captures what we're really about: our new <a href="/referrals">referral program</a>. And before you roll your eyes at another "refer a friend" scheme, hear me out — because this one is different.
        </p>

        <hr />
        <h2 id="when-did-your-social-network-pay-you">
          <a href="#when-did-your-social-network-pay-you">
            When's the last time your social network paid you?
          </a>
        </h2>
        <p>
          Big Tech has made billions — <em>billions</em>
          — from your data. Your photos, your conversations, your habits, your children's faces. They profit while you get... targeted ads and algorithmic manipulation.
        </p>
        <p>
          We wanted to flip that script entirely.
        </p>
        <p>
          When you share MOSSLET with friends and family, and they join, you get paid. Real money. Not points, not credits, not some confusing rewards system that requires a PhD to understand. Actual cash deposited directly to your bank via Stripe.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/dec_22_2025_stlgp.jpg"}
              class="w-full"
              alt="Surveillance-resistant architecture illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@gettyimages"
              class="ml-1"
            >
              Getty Images
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="how-it-works">
          <a href="#how-it-works">
            How it actually works
          </a>
        </h2>
        <p>
          It's genuinely simple:
        </p>
        <ol>
          <li>You share your unique referral link with people you care about</li>
          <li>They get 20% off their first payment (because everyone wins)</li>
          <li>
            You earn 30% on their subscription payments — and this is <em>recurring</em>, not just a one-time thing
          </li>
        </ol>
        <p>
          For lifetime purchases, you get 35% of what they pay. That's a meaningful amount of money for simply sharing something you believe in.
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            Beta Bonus: These Rates Won't Last
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-2">
            <p>
              Right now, during our beta period, we're offering significantly higher commission rates to early supporters. The 30% subscription rate will drop to 15% after beta, and the 35% lifetime rate will drop to 20%.
            </p>
            <p>
              If you join during beta and start referring, you lock in the higher rates. It's our way of saying thank you to the people who believed in us early.
            </p>
          </div>
        </div>

        <hr />
        <h2 id="why-this-matters">
          <a href="#why-this-matters">
            Why this matters to me
          </a>
        </h2>
        <p>
          I've written before about <a href="/blog/articles/01">data brokers</a>
          and <a href="/blog/articles/02">surveillance capitalism</a>. The business model of most social platforms is fundamentally extractive — they take from you and give to shareholders.
        </p>
        <p>
          We wanted to create something where growth benefits everyone. When MOSSLET grows, it's because real people told real friends about something they genuinely value. And those people get rewarded for helping us build a community that respects privacy.
        </p>
        <p>
          This isn't affiliate marketing with creepy tracking pixels and shadowy data sharing. Your referral code is encrypted just like everything else on MOSSLET. We track referrals without compromising anyone's privacy — because that's the whole point.
        </p>

        <hr />
        <h2 id="real-numbers">
          <a href="#real-numbers">
            Let's talk real numbers
          </a>
        </h2>
        <p>
          Here's a concrete example: if 10 of your friends subscribe monthly at $10/month, you'd earn about $30/month in recurring commissions. That's $360 a year — just for sharing something you already love with people you care about.
        </p>
        <p>
          And the key word there is <em>recurring</em>. You don't earn once and forget about it. Every month your referrals stay subscribed, you keep earning. The gift that keeps on giving.
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            The Fine Print (It's Actually Pretty Good)
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-2">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>No minimum referrals:</strong>
                Refer one person or a hundred — you get paid either way
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>Fast payouts:</strong>
                Monthly automatic deposits when you hit $15 (there's a 35-day initial hold to allow for cancellations and refunds)
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>Direct to your bank:</strong> Via Stripe — set up takes minutes
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>Available to all subscribers:</strong>
                If you have an active subscription, you can participate
              </span>
            </div>
          </div>
        </div>

        <hr />
        <h2 id="privacy-first-referrals">
          <a href="#privacy-first-referrals">
            Privacy-first, even here
          </a>
        </h2>
        <p>
          I want to be clear about something: this referral program follows the same privacy principles as everything else we build. Your referral activity is encrypted. We don't use tracking pixels. We don't share data with third parties. We simply record, in our encrypted database, that your friend used your code — and then we pay you.
        </p>
        <p>
          This is what "privacy-first" means in practice. It's not just about the social features — it's about everything we do. Even when money is involved, your privacy comes first.
        </p>

        <hr />
        <h2 id="creating-real-value">
          <a href="#creating-real-value">
            Creating real value for real people
          </a>
        </h2>
        <p>
          At its core, this referral program is about alignment. We grow when people tell other people about us. Those people are creating real value — they're helping families discover a safer, more private way to stay connected. They should be compensated for that value.
        </p>
        <p>
          This is the opposite of surveillance capitalism. Instead of extracting value from you, we're sharing value with you. Instead of making you the product, we're making you a partner.
        </p>
        <p>
          And your friends benefit too — they get 20% off, and they get to use a social network that actually respects them. Everyone wins.
        </p>

        <hr />
        <h2 id="get-started">
          <a href="#get-started">
            Ready to start?
          </a>
        </h2>
        <p>
          If you're already a MOSSLET subscriber, you can find your referral link in your account dashboard. Share it with friends, family, your community — anyone who might appreciate a social network that doesn't spy on them.
        </p>
        <p>
          If you're not yet part of MOSSLET, now is a great time to <a href="/auth/register">join</a>. You'll get access to privacy-first social sharing, and you'll be able to earn while helping us grow a community built on trust rather than surveillance.
        </p>
        <p>
          Thank you for being here. Thank you for believing that social media can be better. And thank you for helping us prove it — one referral at a time.
        </p>
        <p>
          Check out the full details on our <a href="/referrals">referral program page</a>
          and start earning today.
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
       "Blog | Introducing Our Referral Program: Share the Love, Get Paid"
     )
     |> assign_new(:meta_description, fn ->
       "MOSSLET's new referral program pays you real money for sharing privacy-first social media with friends. Earn 30% recurring on subscriptions and 35% on lifetime purchases during beta. No tracking pixels, no data sharing — just honest rewards for honest referrals."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/dec_22_2025_stlgp.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Peaceful hiker in the sunset-colored woods illustration")}
  end
end
