defmodule MossletWeb.PublicLive.Blog.Blog14 do
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
        date="January 25, 2026"
        title="MOSSLET Now Connects With Bluesky"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          We've been quietly working on something we're really excited about: MOSSLET now connects with Bluesky! You can import your posts, export your content, and sync your likes and bookmarks between both platforms.
        </p>
        <p>
          Why does this matter? Because we believe you should be able to move freely between the services you use without being locked in. Your content is <em>yours</em>, not ours.
        </p>

        <hr />
        <h2 id="why-bluesky">
          <a href="#why-bluesky">
            Why Bluesky?
          </a>
        </h2>
        <p>
          When we started thinking about which platforms to integrate with first, Bluesky stood out for a few reasons. It's built on an open protocol called AT Protocol, which means it's designed from the ground up for interoperability. You can take your identity and data with you. That's the kind of thinking we can get behind.
        </p>
        <p>
          We're also impressed by Bluesky's commitment to accessibility and language support. They've put real effort into making the platform usable for people across different languages and abilities — something we care deeply about here at MOSSLET too. We're still working toward better language support ourselves, but accessibility is something we've made first-class as well.
        </p>
        <p>
          The open nature of the AT Protocol is what really excites us. It means that even if Bluesky the company makes decisions we disagree with someday, the protocol itself remains open. That's a fundamentally different model than the walled gardens we've grown used to. It's not perfect — no platform is — but the
          <em>architecture</em>
          is pointed in the right direction.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/jan_25_2026_bsky.jpg"}
              class="w-full"
              alt="MOSSLET and Bluesky interoperability illustration. A group of people's arms outstretched in a vertical line from different cultures and ethnicities."
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

        <hr />
        <h2 id="what-you-can-do">
          <a href="#what-you-can-do">
            What you can do
          </a>
        </h2>
        <p>
          Here's what the Bluesky integration lets you do:
        </p>
        <ul>
          <li>
            <strong>Import your Bluesky posts:</strong>
            Bring your existing content into MOSSLET. Your posts, images, and alt text all come over.
          </li>
          <li>
            <strong>Export to Bluesky:</strong>
            Share your public MOSSLET posts on Bluesky with a tap. Images, link previews, and formatting are preserved.
          </li>
          <li>
            <strong>Sync likes and bookmarks:</strong>
            Your saved posts and likes can move between platforms, so you never lose track of content you care about.
          </li>
        </ul>

        <p>
          And here's the part we're most proud of: when you import content from Bluesky, it gets encrypted with your MOSSLET keys before being stored. Even though the original post was public on Bluesky, once it's on MOSSLET, it's protected by the same triple-layer encryption as everything else. You can then choose who gets to see it — including keeping it completely private.
        </p>

        <hr />
        <h2 id="why-interoperability-matters">
          <a href="#why-interoperability-matters">
            Why interoperability matters
          </a>
        </h2>
        <p>
          Let me tell you why this is so important to us.
        </p>
        <p>
          The big platforms — Facebook, Instagram, TikTok, X — they <em>want</em>
          you locked in. They make it easy to import your data and nearly impossible to get it out. Ever tried to download your Instagram photos in a useful format? Good luck. They do this because lock-in keeps you on their platform even when you'd rather leave.
        </p>
        <p>
          That's not how we think about things. We want you to use MOSSLET because it's good, not because you're trapped. And if someday you decide MOSSLET isn't right for you? You should be able to take your stuff and go. No hard feelings.
        </p>
        <p>
          Interoperability is the antidote to lock-in. When platforms can talk to each other, when you can move your content freely, the power shifts back to you. You stop being a captive audience and start being a user who can make real choices.
        </p>

        <hr />
        <h2 id="open-social">
          <a href="#open-social">
            The case for open social
          </a>
        </h2>
        <p>
          There's a growing ecosystem of people building alternatives to Big Tech social media. Bluesky with AT Protocol. Mastodon with ActivityPub. Smaller indie projects doing their own thing. And us, doing ours.
        </p>
        <p>
          We don't see these projects as competition. We see them as allies in a shared mission: proving that social media can exist without surveillance, without manipulation, without treating users as products to be sold to advertisers.
        </p>
        <p>
          The more these platforms can connect and share, the stronger the whole ecosystem becomes. Someone on Bluesky and someone on MOSSLET shouldn't have to choose one or the other. They should be able to use both, together, seamlessly.
        </p>
        <p>
          That's the future we're building toward. This Bluesky integration is our first step.
        </p>

        <hr />
        <h2 id="privacy-first-always">
          <a href="#privacy-first-always">
            Privacy first, always
          </a>
        </h2>
        <p>
          You might be wondering: "If I connect my Bluesky account, are you going to harvest all my data?"
        </p>
        <p>
          Nope. Here's how it works:
        </p>
        <ul>
          <li>
            We use Bluesky's official OAuth flow for authentication — we never see or store your Bluesky password.
          </li>
          <li>
            When you import posts, they get encrypted immediately with your MOSSLET keys before storage.
          </li>
          <li>
            We don't scrape your Bluesky activity in the background. Imports happen when you ask for them.
          </li>
          <li>
            You can disconnect your Bluesky account at any time. When you do, we revoke the connection completely.
          </li>
        </ul>
        <p>
          The connection is a tool for <em>you</em>
          to move your data around, not a backdoor for us to collect more information about you. That would kind of defeat the whole point of what we're doing here.
        </p>

        <hr />
        <h2 id="try-it-out">
          <a href="#try-it-out">
            Try it out
          </a>
        </h2>
        <p>
          If you already have a Bluesky account, you can connect it right now. Head to your Journal settings and look for the Bluesky section. The whole process takes about thirty seconds.
        </p>
        <p>
          Don't have a Bluesky account yet? No problem — you can create one directly from MOSSLET through our OAuth integration. Just start the connection flow and you'll have the option to sign up for a new Bluesky account right there, then authorize MOSSLET immediately after. You can even use a different email than your MOSSLET account if you want to keep that private.
        </p>
        <p>
          And if you're not on MOSSLET yet? Well, there's never been a better time to <a href="/auth/register">join us</a>. Your first 14 days are free, and you can set up Bluesky at the same time.
        </p>
        <p>
          Here's to open social, interoperability, and taking back control of our digital lives. 🦋🌱
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
       "Blog | MOSSLET Now Connects With Bluesky"
     )
     |> assign_new(:meta_description, fn ->
       "MOSSLET now integrates with Bluesky! Import your posts, export content, sync likes and bookmarks, and verify your identity across platforms. We believe in open social and interoperability — your content is yours, not ours."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/jan_25_2026_bsky.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "MOSSLET and Bluesky interoperability illustration")}
  end
end
