defmodule MossletWeb.PublicLive.Blog.Blog19 do
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
        date="June 24, 2026"
        title="Make Sure It's Really Them: Closing an Authenticity Gap"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          Building Mosslet in the open forces me to ask a lot of uncomfortable questions.
        </p>
        <p>
          Last month we shipped browser-side, post-quantum encryption for everything. Your data is locked down tight. I feel good about it. So this prompted the question — when you share something privately with a friend, how do you actually know the key we handed your browser belongs to your friend, and not an impostor?
        </p>
        <p>
          That question revealed a gap in our architecture. Not a breach or a bug, but a hole that needed to be plugged sooner rather than later.
        </p>
        <p>
          Today I'm happy to share that we've closed that gap, plugged that hole, with a friendly new layer that lets you verify that the people you talk to are really who they say they are.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/jun_24_2026_authenticity.jpg"}
              class="w-full"
              alt="Two people holding matching keys, confirming they belong together."
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@milhad/illustrations"
              class="ml-1"
            >
              Milhad
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="two-questions">
          <a href="#two-questions">
            Encryption doesn't answer every question
          </a>
        </h2>
        <p>
          Strong encryption helps to answer the question: <em>who can read this?</em>
          On Mosslet that answer is you and whoever you choose to share with — not us, not our servers, not someone snooping on the network. Your data is encrypted in your browser before it ever leaves.
        </p>
        <p>
          But there's another question that encryption doesn't help to answer:
          <em>am I sharing this with the right person?</em>
        </p>
        <p>
          When you share something with one of your connections on Mosslet, your browser needs that connection's public key. And to get that key, it has to ask for it from somewhere — in Mosslet's case, that somewhere is Mosslet's server. And while that server is enclosed in our own private, Wireguard encrypted network, it is still technically an attack surface and thus a wrinkle in our end-to-end encryption. If the wrong key ever slipped in, your message would be perfectly encrypted...
          <em>to the wrong recipient.</em>
        </p>
        <p>
          This is a well-known, hard problem in end-to-end encryption and every serious system has to grapple with it. I decided that we needed to name it plainly and address it rather than pretend it didn't exist.
        </p>

        <hr />
        <h2 id="our-server">
          <a href="#our-server">
            A note about Mosslet's server
          </a>
        </h2>
        <p>
          Our server would not substitute someone's key. We have no interest in it, no business model that benefits from it, and our whole architecture is built so we genuinely can't read your content in the first place. Mosslet is open source — you can read exactly what our server does and verify it.
        </p>
        <p>
          And yet "just trust us" is precisely the thing we're trying to make unnecessary. The entire point of zero-knowledge is that your privacy shouldn't depend on our good behavior. So we treat our own server as if it were an adversary, or as if an adversary took over our server, and we give you the tools to check our work.
        </p>

        <hr />
        <h2 id="what-we-built">
          <a href="#what-we-built">
            What we built
          </a>
        </h2>
        <p>
          The new layer has four friendly parts that work quietly in the background until you need them:
        </p>
        <ul>
          <li>
            <strong>Safety numbers</strong>
            — every connection has a short, shared verification code derived from both of your keys. Compare it together over a channel you already trust (in person, a phone call), and a match means you're talking to the real them.
          </li>
          <li>
            <strong>Scan to verify</strong>
            — sitting next to each other? Scan a QR code instead of reading digits aloud. Same guarantee, less squinting (dependent on your device's browser features).
          </li>
          <li>
            <strong>Trust on first use</strong>
            — the first time you connect, your browser remembers that person's key, sealed under your own key so only you can read it. From then on, it watches for changes.
          </li>
          <li>
            <strong>Key-change alerts</strong>
            — if a connection's key ever changes, you'll see a gentle heads-up on and a marker on their connection card, so nothing slips by unnoticed.
          </li>
        </ul>
        <p>
          There's one more quiet safeguard underneath all of this: if a key changes and you haven't re-verified that person, we pause sealing new private content to them until you do. Better to ask than to assume.
        </p>

        <hr />
        <h2 id="the-honest-part">
          <a href="#the-honest-part">
            The honest part
          </a>
        </h2>
        <p>
          When you see a key-change alert, it's worth knowing what it does and doesn't mean. A key can change for a number of innocent reasons: your friend reinstalled the app, set up a new device, or used a recovery key to get back into their account. It could also, in theory, mean something more nefarious; like someone trying to slip a different key in between you. Right now, we can't automatically tell those two cases apart.
        </p>
        <p>
          So instead of guessing for you, we surface the change and hand you a simple, reliable way to settle it: compare safety numbers or scan a QR code with the person directly. If it matches, mark them verified and carry on. If it doesn't, you've caught something worth a closer look. You stay aware and in control.
        </p>

        <hr />
        <h2 id="whats-next">
          <a href="#whats-next">
            Where this goes next
          </a>
        </h2>
        <p>
          This is an interim layer. It's also the standard we want to hold ourselves to: find the gaps before anyone else has to, close them in the open, and tell you about it. The longer-term plan is a tamper-evident, signed history of keys, so that key changes can be checked automatically against a record that can't be quietly rewritten. Until then, you have everything you need to verify the people you care about without taking our word for it.
        </p>
        <p>
          Thanks for being here while we do the work. Go verify a friend — it takes about ten seconds and it feels great.
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
       "Blog | Make Sure It's Really Them: Closing an Authenticity Gap"
     )
     |> assign_new(:meta_description, fn ->
       "Encryption keeps your data unreadable, but how do you know a connection's key really belongs to them? We found and closed that authenticity gap on Mosslet with safety numbers, scan-to-verify, trust-on-first-use, and key-change alerts — and we're honest about what comes next."
     end)
     |> assign(
       :og_image,
       MossletWeb.Endpoint.url() <> ~p"/images/blog/jun_24_2026_authenticity.jpg"
     )
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Two people confirming their keys match")}
  end
end
