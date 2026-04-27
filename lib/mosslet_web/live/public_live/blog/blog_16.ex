defmodule MossletWeb.PublicLive.Blog.Blog16 do
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
        date="April 27, 2026"
        title="The Floor Is Collapsing"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p class="italic">
          Each of these stories felt like a separate problem. They're not.
        </p>
        <p>
          Over the past year and a half, I've been writing about individual privacy stories on this blog. <a href={
            ~p"/blog/articles/08"
          }>Meta gutting its privacy teams</a>. <a href={~p"/blog/articles/07"}>Smart doorbells spying for insurance companies</a>. <a href={
            ~p"/blog/articles/03"
          }>Airlines selling passenger data to Homeland Security</a>. <a href={~p"/blog/articles/02"}>AI algorithms deciding which families to surveil</a>. <a href={
            ~p"/blog/articles/01"
          }>The government abandoning rules that would have shielded us from data brokers</a>.
        </p>
        <p>
          Each time, I wrote about them as separate events. They're not. They're one story.
        </p>
        <p>
          And it's accelerating.
        </p>

        <hr />
        <h2 id="what-happened">
          <a href="#what-happened">
            What's happened since we last talked
          </a>
        </h2>
        <p>
          In late March, the FTC took action against OkCupid and its parent company Match Group — the company behind Tinder, Hinge, and Match.com — for secretly sharing nearly three million user photos, along with location and demographic data, with a facial recognition company called Clarifai. The kicker? OkCupid's founders were personally invested in Clarifai. They handed over the data as a favor. No contract. No restrictions on how it could be used. No notice to users. And then they spent over a decade trying to cover it up — including attempting to obstruct the FTC's own investigation.
        </p>
        <p>
          OkCupid's privacy policy at the time told users their data would not be shared "except as indicated in this Privacy Policy or when we inform you and give you an opportunity to opt out." Clarifai was not a service provider, not a business partner, not a corporate affiliate. Users were never informed. They were never given the chance to opt out. Their photos were just... given away. To train facial recognition.
        </p>
        <p>
          Meanwhile, Tinder — also owned by Match Group —
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://cybernews.com/privacy/tinders-artificial-intelligence-scans-camera-roll/"
          >
            rolled out a new feature in March
          </a>
          that uses AI to scan your entire camera roll. They call it "Photo Insights." It analyzes every photo on your phone to determine your "vibe" — your interests, personality, lifestyle. One tech commentator put it well: "'Vibe analysis' is the friendliest possible name for training a behavioral model on your private photos."
        </p>
        <p>
          Tinder says it's optional. They say select photos are "temporarily uploaded" to their servers. They say photos you don't keep "are deleted within 90 days and may be analyzed to help us improve the Photo Insights feature." Read that last part again. They delete your photos, but not before using them to improve their system. And this is the same company that just settled with the FTC for secretly funneling user photos to a facial recognition startup.
        </p>
        <p>
          Then there's the Ring doorbell saga. Amazon aired a Super Bowl ad for Ring's new "Search Party" feature — pitched as a way to find lost dogs using your neighborhood camera network. The backlash was immediate. People saw through the framing: what tracks a dog can track a person. Around the same time, the FBI revealed that in the <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.theverge.com/tech/877235/nancy-guthrie-google-nest-cam-video-storage"
          >Nancy Guthrie kidnapping case</a>, investigators recovered footage from a Nest doorbell camera using "residual data located in backend systems" — footage the user no longer had access to and that should have been gone. The camera had been forcibly removed, the subscription was inactive, and the clips had expired. Google's engineers still pulled them back.
        </p>
        <p>
          Ring had also been exploring a partnership with Flock Safety, a company whose AI-powered license plate readers are used by law enforcement across more than 6,000 communities. ICE has been tapping that data through requests to local police. Ring eventually cancelled the partnership after public pressure, but the architecture is already built. The sensor network exists. It's in neighborhoods across the country. It's privately owned, and it's available.
        </p>
        <p>
          And just last week, two new data privacy bills were introduced in Congress — the SECURE Data Act and the GUARD Financial Data Act — that would preempt privacy laws in more than twenty states to create a single national standard. Sounds reasonable until you notice what's missing: neither bill would allow people to sue companies over privacy violations. Privacy advocates have already raised alarms that the bills fall short in addressing real-world consequences, particularly for people facing heightened risks.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/apr_27_2026_tfic.jpg"}
              class="w-full"
              alt="Person falling through the floor with social icons around them."
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
        <h2 id="connecting-the-dots">
          <a href="#connecting-the-dots">
            Connecting the dots
          </a>
        </h2>
        <p>
          Here's what I see when I step back:
        </p>
        <p>
          <strong>
            The companies collecting your data are the same companies losing it, sharing it, and lying about it.
          </strong>
          Match Group promised privacy and handed photos to a facial recognition firm. <a href={
            ~p"/blog/articles/07"
          }>Ring promised security and built a surveillance network accessible to law enforcement</a>. Data brokers promise anonymity and <a href={
            ~p"/blog/articles/05"
          }>sell coordinates that can identify soldiers visiting nuclear vaults</a>.
        </p>
        <p>
          <strong>Opt-in" is becoming the new "trust me."</strong>
          Tinder says the camera roll scan is optional. Ring says video sharing is your choice. Google says you can opt in to having Gmail data extracted for ad targeting. But the products are designed to nudge you toward consent, and the fine print always includes a clause that lets them use your data to "improve" their services. Opting out means losing functionality. Opting in means surrendering something you can't take back.
        </p>
        <p>
          <strong>The government isn't protecting you — it's a customer.</strong>
          DHS received over $100 billion in yearly funding through the 2025 spending law. ICE is tapping commercial surveillance networks. The government purchases data from brokers specifically because it's not subject to the same restrictions as information it collects directly. And the CFPB, as <a href={
            ~p"/blog/articles/01"
          }>I wrote about last year</a>, withdrew its own proposal to regulate the data broker industry. The entity that was supposed to protect us quietly stood down.
        </p>
        <p>
          <strong>AI is making all of this worse, faster.</strong>
          Every data point that used to sit in a database now gets processed, cross-referenced, and analyzed at machine speed. A Harvard study published this spring found that surveillance capitalism is extending beyond big tech into industries like oil and gas, luxury goods, and consumer products. Companies like Nvidia, Salesforce, Snowflake, LiveRamp, and Palantir are building the invisible infrastructure that makes it possible. The researchers call them the "dark horses of surveillance capitalism" — they're less famous than Google or Meta, but they're expanding the system.
        </p>
        <p>
          And here's the thing that should bother you the most:
          <strong>the people who understand this are getting younger, and they're furious.</strong>
          A survey by the Friedrich Naumann Foundation of over five thousand Gen Z voters across five countries found that 88.8% ranked "the right to privacy" as the most important of ten human rights — above freedom of assembly, freedom of opinion, and free and fair elections. Shoshana Zuboff, whose work on surveillance capitalism shaped the thinking behind Mosslet, called this the most surprising result she's ever seen. These young people grew up inside the surveillance machine, and they want out.
        </p>

        <hr />
        <h2 id="where-is-this-heading">
          <a href="#where-is-this-heading">
            Where this is heading
          </a>
        </h2>
        <p>
          There's a pattern to how this plays out, and it's worth naming because we're living through it.
        </p>
        <p>
          <strong>The first phase is extraction.</strong>
          Companies build systems designed to harvest as much behavioral data from you as possible — what you click, where you go, who you talk to, what you look at, how long you hesitate. This is surveillance capitalism as Zuboff described it, and at this point it's so deeply embedded in the economy that most people have stopped noticing.
        </p>
        <p>
          <strong>The second phase is</strong>
          what happens when extraction reaches scale: the information environment itself starts to break down. When every platform is optimized to capture attention, the incentive is engagement — not truth. Algorithmic feeds amplify outrage. Micro-targeting fragments shared reality. Deepfakes erode the ability to trust what you see. Nobody can agree on what's real because the infrastructure wasn't designed to deliver reality — it was designed to deliver engagement. This is
          <strong>epistemic chaos.</strong>
          It's not a side effect. It's a direct consequence of the extraction model. And it's where we are right now.
        </p>
        <p>
          <strong>The third phase is the one that should keep you up at night.</strong>
          Once the chaos is deep enough — once people are exhausted, confused, unable to tell what's true — the same institutions and companies that created the mess start offering themselves as the solution. Let the algorithm sort it out. Let the platform decide what's trustworthy. Let the system score who's a risk and who's safe. Hand over more data so we can protect you from the chaos that we made.
        </p>
        <p>
          This is <strong>algorithmic governance</strong>. Total control, offered as a service. And the floor collapsing — the removal of guardrails, the gutting of regulatory agencies, the normalization of corporate surveillance — isn't a failure of the system. It's the transition between phase two and phase three. The chaos isn't a bug. It's the sales pitch.
        </p>
        <p>
          Every story I've covered on this blog fits somewhere on this trajectory. The <a href={
            ~p"/blog/articles/01"
          }>data brokers extracting everything they can</a>. The platforms optimizing for engagement over truth. The
          <a href={~p"/blog/articles/03"}>government purchasing surveillance data</a>
          instead of regulating it. The new privacy bills that look like protection but strip away your ability to fight back. The <a href={
            ~p"/blog/articles/02"
          }>AI systems that promise to make sense of a world that was deliberately made senseless</a>.
        </p>
        <p>
          This is the floor that's collapsing. Not just individual privacy protections — the entire assumption that someone, somewhere, is keeping the system accountable.
        </p>

        <hr />
        <h2 id="why-this-matters-to-us">
          <a href="#why-this-matters-to-us">
            Why this matters to us
          </a>
        </h2>
        <p>
          I started building Mosslet because I had a hunch about where all of this was heading. That hunch has a name now — surveillance capitalism — and the floor underneath it is collapsing faster than even the pessimists predicted.
        </p>

        <p>
          The point of Mosslet was never to be the anti-Facebook. It was to ask a simple question:
          <a href={~p"/blog/articles/10"}>
            what would it look like if a social network couldn't spy on its own people?
          </a>
          What if your messages were encrypted before they left your device? What if your photos were only visible to the people you chose to share them with? What if deleting something actually deleted it?
        </p>

        <p>
          That question felt theoretical when I started. It feels urgent now.
        </p>

        <p>
          And it's not just about privacy for privacy's sake. When your tools are encrypted and open source, when the architecture is zero-knowledge, when no algorithm is deciding what you see or nudging you toward engagement — you're outside the system I just described. You're not feeding the extraction. You're not participating in the chaos. And you're not handing anyone the leverage to govern you through your own data.
        </p>
        <p>
          That's the point. Not just to protect your messages. To protect your autonomy.
        </p>

        <hr />
        <h2 id="the-bigger-picture">
          <a href="#the-bigger-picture">
            The bigger picture
          </a>
        </h2>
        <p>
          Here's what frustrates me about the current state of messaging. Billions of people use apps like Instagram DMs, Facebook Messenger, and WhatsApp every day. These platforms have the resources to build the most secure messaging systems in the world. And yet they keep finding reasons not to.
        </p>
        <p>
          Instagram's decision to remove default encryption from their DMs is particularly telling. They framed it as protecting kids. But what they built is a system where Meta employees and law enforcement (and others?) can read your private conversations. Is that really safer? Or is it just a different kind of surveillance dressed up as care?
        </p>
        <p>
          We think the answer is obvious: <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.schneier.com/essays/archives/2016/04/the_value_of_encrypt.html"
          >encryption (privacy) keeps you safe</a>. Real safety is systemic and comes from caring about safety and then giving people the tools to protect themselves — blocking, reporting,
          <a href={~p"/blog/articles/15"}>image safety checks</a>
          — not from having a corporation read your private thoughts (Instagram was harming kids long before they added end-to-end encryption to their DMs).
        </p>
        <p>
          And let's not forget the business model at play. Meta makes money by understanding you as deeply as possible. Every unencrypted message is another data point, another signal for their advertising machine. When they argue against encryption, they're not just arguing for safety — they're arguing for access to your most intimate digital conversations.
        </p>

        <hr />
        <h2 id="open-source">
          <a href="#open-source">
            Don't take our word for it
          </a>
        </h2>
        <p>
          Everything we've described here is verifiable. MOSSLET is <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/MOSSLET"
          >open source</a>. You can read the encryption code yourself. You can see exactly how conversation keys are generated, how messages are encrypted, how the image safety pipeline works. No trust required — just math.
        </p>
        <p>
          That's the standard we think every platform should be held to. If a company tells you your messages are private, they should be able to show you the code that proves it. If they can't — or won't — ask yourself why.
        </p>

        <hr />
        <h2 id="what-you-can-do">
          <a href="#what-you-can-do">
            What you can do
          </a>
        </h2>
        <p>
          You've heard me say this before, but it bears repeating — especially now:
        </p>
        <ol>
          <li>
            <strong>Write to your congressional representatives.</strong>
            Two new data privacy bills are in Congress right now. They could set the standard for the next decade. Tell your representatives that a national privacy law without a private right of action isn't a privacy law — it's a permission slip. Try
            <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://5calls.org/"
            >
              5calls.org
            </a>
            to find your reps.
          </li>
          <li>
            <strong>Audit your own tools.</strong>
            Check your Ring settings — Consumer Reports published a guide this month on how to turn off Search Party, Community Requests, and other sharing features that are on by default. Check what permissions your dating apps have. Check what your smart TV is tracking.
          </li>
          <li>
            <strong>Move to services that can't betray your trust.</strong>
            Not because they promise not to, but because they're technically unable to. That's the difference between a privacy policy and actual encryption. On <a href={
              ~p"/"
            }>Mosslet</a>, we can't read your messages or see your photos — not because we're good people (though we try), but because the architecture doesn't allow it. It's open source. You can verify that yourself.
          </li>
          <li>
            <strong>Talk about it.</strong>
            The 88.8% of Gen Z voters who ranked privacy as the most important human right didn't learn that from a blog post. They learned it from living inside the machine. If you're reading this, you probably already understand what's happening. Share that understanding with the people around you.
          </li>
        </ol>
        <p>
          The floor is collapsing. But we can build something better on different ground.
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
       "Blog | The Floor Is Collapsing"
     )
     |> assign_new(:meta_description, fn ->
       "Over the past year, we've covered airlines selling data, doorbells spying for insurers, data brokers tracking soldiers, and governments stepping aside. They're not separate stories — they're one system. And the floor beneath it is collapsing."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/apr_27_2026_tfic.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Person falling through the floor with social icons around them")}
  end
end
