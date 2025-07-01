defmodule MossletWeb.PublicLive.Blog.Blog04 do
  @moduledoc false
  use MossletWeb, :live_view

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      user={assigns[:user]}
      current_page={:blog}
      container_max_width={@max_width}
      key={@key}
    >
      <MossletWeb.Components.LandingPage.beta_banner />
      <div class="max-w-screen overflow-x-hidden">
        <div class="grid min-h-dvh grid-cols-1 grid-rows-[1fr_1px_auto_1px_auto] justify-center pt-14.25 [--gutter-width:2.5rem] lg:grid-cols-[var(--gutter-width)_minmax(0,var(--breakpoint-2xl))_var(--gutter-width)]">
          <div class="col-start-1 row-span-full row-start-1 hidden lg:block"></div>
          <div class="text-gray-950 dark:text-white">
            <div hidden=""></div>
            <div class="grid grid-cols-1 xl:grid-cols-[22rem_2.5rem_auto] xl:grid-rows-[1fr_auto]">
              <div class="col-start-2 row-span-2 max-xl:hidden"></div>
              <div class="max-xl:mx-auto max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="mt-16 px-4 text-sm/7 font-medium tracking-widest text-gray-500 dark:text-gray-400 uppercase lg:px-2">
                  <time datetime="2025-05-14T19:00:00.000Z">June 26, 2025</time>
                </div>
                <div class="mb-6 px-4 lg:px-2 xl:mb-16 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <h1 class="inline-block max-w-(--breakpoint-md) text-[2.5rem]/10 font-bold tracking-tight text-pretty text-gray-950 lg:text-6xl dark:text-gray-200">
                    How MOSSLET Keeps You Safe
                  </h1>
                </div>
              </div>
              <div class="max-xl:mx-auto max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="flex flex-col gap-4">
                  <div class="flex items-center px-4 py-2 font-medium whitespace-nowrap max-xl:before:-left-[100vw]! max-xl:after:-left-[100vw]! xl:px-2 xl:before:hidden relative before:absolute before:top-0 before:h-px before:w-[200vw] before:right-0 after:absolute after:bottom-0 after:h-px after:w-[200vw] after:right-0">
                    <div class="flex gap-4">
                      <img
                        alt=""
                        loading="lazy"
                        width="36"
                        height="36"
                        decoding="async"
                        data-nimg="1"
                        class="size-12 rounded-full"
                        src={~p"/images/about/mark_photo.jpg"}
                        style="color: transparent;"
                      />
                      <div class="flex flex-col justify-center gap-1 text-sm font-semibold">
                        <div class="text-gray-950 dark:text-white">Mark Thayer</div>
                        <div>
                          <.link
                            navigate={~p"/"}
                            class="text-emerald-500 hover:text-emerald-600 dark:text-emerald-400"
                          >
                            MOSSLET
                          </.link>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div class="max-xl:mx-auto max-xl:mt-16 max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="px-4 py-2 lg:px-2 relative before:absolute before:top-0 before:h-px before:w-[200vw]  before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <article class="prose prose-blog max-w-(--breakpoint-md) dark:text-gray-400">
                    <p>
                      Woohoo! Finally, an article that's not doom and gloom.
                    </p>

                    <p>
                      We're going to fly around and take a peak at some of the ways we keep you safe online. Essentially this is what we do on MOSSLET to keep you (and your data) safe:
                      <ol>
                        <li>
                          Attention freeing
                        </li>
                        <li>
                          Comprehensive control
                        </li>
                        <li>
                          Intimate privacy protection
                        </li>
                        <li>
                          Triple layer encryption
                        </li>
                        <li>
                          Zero dark patterns
                        </li>
                      </ol>
                      Perhaps most importantly, you don't have to simply take our word for it, you can check everything yourself with our <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://github.com/moss-piglet/MOSSLET"
                        class="dark:text-gray-200"
                      >open source code base</.link>. ✌️
                    </p>

                    <p>
                      When I first started thinking about making MOSSLET, I was overwhelmed by the sheer scope of invasion happening on the internet. The NSA receives almost
                      <em>every</em>
                      bit of data that flows across the internet by siphoning it out of transit and into their storage facilities (for later analysis and inspection). That's just the start of the surveillance apparatus online. Look at Kate Crawford's award-winning installation
                      <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://calculatingempires.net/"
                        class="dark:text-gray-200"
                      >
                        calculating empires
                      </.link>
                      for a visualization of the machine.
                    </p>

                    <p>
                      This led me to the conclusion that the first step in protecting people on MOSSLET was to ensure that their data was <em>encrypted</em>. I couldn't prevent an organization like the NSA from obtaining your data without your permission, but I could make it incredibly difficult (if not impossible) for them to understand it. With encryption in place, I could then focus on designing our service to keep people in control and avoid manipulative design techniques that could negatively impact you.
                    </p>

                    <p>
                      That was my goal when I was first getting started, and it remains the goal today. When you sign on to MOSSLET my hope is that you will instantly notice the
                      <em>absence</em>
                      of things you may have grown accustom to on other platforms. We don't have anything fighting for your attention and nudging you to action. You will most likely feel bored and think something like, <em>what do I do?</em>, because it's now up to you.
                    </p>

                    <p>
                      In time, as you only use MOSSLET to connect and share with your friends online, you should discover that you have more time, attention, and energy for the rest of your life. You will start to feel free because you will be. And supporting all of that freedom are these areas we focus on:
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="who-is-the-arc">
                      <a href="#who-is-the-arc" class="anchor dark:text-gray-200">
                        Attention freeing
                      </a>
                    </h2>
                    <p>
                      This is the <em>opposite</em>
                      of surveillance logic. Almost every website today, and certainly every social app/platform/service you're used to, is designed to steal your attention away from you. They want to keep your eyeballs for as long as possible because every second of attention that they have they are monetizing.
                    </p>
                    <p>
                      On MOSSLET we want you to give your attention to your life, not us. We believe the current attention-stealing practices online are profoundly harmful to people and our communities. When a parent can't look up from their device while their child is talking to them, <em>something is wrong</em>.
                    </p>

                    <p>
                      So we intentionally design MOSSLET to <em>free</em>
                      your attention. That means you won't see any red notifications that trick your brain into responding. You won't see any notifications, period. When someone sends you a request to connect, you won't know unless you happen to be on your Connections page and notice the little button that appears saying "You've got Connections".
                    </p>

                    <p>
                      Someone requesting to connect with you online shouldn't be more important to whatever you are doing in real life.
                      It's crazy what we're doing — we're shifting your priority away from our service and back to your life. We think it's peaceful that way.
                    </p>

                    <div data-media="true">
                      <div class="not-prose relative overflow-hidden rounded-xl">
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
                        </div>
                        <img src={~p"/images/blog/june_26_2025_mkys.jpg"} />
                      </div>
                      <figcaption class="flex justify-end">
                        artwork by
                        <.link
                          target="_blank"
                          rel="noopener noreferrer"
                          href="https://unsplash.com/@inipagi/illustrations"
                          class="ml-1 dark:text-gray-200"
                        >
                          Rizki Kurniawan
                        </.link>
                      </figcaption>
                    </div>

                    <hr class="dark:border-gray-700" />
                    <h2 id="loophole-for-surveillance">
                      <a href="#loophole-for-surveillance" class="anchor dark:text-gray-200">
                        Comprehensive control
                      </a>
                    </h2>

                    <p>
                      Another radical idea of ours, apparently. Let's look at Facebook or Instagram as an example: they have pages and pages of settings that you can fiddle with to give you the <em>impression of control</em>. But that's all it is, an impression. Because we are constantly discovering that services (whether it's Google's Chrome browser or Instagram) are blatantly ignoring your settings to continue surveilling you.
                    </p>
                    <p>
                      Not us.
                    </p>
                    <p>
                      Here you have the ability to <em>actually</em>
                      control your data. You can delete it and it is actually deleted. If you had a photo that has been encrypted and stored in our private cloud, then we delete it from there too. Because we think that if you mean to make something be gone, then it should actually be gone. Simple.
                    </p>

                    <p>
                      This is what comprehensive control means to us. It means that we give you the controls to your data without any tricks. We even delete your data from Stripe (our secure payment provider) when you opt to delete your MOSSLET account, because that's simply <em>the right thing to do</em>.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="what-you-can-do">
                      <a href="#what-you-can-do" class="anchor dark:text-gray-200">
                        Intimate privacy protection
                      </a>
                    </h2>
                    <p>
                      If this term sounds unfamiliar to you, hop on over to your local bookstore and pick up a copy of
                      <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://bookshop.org/p/books/the-fight-for-privacy-protecting-dignity-identity-and-love-in-the-digital-age-danielle-keats-citron/18092442?ean=9781324066095&next=t"
                        class="dark:text-gray-200"
                      >
                        The Fight For Privacy
                      </.link>
                      for a thorough breakdown on intimate privacy and the fight to protect it.
                    </p>
                    <p>
                      What is intimate privacy?
                      <ul>
                        <li>
                          a <em>civil right</em>
                          hopefully (people have been fighting for it since 1890)
                        </li>
                        <li>
                          central to the development of an authentic and dignified identity
                        </li>
                        <li>a precondition to love, friendship, and civic engagement</li>
                        <li>
                          lets us form, develop, and reshape our identities
                        </li>
                      </ul>
                      Intimate privacy <strong class="dark:text-gray-200">should be a civil right</strong>. Intimate privacy pertains to deeply personal information and experiences that are fundamental to our sense of self, autonomy, and dignity. Making intimate privacy a civil right would prevent potential harm and exploitation, protect our autonomy as individuals, preserve our dignity, and allow us to maintain control over our most sensitive personal information. In short, intimate privacy is essential to human freedom and democracy — to being free to live our best lives.
                    </p>

                    <p>
                      Many of the ways that we protect your data on MOSSLET go hand-in-hand with protecting your intimate privacy. Most notably, you're in control of who and what you share (not even we can see your photos). And we go extra steps to restrict people's ability to "right click" on any images you share. It doesn't prevent someone from taking a screenshot of an image you share with them, but it does make it harder for them to steal your images. Further, your account is set to "private" by default. And if you discover that you shared something by mistake, you can delete it immediately (in realtime) across our service.
                    </p>
                    <p>
                      You're even in control of whether the people you are connected to can see personal details like your email, name, and avatar associated with your account.
                    </p>
                    <p>
                      Whenever you upload photos we check them against a not-safe-for-work (NSFW) image detector and reject any that don't pass. This check is done privately and your data is not sent anywhere nor used for training (the pre-trained algorithm runs on our private servers). The check isn't perfect, there's more work to be done here to fine-tune, but we feel it is a good step to further ensuring the protection of your intimate privacy on our service.
                    </p>
                    <p>
                      We're always thinking of ways to protect your intimate privacy and give you control, like making it super easy to see everyone who has access to your Posts and remove someone you didn't mean to share with (in realtime of course). Our next few steps involve making it quick and easy to (1) report/takedown harmful Posts and (2) talk to customer service (us) from within the privacy of your account.
                    </p>
                    <p></p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="what-you-can-do">
                      <a href="#what-you-can-do" class="anchor dark:text-gray-200">
                        Triple layer encryption
                      </a>
                    </h2>
                    <p>
                      This is the bread and butter of your safety on MOSSLET. We encrypt your data at-rest, in-transit, and end-to-end. When we say we use asymmetric encryption we mean that only you (and the people you choose to share with) can access your data. We don't have access to it — all we can see is a scrambled blob of encrypted text.
                    </p>
                    <p>
                      And the key to accessing your data is derived from your password — meaning that when you sign in to your account you are granted temporary access to your data. We don't store your password and we use industry-leading encryption and password-hashing libraries to handle the technical parts.
                    </p>

                    <p>
                      That's why if you forget your password you can get locked out of your account — we don't have access to it <em>by design</em>. That being said we recognize the importance of convenience and that people sometimes do forget their passwords.
                    </p>
                    <p>
                      To protect against that, we give you the ability to turn on a
                      <em>forgot password</em>
                      feature that temporarily stores a <em>symmetrically</em>
                      encrypted version of your password-derived key. This enables us to reset your password if you forget it while still giving you a strong level of protection and privacy. If you decide that you want to go back to the complete protection and privacy of our asymmetric encryption, then you can disable the forgot password feature — immediately deleting the symmetrically encrypted copy of your password-derived key — returning your account to its original asymmetric design.
                    </p>
                    <p>
                      In terms of storage, our databases are all on a private, encrypted network that does not allow any outside connections. When we send a photo to object storage in our private cloud (no Amazon here), it is already asymmetrically encrypted before being sent and stored.
                    </p>

                    <p>
                      We chose to design our service this way so that we can guarantee you data privacy and convenience to the best of our abilities. With this design we cannot identify your device or access your data. Even if we are required to hand over your data by a court order, we have no ability to decrypt it. The only thing we could do is hand over encrypted bits.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="what-you-can-do">
                      <a href="#what-you-can-do" class="anchor dark:text-gray-200">
                        Zero dark patterns
                      </a>
                    </h2>
                    <p>
                      Dark pattern design is what companies are using to trick you into doing something: usually staying on their service longer and giving away more of your data.
                    </p>
                    <p>
                      The most recognizable dark pattern is <em>infinite scroll</em>. This is when you have no concept of where the end is, or what to expect next, so you just keep on scrolling and scrolling and scrolling. It's not good. But people think it looks cool! That was smoking's whole brand too, right?
                    </p>

                    <p>
                      Sometimes it's cool to not be. So we avoid it.
                    </p>

                    <p>
                      It's also why our main color is a green rather than a blue. Why? Because companies discovered that blue has a psychological effect on our brain, making us more likely to stick around longer and click on things more (eg. buy more). We didn't want to be associated with tricking you. Who uses blue? X/Twitter, Facebook, Telegram, and BlueSky to name a few... blue is cool, we have another brand that has a lot of blue, it's probably not a big deal, but it's not something we felt comfortable doing for MOSSLET.
                    </p>
                    <p>
                      When you're on MOSSLET we don't have any dark pattern design. We go out of our way to make sure not to trick you. And we think that's pretty cool.
                    </p>

                    <p>
                      Thank you for being here and your interest in the growing movement for simple and ethical software. Tell a friend and
                      <.link navigate={~p"/auth/register"} class="dark:text-gray-200">
                        switch to MOSSLET
                      </.link>
                      today to start getting the protection you deserve.
                    </p>
                  </article>
                </div>
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
       "Blog | How MOSSLET Keeps You Safe"
     )}
  end
end
