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
      <%!-- Enhanced liquid metal blog page layout --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/50 via-transparent to-emerald-50/30 dark:from-slate-900/50 dark:via-transparent dark:to-teal-900/20">
        <div class="relative mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 pt-16 pb-24">
          <%!-- Page heading --%>
          <.blog_page_heading />

          <%!-- Blog entries container with liquid styling --%>
          <div class="relative mt-16">
            <%!-- Subtle background pattern --%>
            <div class="absolute inset-0 -z-10 opacity-20">
              <div class="absolute inset-0 bg-gradient-to-br from-teal-50/10 via-transparent to-emerald-50/10 dark:from-teal-900/5 dark:via-transparent dark:to-emerald-900/5">
              </div>
            </div>

            <%!-- Blog entries --%>
            <div class="space-y-8">
              <.blog_entry
                id="blog_10"
                date="December 7, 2025"
                title="How we built surveillance-resistant social media"
                preview="I've been asked a few times now to write about how MOSSLET actually works under the hood. We're open source, so anyone can read the code, but code isn't documentation — and most people don't read Elixir. So here's the technical story of how we built a social network that can't spy on its own people."
                link={~p"/blog/articles/10"}
              />
              <.blog_entry
                id="blog_09"
                date="November 27, 2025"
                title="Unlock Sessions: Privacy Meets Convenience This Holiday Season"
                preview="The autumn leaves are falling and the coziness is here — a time for gathering with loved ones, sharing memories, and yes, spending a bit more time on our devices connecting with friends and family near and far. At MOSSLET, we've been thinking about how to make your experience both secure and convenient this holiday season."
                link={~p"/blog/articles/09"}
              />
              <.blog_entry
                id="blog_08"
                date="November 7, 2025"
                title="Meta Layoffs Included Employees Who Monitored Risks to User Privacy"
                preview="Mark Zuckerberg once said that people who trusted him with their personal information were 'f***ing stupid.' This week's news from Meta proves he was being honest about his company's true priorities — and it's not protecting your privacy."
                link={~p"/blog/articles/08"}
              />
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
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/blog_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Learn about privacy, our company, and our opinions on the latest privacy news"
     )}
  end
end
