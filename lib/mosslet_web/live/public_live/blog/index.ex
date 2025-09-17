defmodule MossletWeb.PublicLive.Blog.Index do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.PublicLive.Blog.Components

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:about}
      container_max_width={@max_width}
      key={@key}
    >
      <div class="max-w-screen overflow-x-hidden">
        <div class="grid min-h-dvh grid-cols-1 grid-rows-[1fr_1px_auto_1px_auto] justify-center pt-14.25 [--gutter-width:2.5rem] lg:grid-cols-[var(--gutter-width)_minmax(0,var(--breakpoint-2xl))_var(--gutter-width)]">
          <div class="col-start-1 row-span-full row-start-1 hidden lg:block"></div>
          <div class="text-gray-950 dark:text-white">
            <div class="relative mx-auto mt-24 max-lg:max-w-2xl">
              <.blog_page_heading />
              <%!--
              <.blog_newsletter_signup />
              --%>
              <div class="mt-12 mb-46 grid grid-cols-1 lg:grid-cols-[24rem_2.5rem_minmax(0,1fr)]">
                <.blog_entry
                  id="blog_07"
                  date="September 4, 2025"
                  title="Smart Doorbells Spying for Insurance Companies"
                  preview="What began as a convenient security device to protect your family, and packages, has morphed into a corporate (and state) surveillance tool that fundamentally changes the relationship between you and your insurance provider. When you install a smart doorbell, you're not just protecting your home — you're potentially giving insurance companies (and authorities) a 24/7 window into your private life."
                  link={~p"/blog/articles/07"}
                />

                <.blog_entry
                  id="blog_06"
                  date="August 19, 2025"
                  title="Disappearing Keyboard on Apple iOS Safari"
                  preview="This is great if you want Apple to create a password for you, and not so great if you want to create your own password with the onscreen keyboard. We have encountered this annoyance when trying to create a new account, so we thought we'd share some options for a quick workaround:"
                  link={~p"/blog/articles/06"}
                />

                <.blog_entry
                  id="blog_05"
                  date="August 13, 2025"
                  title="Companies Selling AI to Geolocate Your Social Media Photos"
                  preview="To get a better idea of what this means, imagine you share a photo on Instagram, Facebook, X, Bluesky, Mastodon, or other social media surveillance platform (even a video on TikTok or YouTube), and in that photo is a harmless object (like a car or a building). But to this company's surveillance algorithm, that harmless object is a clue that can be used to determine your location at the time the photo was taken."
                  link={~p"/blog/articles/05"}
                />

                <.blog_entry
                  id="blog_04"
                  date="June 26, 2025"
                  title="How MOSSLET Keeps You Safe"
                  preview="Someone requesting to connect with you online shouldn't be more important to whatever you are doing in real life. But that's exactly what is happening on these Big Tech services, our brains are being rewired to prioritize responding to an online notification over our real life interactions. It's not our fault, these systems are designed to hijack our biology and shift our behavior — and its killing us."
                  link={~p"/blog/articles/04"}
                />

                <.blog_entry
                  id="blog_03"
                  date="June 10, 2025"
                  title="Major Airlines Sold Your Data to Homeland Security"
                  preview="If flying on a major airline wasn't trouble enough, with increasing prices and crashes (due to faulty Boeing airplanes and understaffed and outdated air traffic control systems), the airlines have also been secretly selling passenger data to the Department of Homeland Security."
                  link={~p"/blog/articles/03"}
                />

                <.blog_entry
                  id="blog_02"
                  date="May 20, 2025"
                  title="AI Algorithm Deciding Which Families Are Under Watch For Child Abuse"
                  preview="Which brings us to this unsettling report from the Markup about an artificial intelligence system that is being used to decide which families are more likely to harm their children, and as you can imagine, the system is filled with prejudice."
                  link={~p"/blog/articles/02"}
                />

                <.blog_entry
                  id="blog01"
                  date="May 14, 2025"
                  title="U.S. Government Abandons Rule to Shield Consumers from Data Brokers"
                  preview="Today, I learned that the Consumer Financial Protection Bureau (CFPB) quietly withdrew its own proposal to protect Americans from the data broker industry. Its original rule was proposed last December under former director Rohit Chopra and would have gone a long way in shielding us from the indiscriminate sharing of our personal information — like social security numbers, addresses, phone numbers, you name it."
                  link={~p"/blog/articles/01"}
                />
              </div>
            </div>
          </div>
          <div class="row-span-full row-start-1 hidden lg:col-start-3 lg:block"></div>
        </div>
      </div>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(
       :page_title,
       "Blog"
     )
     |> assign_new(:meta_description, fn ->
       "MOSSLET updates from our blog. Learn about privacy, our company, and our opinions on the latest privacy news."
     end)}
  end
end
