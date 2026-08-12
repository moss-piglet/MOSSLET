defmodule MossletWeb.PublicLive.Blog.Blog20 do
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
        date="August 12, 2026"
        title="The Network Jaron Lanier Hoped Someone Would Build"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p class="italic text-emerald-600 dark:text-emerald-400">
          To my knowledge, Jaron Lanier is completely unaware of Mosslet's existence nor has he given an endorsement of our service. This is merely my opinion that I think (hope) he would like Mosslet based on statements he's made in his book and in public appearances. If you are Jaron Lanier, I would love your feedback (or support).
        </p>
        <p>
          Jaron Lanier, the computer scientist who helped popularize the term "virtual reality," wrote a small, sharp book called <span class="italic">Ten Arguments for Deleting Your Social Media Accounts Right Now</span>. People assume it's a rant against connection. It isn't. Lanier is a tech optimist. He loves what networks could be. What he can't stand is the machine most of them are built on.
        </p>
        <p>
          He gave that machine a name. <span class="font-bold">BUMMER</span>, which stands for <span class="font-bold">B</span>ehaviors of <span class="font-bold">U</span>sers <span class="font-bold">M</span>odified, and <span class="font-bold">M</span>ade into an <span class="font-bold">E</span>mpire for <span class="font-bold">R</span>ent. If you're wondering, he has an equally clever and creative acronym for his job title at Microsoft.
        </p>
        <p>
          So how does BUMMER work? Essentially like this: Advertisers rent your attention. For the cost of rent to be worth it for advertisers, the platform has to reliably modify your behavior, <span class="italic">so it does</span>, with feeds and streaks and notifications and outrage. Every harm Lanier describes flows from this single business decision about who the real customer on a platform is, which these companies decided was not you the user, but rather the entity paying to change your behavior for that entity's desired outcome.
        </p>

        <p>
          When I first read the book, I had already made Mosslet and it read like a spec of all the reasons why I had made Mosslet and the choices behind the features we have today.
        </p>
        <p>
          Read on for Jaron Lanier's ten arguments in the context of Mosslet.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/aug_12_2026_trdysn.jpg"}
              class="w-full"
              alt="People enjoying a day in the park with square identifying AI drawn boxes around their heads."
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
        <h2 id="losing-free-will">
          <a href="#losing-free-will">
            <ol class="font-bold">
              <li>"You are losing your freel will".</li>
            </ol>
          </a>
        </h2>
        <p>
          BUMMER platforms are engineered to override your intentions, with infinite scroll, variable-reward notifications, and feeds tuned to keep you there. Mosslet has none of it. There is no algorithmic ranking, no endless scroll, and no dark-pattern nudges. Your timeline has a natural ending, a simple "you're all caught up." Then you go and live your life.
        </p>

        <hr />
        <h2 id="quit-to-resist">
          <a href="#quit-to-resist">
            <ol start={2} class="font-bold">
              <li>"Quitting is the most finely targeted way to resist the insanity of our times."</li>
            </ol>
          </a>
        </h2>
        <p>
          Lanier's point is that you resist BUMMER by starving it of the behavior it sells. But you shouldn't have to give up your friends to do that. Mosslet lets you keep the connection and drop the machine. There are no ads, no advertisers, and no behavior modification. You're the customer, not the inventory. You pay a fair price, and in return we answer to you.
        </p>

        <hr />
        <h2 id="making-you-mean">
          <a href="#making-you-mean">
            <ol start={3} class="font-bold">
              <li>"Social media is making you into an a**hole."</li>
            </ol>
          </a>
        </h2>
        <p>
          Lanier argues that attention-maximizing systems reward the loudest, meanest version of everyone. Mosslet doesn't rank for virality or engagement. There's nothing to game and no dopamine leaderboard for the hottest take. Content warnings and wellbeing controls put you in charge of your own experience. Lanier's own advice was to "go to where you are kindest," and that is the design goal here, not an afterthought.
        </p>

        <hr />
        <h2 id="undermining-truth">
          <a href="#undermining-truth">
            <ol start={4} class="font-bold">
              <li>"Social media is undermining truth."</li>
            </ol>
          </a>
        </h2>
        <p>
          When engagement is the metric, the most inflammatory thing wins, whether it's true or not. On Mosslet nothing is algorithmically amplified to strangers. You decide who sees each post, whether that's just you, your connections, or the public. There is no invisible hand deciding what should go viral today.
        </p>

        <hr />
        <h2 id="words-meaningless">
          <a href="#words-meaningless">
            <ol start={5} class="font-bold">
              <li>"Social media is making what you say meaningless."</li>
            </ol>
          </a>
        </h2>
        <p>
          On BUMMER platforms, context gets applied to your words after you say them, by systems working for someone else's profit. Your sincere post becomes ad-adjacent data. Mosslet is zero-knowledge, which means your words are encrypted in your browser before they ever reach us. We store ciphertext we can't read. No one re-frames, mines, or sells your meaning, because no one can. And because that's not how we make money.
        </p>

        <hr />
        <h2 id="whats-next">
          <a href="#whats-next">
            <ol start={6} class="font-bold">
              <li>"Social media is destroying your capacity for empathy."</li>
            </ol>
          </a>
        </h2>
        <p>
          BUMMER shows you people out of context, as audiences to perform for. Mosslet is built for real circles instead. You get small groups, blind connection requests, gentle "thinking of you" nudges, and shared prompts that start actual conversations rather than comment-section combat.
        </p>

        <hr />
        <h2 id="making-you-unhappy">
          <a href="#making-you-unhappy">
            <ol start={7} class="font-bold">
              <li>"Social media is making you unhappy."</li>
            </ol>
          </a>
        </h2>
        <p>
          The comparison metrics, the anxiety loops, and the fear of missing out are not accidents. They're engagement features. Mosslet is healthy by design. There are no follower-count status games engineered to keep you insecure. You catch up with the people you love and close the tab feeling better, not worse.
        </p>

        <hr />
        <h2 id="no-economic-dignity">
          <a href="#no-economic-dignity">
            <ol start={8} class="font-bold">
              <li>"Social media doesn't want you to have economic dignity."</li>
            </ol>
          </a>
        </h2>
        <p>
          In a humane network, the value you create would flow back to you. Mosslet takes two concrete steps toward that. First, you own your data, with complete export and no lock-in, ever. Second, our referral program actually pays you a residual over the lifetime of your friend's accounts. When was the last time your social network sent you money?
        </p>

        <hr />
        <h2 id="no-politics">
          <a href="#no-politics">
            <ol start={9} class="font-bold">
              <li>"Social media is making politics impossible."</li>
            </ol>
          </a>
        </h2>
        <p>
          Outrage is the most engaging emotion, so BUMMER manufactures it at scale. With no engagement-maximizing feed, Mosslet has no incentive, and no mechanism, to decide you should be furious today. It's just your people, in your own words.
        </p>

        <hr />
        <h2 id="no-soul">
          <a href="#no-soul">
            <ol start={10} class="font-bold">
              <li>"Social media hates your soul."</li>
            </ol>
          </a>
        </h2>
        <p>
          Lanier saves the strangest and truest one for last. The deepest cost, he says, is losing the private space to become yourself, away from the constant judgment of the crowd. Mosslet gives that space back. You get an encrypted journal only you can read, letters to your future self, and a corner of the internet that is genuinely, provably yours.
        </p>

        <hr />
        <h2 id="hope-for-better-future">
          <a href="#hope-for-better-future">
            Mosslet is our hope for a better future
          </a>
        </h2>

        <p>
          Lanier ends his book with a hope, that one day the money behind our networks would be earned a different and more honest way.
        </p>
        <p>
          That hope is the entire reason Moss Piglet Corporation exists. We're a bootstrapped public benefit corporation. No venture capital, no ads, no tracking, no BUMMER. Just software that people pay a fair price for, built to serve them.
        </p>

        <p>
          You don't have to delete social media. You can just use one that was built the way Jaron Lanier hoped someone would build it.
        </p>

        <p>
          <.link navigate={~p"/"}>Try Mosslet <.phx_icon name="hero-arrow-right" /></.link>
        </p>
        <p>
          <.link navigate={~p"/features"}>We have other cool things too
          <.phx_icon name="hero-arrow-right" /></.link>
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
       "Blog | The Network Jaron Lanier Hoped Someone Would Build"
     )
     |> assign_new(:meta_description, fn ->
       "Jaron Lanier, the computer scientist who helped popularize the term \"virtual reality,\" wrote a small, sharp book called Ten Arguments for Deleting Your Social Media Accounts Right Now. People assume it's a rant against connection. It isn't. Lanier is a tech optimist. He loves what networks could be. What he can't stand is the machine most of them are built on."
     end)
     |> assign(
       :og_image,
       MossletWeb.Endpoint.url() <> ~p"/images/blog/aug_12_2026_trdysn.jpg"
     )
     |> assign(:og_image_type, "image/jpeg")
     |> assign(
       :og_image_alt,
       "People enjoying the day in a park with AI identification boxes around their head"
     )}
  end
end
