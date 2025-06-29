defmodule MossletWeb.PublicLive.Blog.Blog02 do
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
                  <time datetime="2025-05-14T19:00:00.000Z">May 20, 2025</time>
                </div>
                <div class="mb-6 px-4 lg:px-2 xl:mb-16 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <h1 class="inline-block max-w-(--breakpoint-md) text-[2.5rem]/10 font-bold tracking-tight text-pretty text-gray-950 lg:text-6xl dark:text-gray-200">
                    AI Algorithm Deciding Which Families Are Under Watch For Child Abuse
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
                      This story will hit close to home for any parent who has had to confront the prejudices of our society's legal systems governing children. Maybe you were a stay-at-home parent who experienced family court divorcing someone with personality disorders, or maybe you just happened to be born in the wrong neighborhood.
                    </p>
                    <p>
                      When confronted with a system, or person, of prejudice you find yourself met with a colossal wall of denial and retribution — denial of your self and opinions (including any supporting facts or evidence) and retribution for wrongdoing that has been created and assigned to you simply because you are different, other, <em>not like them</em>.
                    </p>
                    <p>
                      Prejudice dislodges and distorts reality. When one-side is prejudiced toward another, there is no amount of excellence that can overcome the perception of being wrong, bad, or
                      <em>less than</em>
                      — everything fits the narrative that is being unjustly and disproportionately applied.
                    </p>
                    <p>
                      And when it comes to families and the legal systems that govern them, it means a parent is forever threatened and filled with the fear of losing their child. A monstrously abusive terror.
                    </p>
                    <p>
                      Which brings us to this unsettling
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://themarkup.org/investigations/2025/05/20/the-nyc-algorithm-deciding-which-families-are-under-watch-for-child-abuse"
                        class="dark:text-gray-200"
                      >
                        report from the Markup
                      </a>
                      about an artificial intelligence system that is being used to decide which families are more likely to harm their children, and as you can imagine, the system is filled with prejudice.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="what-is-this-ai-powered-system">
                      <a href="#what-is-this-ai-powered-system" class="anchor dark:text-gray-200">
                        What is this AI-powered system?
                      </a>
                    </h2>
                    <p>
                      According to a
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.documentcloud.org/documents/25947755-acs-algorithm-technical-review/"
                        class="dark:text-gray-200"
                      >
                        technical document
                      </a>
                      by New York City’s Administration for Children Services (ACS), a quality assurance pilot program (QA) was launched in 2018 for investigations into high-risk cases of serious physical or sexual harm to children. Each year ACS conducts 60,000 child maltreatment investigations and the quality assurance pilot program would review up to 3,600 of those 60,000 cases. ACS was overwhelmed and struggling with “how to prioritize cases for review”, so they decided to build “a predictive model that computes the risk of each child” to help ease the workload.
                    </p>
                    <p>
                      The computer code, also called the model or AI-powered system, “uses 279 factors measured over a period of 1.5 years and prediction is made for an outcome spanning the 24 months following the observation date”. Come again? The AI-powered system is predicting whether a child will be harmed up to 2 years from now?
                    </p>

                    <p>
                      Any parent knows that family life and childhood development is <em>dynamic</em>, not frozen in time, but rather changing every moment of every day. It is possible that life last year was the same as life this year for your family, but it's not a guarantee. So, while the motivation behind this system is presumably good-natured, you can begin to see where problems arise.
                    </p>

                    <p>
                      And New York City's ACS seemed to agree, because they conducted an internal audit of their own system and concluded that it is "more likely to be incorrect than correct".
                    </p>

                    <div data-media="true">
                      <div class="not-prose relative overflow-hidden rounded-xl">
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
                        </div>
                        <img src={~p"/images/blog/may_20_2025_ainy.jpg"} />
                      </div>
                      <figcaption class="flex justify-end">
                        artwork by
                        <.link
                          target="_blank"
                          rel="noopener noreferrer"
                          href="https://unsplash.com/@bartolomewstudio/illustrations"
                          class="ml-1 dark:text-gray-200"
                        >
                          Bartolomew Studio
                        </.link>
                      </figcaption>
                    </div>

                    <hr class="dark:border-gray-700" />
                    <h2 id="humans-are-dynamic">
                      <a href="#humans-are-dynamic" class="anchor dark:text-gray-200">
                        Humans are dynamic
                      </a>
                    </h2>
                    <p>
                      Human and family dynamics tend to not fit nicely into the rigidity of computer coded instructions. Where mathematics largely stay the same,
                      <em>1 + 1</em>
                      was the same a thousand years ago as it is today and will be tomorrow, living systems are not.
                    </p>

                    <p>
                      Despite general patterns to people and their families, there are differences and those differences fluctuate, change, and matter — and are often not able to be accounted for in AI-powered systems.
                    </p>
                    <p>
                      When you try to build an artificial intelligence model, it is typically given a lot of pre-existing information about something. This is what it means when you hear someone say it takes a lot of data to train a model (there are numerous ways to go about making artificial intelligence but the most widely-used methods in use today are given pre-existing information like this).
                    </p>
                    <p>
                      Well, what is this pre-existing information and where does it come from? Great question. It could come from anywhere and because it is pre-existing, it typically includes any and all pre-existing
                      <em>prejudices</em>
                      with it.
                    </p>
                    <p>
                      Couple those pre-existing prejudices with the inability to fit living beings neatly into computer code, and you get AI-powered computer systems that reinforce and recreate the discrimination and suffering they claim to alleviate.
                    </p>

                    <div>
                      <div class="rounded-xl bg-gray-950 in-data-stack:mt-0 in-data-stack:rounded-none in-[figure]:-mx-1 in-[figure]:-mb-1 in-data-stack:[:first-child>&amp;]:rounded-t-xl in-data-stack:[:first-child>&amp;]:*:rounded-t-xl in-data-stack:[:last-child>&amp;]:rounded-b-xl in-data-stack:[:last-child>&amp;]:*:rounded-b-xl">
                        <div class="rounded-xl p-1 text-sm scheme-dark in-data-stack:rounded-none dark:bg-emerald-50/5 dark:inset-ring dark:inset-ring-emerald-50/10 in-data-stack:dark:inset-ring-0 not-prose">
                          <div class="*:flex *:*:shrink-0 *:*:grow *:overflow-auto *:rounded-lg *:bg-background-50/10! *:p-5 dark:*:bg-emerald-50/5! **:[.line]:isolate **:[.line]:block **:[.line]:not-last:min-h-[1lh] *:inset-ring *:inset-ring-background-50/10 dark:*:inset-ring-emerald-50/5 *:*:max-w-none">
                            <pre
                              class="shiki tailwindcss-theme has-highlighted"
                              style="background-color:transparent;color:var(--color-slate-50)"
                              tabindex="0"
                            ><code><span class="line"><span style="color:var(--color-slate-400)">## </span><span style="color:var(--color-pink-400)">A System of Permanance</span></span><span class="line"></span><span class="line -mx-5 pl-[calc(var(--spacing)*5-2px)] border-l-2 pr-5 border-emerald-400 bg-emerald-300/15"><span style="color:var(--color-slate-400)">![</span><span style="color:var(--color-emerald-300)">Severe Harm Present</span><span style="color:var(--color-slate-400)">](</span><span style="color:var(--color-slate-50)"></span><span style="color:var(--color-slate-400)">)</span></span><span class="line"></span><span class="line"><span style="color:var(--color-slate-50)">Your family has been selected for ongoing </span></span><span class="line"><span style="color:var(--color-slate-50)">investigation with an elevated risk of</span></span><span class="line"><span style="color:var(--color-slate-50)">future severe physical or sexual injury</span></span><span class="line"><span style="color:var(--color-slate-50)">within 2 years from today.</span></span><span class="line"></span></code></pre>
                          </div>
                        </div>
                      </div>
                    </div>
                    <p>
                      Two investigations conducted by ACS after their AI-powered system flagged a 39-year-old singer and film student, Jasmine Mitchell, concluded that her at-risk score and the investigations themselves were unfounded.
                    </p>
                    <p>
                      But that didn’t free Jasmine from the prejudice, “I’m still in the database” she told The Markup, “it feels like there’s this permanence to it even though both of my investigations were unfounded”.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="generalizations-harm-us-all">
                      <a href="#generalizations-harm-us-all" class="anchor dark:text-gray-200">
                        Generalizations harm us all
                      </a>
                    </h2>
                    <p>
                      Behind all AI-powered systems are series of increasing generalizations. In this case, there are 279 generalizations at play. For example, a decision gets made that poverty is neglect, and then anyone in lower-income neighborhoods becomes labeled as potentially abusive to their children.
                    </p>

                    <p>
                      It doesn’t take much to realize that rich kids can be at risk for abuse too — if not, where would our leaders come from?
                    </p>
                    <p>
                      Further, if people behind these AI-powered systems are deciding that poverty is neglect, then why isn’t the response to reduce poverty and provide more public funding and welfare?
                    </p>

                    <p>
                      I would wager these AI-powered systems increase or reinforce the same levels of child abuse because it applies a constant, never-ending pressure to the victims of these systems who have been labeled as high-risk.
                    </p>
                    <p>
                      Being a <em>good parent</em>
                      is already the hardest job in the world, having to do it with the suffocating weight of
                      <em>prejudicial surveillance</em>
                      is unconscionable.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="a-real-problem">
                      <a href="#a-real-problem" class="anchor dark:text-gray-200">
                        A real problem
                      </a>
                    </h2>
                    <p>
                      There is a considerable problem at the heart of this, and the number of cases of child abuse is alarming and overwhelming New York City’s ACS, the agency often blamed whenever a child is failed.
                    </p>
                    <p>
                      To me, it seems this AI-powered system is a good solution to alleviate blame from ACS but not a good solution to alleviate child abuse.
                    </p>
                    <p>
                      If you wanted to reduce and alleviate child abuse, then the way forward is quite familiar:
                      <ol>
                        <li>Dramatically reduce inequality.</li>
                        <li>
                          Dramatically increase education.
                        </li>
                        <li>
                          Dramatically increase access to childcare.
                        </li>
                        <li>
                          Dramtically increase access to health and mental care.
                        </li>
                      </ol>
                    </p>

                    <p>
                      These are not lightning bolt innovations. We know how to do all of these things and could, technically, do them. So why don’t we? Why are just finding new ways to shift the blame?
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="you-are-safe-on-mosslet">
                      <a href="#you-are-safe-on-mosslet" class="anchor dark:text-gray-200">
                        You are safe on MOSSLET
                      </a>
                    </h2>

                    <p>
                      Ultimately, a conversation about AI-powered systems is often a conversation about information — who controls it, who knows about it, where it comes from, what it is, and what is done with it. On apps and platforms (Facebook, Instagram, TikTok, X, YouTube, Google) your information is continuously stolen and used to identify, predict, and change your future behavior. Your information is taken from you and used against you — against all of us.
                    </p>

                    <p>
                      We are fed up with that. That's why we made <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://mosslet.com"
                        class="dark:text-gray-200"
                      >MOSSLET</a>. On MOSSLET you are safe to share about your family. When you make a post on MOSSLET no one collects information about you. We don't spy on you. We don't profit off of knowing whether you are happy, sad, or at risk of harming your children (we certainly hope not). On MOSSLET we can't know that even if we wanted to, <em>by design</em>.
                    </p>

                    <p>
                      Child abuse is a serious problem that deserves our society's compassion and resources to prevent and heal, not a prejudicial computer system that preaches predetermination and reinforces existing inequities, leaving no room for our humanity. We deserve a more human future.
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
       "Blog | AI Algorithm Deciding Which Families Are Under Watch For Child Abuse"
     )}
  end
end
