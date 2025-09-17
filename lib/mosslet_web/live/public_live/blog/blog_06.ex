defmodule MossletWeb.PublicLive.Blog.Blog06 do
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
        date="August 19, 2025"
        title="Disappearing Keyboard on Apple iOS Safari"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          For anyone using Apple's iOS Safari browser, you may have noticed that when you tap into a password input field you get an iOS popup to create a password but the onscreen keyboard never appears. This is a known issue from a security update that was released during iOS 13.
        </p>

        <p>
          This is great if you want Apple to create a password for you, and not so great if you want to create your own password with the onscreen keyboard. We have encountered this annoyance when trying to create a new account, so we thought we'd share some options for a quick workaround:
        </p>
        <ul>
          <li>
            Disable "Autofill Passwords" in iOS
          </li>
          <li>
            Use our sparkles (<.phx_icon
              name="hero-sparkles"
              class="inline-flex size-5"
            />) button to generate a secure password and simply copy/paste it into the password confirmation field — just make sure you don't forget it!
          </li>
          <li>
            Use Apple's automated suggestion to create a password and then copy/paste it into the password confirmation field
          </li>
          <li>
            Use a different browser
          </li>
        </ul>
        <p>
          We recommend disabling "Autofill Passwords" in your iOS settings while on MOSSLET, and then using our secure password generator to make one for you. You can learn more about
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.eff.org/dice"
          >
            how we generate passwords
          </a>
          based on the Electronic Frontier Foundation's best practices. ✌️
        </p>

        <hr />
        <h2 id="quick-ios18-workarounds">
          <a href="#quick-ios18-workarounds">
            Quick iOS 18 Workarounds
          </a>
        </h2>
        <p>
          Disabling auto-filling passwords is the easiest way to ensure you have access to your keyboard when using Safari on your mobile phone. To do this on iOS 18 follow these instructions:
        </p>
        <ol>
          <li>
            Open <strong>Settings</strong> on your iOS device
          </li>
          <li>
            Select <strong>General</strong>
          </li>
          <li>
            Select <strong>Autofill & Passwords</strong> (you may have to search or scroll to find it)
          </li>
          <li>
            Toggle off <strong>Autofill Passwords</strong>
          </li>
        </ol>

        <p>
          For other iOS versions we recommend searching "disable autofill passwords in iOS" in <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://duckduckgo.com/"
          >DuckDuckGo</a>.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/aug_19_2025_dkais.jpg"}
              class="w-full"
              alt="iOS Safari keyboard disappearing issue illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@riswanr_/illustrations"
              class="ml-1"
            >
              Riswan Ratta
            </.link>
          </figcaption>
        </div>

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
       "Blog | Disappearing Keyboard on Apple iOS Safari"
     )
     |> assign_new(:meta_description, fn ->
       "Quick workarounds for the disappearing keyboard on Apple iOS Safari. In this 6th blog post, from privacy-first social alternative MOSSLET, we share quick and easy tips for getting your onscreen keyboard back when using Apple iOS Safari."
     end)}
  end
end
