defmodule MossletWeb.PublicLive.Blog.Blog07 do
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
        date="September 4, 2025"
        title="Smart Doorbells Spying for Insurance Companies"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          Ding Dong! Who is it? Surveillance capitalism! Troubling reports reveal that insurance companies are using smart doorbell footage and other home surveillance devices to deny claims, increase premiums, and monitor homeowners' daily activities without their explicit knowledge or consent.
        </p>

        <p>
          What began as a convenient security device to protect your family, and packages, has morphed into a corporate (and state) surveillance tool that fundamentally changes the relationship between you and your insurance provider. When you install a smart doorbell, you're not just protecting your home — you're potentially giving insurance companies (and authorities) a 24/7 window into your private life.
        </p>
        <p>
          Gadget Review recently published an article detailing how smart doorbells are
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.gadgetreview.com/privacy-nightmare-your-doorbell-camera-is-snitching-to-insurance-companies"
          >
            snitching to insurance companies
          </a>
          to determine homeowner policy rates without your awareness or consent.
        </p>

        <hr />
        <h2 id="surveillance-ringing">
          <a href="#surveillance-ringing">
            Surveillance ringing
          </a>
        </h2>
        <p>
          "But it just shows the outside of my house, who cares?" Despite being pointed away from your home, by analyzing the behavior of your visitors, insurance companies (and others) can determine quite a lot about your private life inside. Let's see how it works in terms of insurance:
        </p>
        <ul>
          <li>
            <strong>Data harvesting:</strong>
            Every visitor, delivery, and daily routine is recorded and analyzed
          </li>
          <li>
            <strong>Insurance partnerships:</strong>
            Companies share footage with insurers who use AI to assess "risk factors" in your behavior
          </li>
          <li>
            <strong>Algorithmic bias:</strong>
            AI systems may flag normal activities as "suspicious" or "high-risk," leading to unfair treatment
          </li>
          <li>
            <strong>Privacy erosion:</strong>
            Your home, once your private sanctuary, becomes a monitored corporate asset
          </li>
        </ul>
        <p>
          The most insidious part? Many homeowners don't realize they've signed away their privacy rights until it's too late — often when filing a claim.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/sept_04_2025_dbsic.jpg"}
              class="w-full"
              alt="Smart doorbells spying for insurance companies illustration"
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
              Tri Wiranto
            </.link>
          </figcaption>
        </div>

        <p>
          Did you have too many parties? Are there frequent visitors? Do you leave packages on your doorstep? All of these normal human behaviors can now be weaponized against you in the form of higher premiums or denied claims.
        </p>

        <hr />
        <h2 id="beyond-doorbells">
          <a href="#beyond-doorbells">
            Beyond doorbells: The expanding web
          </a>
        </h2>

        <p>
          Smart doorbells are just one thread of an expanding web of surveillance. Insurance companies are increasingly interested in all forms of home surveillance and IoT devices:
        </p>
        <ul>
          <li>Smart thermostats that reveal when you're home (among other things)</li>
          <li>Security cameras that monitor your daily routines</li>
          <li>Smart locks that track who enters and leaves</li>
          <li>Water sensors and smoke detectors that report maintenance issues</li>
          <li>Connected appliances that reveal usage patterns</li>
        </ul>
        <p>
          Each device represents another data point in an insurance company's risk assessment algorithm, and another way for them to justify raising your rates or denying coverage.
        </p>
        <p>
          These devices could simply be used to provide convenience, security, and support to our life. We already pay once for them at checkout, why do we have to continue to pay with our behavioral data and privacy? Companies could sell a great product to us and let that be it! Why do they have to commoditize our humanity along with it?
        </p>

        <hr />
        <h2 id="protecting-your-home-privacy">
          <a href="#protecting-your-home-privacy">
            Protecting your home privacy
          </a>
        </h2>
        <p>
          While the surveillance web is expanding, you still have options to protect your privacy:
        </p>
        <ul>
          <li>
            <strong>Read the fine print:</strong>
            Understand what data your devices collect and who they share it with
          </li>
          <li>
            <strong>Choose local storage:</strong>
            Use security systems that store footage locally rather than in the cloud
          </li>
          <li>
            <strong>Limit connectivity:</strong>
            Use devices that don't require internet connections for basic functionality
          </li>
          <li>
            <strong>Review insurance policies:</strong>
            Understand how your insurer uses surveillance data in claims decisions
          </li>
          <li>
            <strong>Consider alternatives:</strong>
            Traditional security measures like good lighting and sturdy locks are often just as effective
          </li>
        </ul>

        <p>
          The rise of smart home surveillance represents a fundamental shift in the balance of power between individuals and corporations. What was once your private domain is increasingly becoming corporate territory, monitored and analyzed for profit.
        </p>

        <p>
          And it doesn't just affect you — it impacts your neighbors, visitors, delivery workers, and anyone who steps within range of these devices. Buying a smart doorbell (eg. Nest, Ring, et al) helps companies create surveillance neighborhoods, where privacy becomes a luxury no one on the street can afford.
        </p>

        <p>
          At <a href="/">MOSSLET</a>, we believe your home should remain your sanctuary. That's why we're committed to building privacy-first services that put you in control, not the other way around. Your private moments should remain private, whether they happen at home or on social media.
        </p>

        <p>
          Thank you for being here and your interest in the growing movement for simple and ethical software. Tell a friend and
          <a href="/auth/register">
            switch to MOSSLET
          </a>
          today to start getting the privacy and protection you deserve.
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
       "Blog | Smart Doorbells Spying for Insurance Companies"
     )
     |> assign_new(:meta_description, fn ->
       "Smart doorbells are spying for insurance companies. In this 7th blog post from privacy-first social alternative MOSSLET, we explore how insurance companies are using smart doorbell footage and home surveillance devices to monitor homeowners, deny claims, and increase premiums without explicit consent."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/sept_04_2025_dbsic.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Smart doorbells spying for insurance companies illustration")}
  end
end
