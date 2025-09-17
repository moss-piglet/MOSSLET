defmodule MossletWeb.PublicLive.Blog.Blog01 do
  @moduledoc false
  use MossletWeb, :live_view

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:blog}
      container_max_width={@max_width}
      key={@key}
    >
      <div class="max-w-screen overflow-x-hidden">
        <div class="grid min-h-dvh grid-cols-1 grid-rows-[1fr_1px_auto_1px_auto] justify-center pt-14.25 [--gutter-width:2.5rem] lg:grid-cols-[var(--gutter-width)_minmax(0,var(--breakpoint-2xl))_var(--gutter-width)]">
          <div class="col-start-1 row-span-full row-start-1 hidden lg:block"></div>
          <div class="text-gray-950 dark:text-white">
            <div hidden=""></div>
            <div class="grid grid-cols-1 xl:grid-cols-[22rem_2.5rem_auto] xl:grid-rows-[1fr_auto]">
              <div class="col-start-2 row-span-2  max-xl:hidden"></div>
              <div class="max-xl:mx-auto max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="mt-16 px-4 text-sm/7 font-medium tracking-widest text-gray-500 dark:text-gray-400 uppercase lg:px-2">
                  <time datetime="2025-05-14T19:00:00.000Z">May 14, 2025</time>
                </div>
                <div class="mb-6 px-4 lg:px-2 xl:mb-16 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <h1 class="inline-block max-w-(--breakpoint-md) text-[2.5rem]/10 font-bold tracking-tight text-pretty text-gray-950 lg:text-6xl dark:text-gray-200">
                    U.S. Government Abandons Rule to Shield Consumers from Data Brokers
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
                        <div class="text-gray-950 dark:text-white">Mark</div>
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
                <div class="px-4 py-2 lg:px-2 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <article class="prose prose-blog max-w-(--breakpoint-md) dark:text-gray-400">
                    <p>
                      It feels like every day it gets harder and harder to find good news. Headlines are rightly dominated by the genocides perpretated by our own governments — whom we hope to defend us from such attrocities. Which made it even easier for this quiet event to slip by unnoticed if it wasn't for
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.wired.com/story/cfpb-quietly-kills-rule-to-shield-americans-from-data-brokers/"
                        class="dark:text-gray-200"
                      >
                        an article from Wired Magazine
                      </a>
                      that landed in my inbox courtesy of DuckDuckGo's <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://duckduckgo.com/newsletter"
                        class="dark:text-gray-200"
                      >privacy newsletter</a>.
                    </p>
                    <p>I am a parent.</p>
                    <p>
                      I decided to become a software developer in order to make
                      <a href="/" class="dark:text-gray-200">
                        MOSSLET — a privacy-first social network
                      </a>
                      for people. It was a response to a hunch that had been bouncing around my head for quite some time, and finally given the name
                      <em>surveillance capitalism</em>
                      by Shoshana Zuboff who devoted more than ten years of her life researching the new economic logic.
                    </p>
                    <p>
                      Today, I learned that the Consumer Financial Protection Bureau (CFPB) quietly withdrew its own proposal to protect Americans from the data broker industry. Its original rule was proposed last December under former director Rohit Chopra and would have gone a long way in shielding us from the indiscriminate sharing of our personal information — like social security numbers, addresses, phone numbers, you name it.
                    </p>
                    <p>
                      This latest decision comes from the current director Russell Vought and seems to appease the complaints of the Financial Technology Association (FTA), which had sent Vought a
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.ftassociation.org/wp-content/uploads/2025/05/FTA-Letter-on-OMB-Deregulation-RFI.pdf"
                        class="dark:text-gray-200"
                      >
                        letter
                      </a>
                      that appears to ultimately be saying that the proposed protections would make their jobs harder.
                    </p>
                    <p>
                      It's a difficult letter to read, full of legal and corporate jargon that gives it an air of authority and "good-intentioned-ness", and so I can imagine the difficulty a public official might have trying to decipher this letter and the veracity of the claims made by the FTA. Their claims appear to make sense, but for whom?
                    </p>
                    <p>
                      And anyway, why should we care? Just how out of control is the data broker industry?
                    </p>
                    <hr class="dark:border-gray-700" />
                    <h2 id="its-nothing-personal">
                      <a href="#its-nothing-personal" class="anchor dark:text-gray-200">
                        It's nothing personal
                      </a>
                    </h2>
                    <p>
                      You may have missed it but Consumer Reports and The Markup copublished an article <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://themarkup.org/privacy/2024/01/17/each-facebook-user-is-monitored-by-thousands-of-companies-study-indicates"
                        class="dark:text-gray-200"
                      >each Facebook user is monitored by thousands of companies</a>. The
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://innovation.consumerreports.org/wp-content/uploads/2024/01/CR_Who-Shares-Your-Information-With-Facebook.pdf"
                        class="dark:text-gray-200"
                      >
                        study from Consumer Reports
                      </a>
                      found that each user on Facebook is monitored by over 2,000 companies and that some users are monitored by more than 7,000.
                    </p>
                    <p>
                      What are these companies doing with all of this information on people and who are they? It's honestly unclear, the study even reports that 99% of participants were identified (targeted/monitored) by a company with an unidentifiable name — cue the irony. But it is clear that information about every single of one us is being passed around to anyone and everyone with an appetite for it.
                    </p>
                    <div data-media="true">
                      <div class="not-prose relative overflow-hidden rounded-xl">
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
                        </div>
                        <img src={~p"/images/blog/may_14_2025_cfpb.jpg"} />
                      </div>
                      <figcaption class="flex justify-end">
                        artwork by
                        <.link
                          target="_blank"
                          rel="noopener noreferrer"
                          href="https://unsplash.com/@milhad/illustrations"
                          class="ml-1 dark:text-gray-200"
                        >
                          Milhad Art
                        </.link>
                      </figcaption>
                    </div>
                    <p>
                      As I understand it, data brokers are companies that collect any and all information they can about you and make it available to others
                      <em>(for considerable profit I guess?)</em>
                      with no oversight to the process.
                    </p>
                    <p>
                      The CFPB, under its previous direction, described the practice of data brokers "by selling our most sensitive personal data without our knowledge or consent, data brokers can profit by enabling scamming, stalking, and spying". And the CFPB had proposed a rule that would apply a 1970's law, the Fair Credit Reporting Act, to data brokers by treating them like credit reporting agencies.
                    </p>
                    <p>
                      This was a reasonable proposal considering the information data brokers have includes anything and everything <em>from addresses and social security numbers to debt and medical information</em>. Treating data brokers as credit reporting agencies under the Fair Credit Reporting Act would have dramatically increased the security of Americans and reduced the amount of scamming, stalking, and spying that is enabled by the data broker industry.
                    </p>
                    <p>
                      Financial technology (FinTech) companies would still have been able to provide their services but may have had to redo the manner in which they so readily access and use our personal information. I believe that is what the Financial Technology Association's (FTA) letter to CFPB director Russell Vought was outlining when it stated "fraud prevention tools used throughout the industry will be impacted by this proposal".
                    </p>
                    <p>
                      I think making a company funded by billionaires, <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.ftassociation.org/members/"
                        class="dark:text-gray-200"
                      >the members of the FTA</a>, work a little harder to provide the service they're selling to people, in exchange for increased safety and privacy of the American public, seems like a reasonable trade-off.
                    </p>
                    <p>
                      So why would Russell Vought decide to withdraw his own bureau's proposal? Did he receive a private deal to protect him and his family from this industry in exchange for betraying the rest of the American public?
                    </p>
                    <p>
                      Well, as it turns out, it's not just the public that's being betrayed by this decision.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="national-security-problem">
                      <a href="#national-security-problem" class="anchor dark:text-gray-200">
                        National security problem
                      </a>
                    </h2>
                    <p>
                      On November 19, 2024, Wired magazine released an article revealing their investigation into the data broker industry that resulted in their ability to
                      <em>buy data tracking American soldiers and spies</em>
                      as they traveled to and from
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.wired.com/story/phone-data-us-soldiers-spies-nuclear-germany/"
                        class="dark:text-gray-200"
                      >
                        nuclear vaults and brothels
                      </a>
                      in Germany.
                    </p>

                    <p>
                      Apparently Wired was able to purchase billions of location cooardinates from an American data broker, analyze those coordinates, and then identify American service members and their daily routines.
                    </p>
                    <p>
                      Why could Wired obtain this data? Because <em>anyone</em> can.
                    </p>
                    <p>
                      Why is this being allowed? Possibly because the privatization of this spying allows government agencies that are not legally allowed to spy on their citizens to outsource accountability and piggyback on the spoils.
                    </p>
                    <p>
                      If there was ever a reasonable claim to national security being at risk, this seems like one of them.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="what-you-can-do">
                      <a href="#what-you-can-do" class="anchor dark:text-gray-200">
                        What you can do
                      </a>
                    </h2>
                    <p>
                      The first thing you can do is write to your congressmembers and let them know how you feel about this latest decision by the Consumer Financial Protection Bureau.
                    </p>

                    <p>
                      The next thing you can do is delete your Facebook account and other social media accounts and switch to privacy-first alternatives like <a
                        href="/"
                        class="dark:text-gray-200"
                      >MOSSLET</a>.
                    </p>
                    <p>
                      A third thing is to look into privacy-first services that try to help you remove your data from these data brokers — like DuckDuckGo's
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://spreadprivacy.com/meetprivacypro/"
                        class="dark:text-gray-200"
                      >
                        privacy pro
                      </a>
                      that has an information removal feature.
                    </p>

                    <p>
                      I've currently been using that information removal feature and it's great, but also feels like a never-ending game of whack-a-mole — your data is removed from one service only to be back up on another service the next month. But, at the very least, it'll give you a glimpse into how much data about you is out there.
                    </p>
                    <p>
                      This is why we need our Congress and public officials to take action on our behalf.
                    </p>
                    <p>
                      So, what can you do? Here it is:
                      <ol>
                        <li>
                          Write and call your congressmembers (try <.link
                            target="_blank"
                            rel="noopener noreferrer"
                            href="https://5calls.org/"
                            class="dark:text-gray-200"
                          >5calls.org</.link>).
                        </li>
                        <li>
                          Delete your Facebook and other <em>privacy-last</em> social media accounts.
                        </li>
                        <li>
                          Try a privacy-first <a
                            target="_blank"
                            rel="noopener noreferrer"
                            href="https://spreadprivacy.com/meetprivacypro/"
                            class="dark:text-gray-200"
                          >
                          information removal service</a>.
                        </li>
                        <li>
                          Switch to a
                          <a href="/" class="dark:text-gray-200">social network like ours</a>
                          to start dramatically reducing the amount of data these brokers have on you.
                        </li>
                      </ol>
                    </p>

                    <p>
                      Looking forward to you joining us and the growing movement for simple, ethical software. Let's elect leaders who prioritize people over profit!
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
       "Blog | U.S. Government Abandons Rule to Shield Consumers from Data Brokers"
     )
     |> assign_new(:meta_description, fn ->
       "Today, I learned that the Consumer Financial Protection Bureau (CFPB) quietly withdrew its own proposal to protect Americans from the data broker industry. Its original rule was proposed last December under former director Rohit Chopra and would have gone a long way in shielding us from the indiscriminate sharing of our personal information — like social security numbers, addresses, phone numbers, you name it."
     end)}
  end
end
