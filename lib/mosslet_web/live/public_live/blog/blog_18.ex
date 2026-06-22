defmodule MossletWeb.PublicLive.Blog.Blog18 do
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
        date="June 22, 2026"
        title="Bring Your People With You: Family and Business Plans Are Here"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          Sharing privacy? Feels like an oxymoron, but that's exactly what I'm excited to introduce today; two new ways to bring the people you love and trust onto Mosslet with our Family and Business plans. Both run on the same zero-knowledge, post-quantum encryption that protects everything else here, which means we still can't read your data, and now neither can anyone snooping on the people you care about.
        </p>
        <p>
          Best of all, you don't have to give anything up. Even though we recommend ditching Big Tech, we know that it can be hard. Which is why you can simply augment your existing tech stack with Mosslet — the calm, private space you add on top, for the conversations and files that deserve real protection.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/jun_22_2026_bypwyfb.jpg"}
              class="w-full"
              alt="A family and a small team gathered together in a calm, private space."
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@gettyimages/illustrations"
              class="ml-1"
            >
              Getty Images
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="family">
          <a href="#family">
            Stay close as a family, without the surveillance
          </a>
        </h2>
        <p>
          Most "family" features on other platforms are really just monitoring with a makeover. We built the opposite. Mosslet Family runs on consent based guardianship with no master key. A guardian can only co-read a member's content after that member says "yes" and every managed member always sees exactly who can read what. Additionally, either side can hit "pause" on sharing any future content whenever they want.
        </p>
        <p>
          It might take some coordination but we think getting family's talking again is a good thing. And that's why you'd bring yours to Mosslet. It's a warm, private space for the people closest to you, and it works happily alongside whatever your family already uses to stay in touch.
        </p>
        <p>
          Family is $20/month or $160/year (save 33%), includes 5 members, and you can add seats for $3/month each. It comes with a shared, end to end encrypted family circle, a 14 day free trial, and a 30 day money back guarantee. You can read more on the <.link navigate={
            ~p"/family-plan"
          }>Family plan page</.link>.
        </p>

        <hr />
        <h2 id="business">
          <a href="#business">
            Give your team a private place to work
          </a>
        </h2>
        <p>
          Mosslet Business gives your organization private, org-scoped circles, so only the people you add can see a circle's files and conversations. File sharing is fully zero-knowledge: files are encrypted in your browser before they upload, and our servers only ever hold encrypted blobs.
        </p>
        <p>
          You also get a zero-knowledge admin audit log, a clear append-only record of who did what, without exposing anyone's private content, plus simple per-seat billing and an optional branding add-on for a custom subdomain.
        </p>
        <p>
          Already have Slack? That's great, use Mosslet Business right alongside it for the work that should stay between your team — you can even pin the link to your Slack or Notion in your org dashboard so everyone teammates can easily navigate your company's most important digital spaces.
        </p>
        <p>
          Business is $100/month or $800/year (save 33%), includes 10 members, with extra seats at $5/month each, and it scales to 200. Same 14 day free trial and 30 day money back guarantee. See the details on the <.link navigate={
            ~p"/business-plan"
          }>Business plan page</.link>.
        </p>

        <hr />
        <h2 id="the-idea">
          <a href="#the-idea">
            The whole idea
          </a>
        </h2>
        <p>
          You shouldn't have to choose between staying connected and staying private. Family and Business let you keep everything you already love, and add a space where the people you trust are protected by math and code, not promises. No ads, no data mining, no one reading over your shoulder.
        </p>
        <p>
          I'd love for you to try it. Take a look at our <.link navigate={~p"/pricing"}>pricing</.link>, pick the plan that fits, and bring your people with you.
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
       "Blog | Bring Your People With You: Family and Business Plans Are Here"
     )
     |> assign_new(:meta_description, fn ->
       "Introducing Mosslet Family and Business plans, built on the same zero-knowledge, post-quantum encryption that protects everything on Mosslet. Family uses consent-based guardianship with no master key. Business gives teams private circles and zero-knowledge file sharing. Add them alongside the tools you already use."
     end)
     |> assign(
       :og_image,
       MossletWeb.Endpoint.url() <> ~p"/images/blog/jun_22_2026_bypwyfb.jpg"
     )
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Mosslet Family and Business plans announcement")}
  end
end
