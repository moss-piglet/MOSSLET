defmodule MossletWeb.PublicLive.Blog.Blog05 do
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
        date="August 13, 2025"
        title="Companies Selling AI to Geolocate Your Social Media Photos"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          Today we have a disturbing story about the further erosion of our right to privacy, thanks to a surveillance company (and the absence of strong privacy laws) that sells an AI service that can locate objects in your photos. The company specifically markets their service to people who want to locate someone based on a photograph of that person.
        </p>

        <p>
          To get a better idea of what this means, imagine you share a photo on Instagram, Facebook, X, Bluesky, Mastodon, or other social media surveillance platform (even a video on TikTok or YouTube), and in that photo is a harmless object (like a car or a building). But to this company's surveillance algorithm, that harmless object is a clue that can be used to determine your location at the time the photo was taken.
        </p>
        <p>
          404media reveals how the
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.404media.co/lapd-eyes-geospy-an-ai-tool-that-can-geolocate-photos-in-seconds/"
          >
            LAPD is interested in this latest surveillance tool
          </a>
          and how the existence of this spy company, and others like them, puts all of our safety at risk.
        </p>

        <hr />
        <h2 id="photo-invasion">
          <a href="#photo-invasion">
            Photo invasion
          </a>
        </h2>
        <p>
          When you upload a photograph online to share with your friends or family, you have a preconceived notion about the action you are taking and its possible effects on your life (eg. positive boost in connection and nostalgia with no permanent nor negative consequence). Surveillance companies and algorithms like the one mentioned in the article above, subvert this understanding by opening up invisible ways to exploit you and your safety (or that of your friends and family).
        </p>

        <p>
          Instead of simply connecting with a loved one online, you have now given a stranger a Google street view of your home or last known location — which is what the service does. If the street view wasn't enough to locate you, the service also shares the latitude and longitude so that a stranger can quickly pull up turn-by-turn directions to you.
        </p>

        <p>
          As companies and tools like this invade our photographs in order to <em>invade us</em>, the "invisible" dangers of surveillance capitalism start to come into view. It doesn't take much to imagine a disgruntled person, or stalker, using a tool like this to find someone (let alone a disgruntled government or organization).
        </p>

        <p>
          Should we really have to live like Edward Snowden, putting blankets over our heads, to protect ourselves from being located by the background of our selfie?
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/aug_13_2025_augp.jpg"}
              class="w-full"
              alt="AI geolocation surveillance of social media photos illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@setyanski/illustrations"
              class="ml-1"
            >
              Wahyu Setyanto
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="protecting-vs-consuming-privacy">
          <a href="#protecting-vs-consuming-privacy">
            Protecting vs consuming privacy
          </a>
        </h2>

        <p>
          The accuracy of digital spy services, and their AI algorithms, is only possible thanks to surveillance capitalism, which provides the data necessary for them to work (the food) as well as the market in which to sell them (the appetite).
        </p>
        <p>
          We are all living witnesses to the total consumption (annihilation) of our privacy.
        </p>
        <p>
          It reminds me, <em>yet again</em>, of why we're making <a href="/">MOSSLET</a>: everyone deserves to be able to connect and share online without sacrificing their privacy and safety.
        </p>

        <p>
          At MOSSLET <strong>we protect privacy</strong>
          rather than consume it. On MOSSLET you have greater control over your photographs:
        </p>
        <ul>
          <li>
            the entire photo is encrypted (only you and people you choose to share with can decrypt them)
          </li>
          <li>you can control whether or not someone can download your photos</li>
          <li>your photos are never sent outside of our network</li>
          <li>
            when you delete a photo it is immediately and permanently deleted
          </li>
        </ul>
        <p>
          These steps help ensure spy services can't wrap their tentacles around you. It's not perfect protection, you may connect with someone who takes a screenshot of your photograph (which is why you want to consider who you connect with online), but it goes a long way in preventing a lot of the surveillance danger online — and we'll keep working on ways to do even more.
        </p>

        <p>
          Thank you for being here and your interest in the growing movement for simple and ethical software. By reading this, you have already taken a big step toward protecting yourself and your loved ones online. Tell a friend and
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
       "Blog | Companies Selling AI to Geolocate Your Social Media Photos"
     )
     |> assign_new(:meta_description, fn ->
       "Companies selling AI to geolocate your social media photos. In this 5th blog post, from privacy-first social alternative MOSSLET, we share an alarming trend among surveillance and spy companies to offer AI services that can locate you based on your photographs. Then, we discuss how MOSSLET protects your privacy and keeps you safe from these very same spy tools."
     end)}
  end
end
