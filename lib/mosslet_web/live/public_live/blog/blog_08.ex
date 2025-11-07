defmodule MossletWeb.PublicLive.Blog.Blog08 do
  @moduledoc false
  use MossletWeb, :live_view
  alias MossletWeb.PublicLive.Blog.Components

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:blog}
      container_max_width={@max_width}
      key={@key}
    >
      <Components.blog_article
        date="November 7, 2025"
        title="Meta Layoffs Included Employees Who Monitored Risks to User Privacy"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          Mark Zuckerberg once said that people who trusted him with their personal information were "f***ing stupid." This week's news from Meta proves he was being honest about his company's true priorities — and it's not protecting your privacy.
        </p>

        <p>
          According to reports from <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.nytimes.com/2025/10/23/technology/meta-layoffs-user-privacy.html"
          >The New York Times</a>, Meta laid off over 100 people from its risk review organization — the very team responsible for ensuring the company's products comply with Federal Trade Commission agreements and global privacy regulations. While Meta's AI division shed 600 employees to "make decisions faster," the cuts to privacy oversight represent something far more troubling.
        </p>
        <p>
          This isn't just corporate restructuring. It's a deliberate gutting of the safeguards meant to protect your personal information, and it reveals everything you need to know about where Meta's priorities truly lie.
        </p>

        <hr />
        <h2 id="gutting-privacy-protections">
          <a href="#gutting-privacy-protections">
            Gutting privacy protections
          </a>
        </h2>
        <p>
          Meta's risk review organization wasn't just another corporate department — it was the team specifically created in response to the company's $5 billion FTC fine in 2019 for deceiving users about their privacy controls. These employees were responsible for auditing new products and ensuring they didn't violate the consent agreement Meta signed with federal regulators.
        </p>
        <p>
          Now, according to internal memos, Meta is replacing most of these human reviewers with "automated systems." Michel Protti, Meta's chief privacy officer, claims this shift will deliver "more accurate and reliable compliance outcomes." But current and former employees are skeptical that algorithms can effectively protect user privacy, especially around sensitive issues that require human judgment.
        </p>
        <p>
          Think about what this means: The company that has repeatedly violated user trust is now removing the human oversight designed to prevent future violations. It's like firing the safety inspectors at a nuclear plant because they're slowing down operations.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/nov_7_2025_mlemrp.jpg"}
              class="w-full"
              alt="Meta layoffs gut privacy protections illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@ghariza_/illustrations"
              class="ml-1"
            >
              Ghariza Mahavira
            </.link>
          </figcaption>
        </div>

        <p>
          The timing of these layoffs is particularly telling. Meta executives have reportedly grown frustrated with the pace of product development, and the risk organization was identified as one division that was "holding things up — by design." That's exactly the point! Privacy protections are supposed to slow down reckless data collection and use.
        </p>

        <p>
          This is surveillance capitalism in its purest form: remove the obstacles to profit, even when those obstacles exist to protect people's fundamental rights to privacy and autonomy.
        </p>

        <hr />
        <h2 id="a-pattern-of-disregard">
          <a href="#a-pattern-of-disregard">
            A pattern of disregard
          </a>
        </h2>

        <p>
          This isn't Meta's first rodeo when it comes to privacy violations. The company has a long history of treating user privacy as an obstacle to overcome rather than a right to respect:
        </p>
        <ul>
          <li>
            <strong>Cambridge Analytica scandal:</strong>
            87 million users' data was harvested without consent for political advertising
          </li>
          <li>
            <strong>$5 billion FTC fine:</strong>
            The largest privacy fine in history for deceiving users about privacy controls (their stock price went up after Zuck announced they'd simply set aside $5B/yr for future violations)
          </li>
          <li>
            <strong>Instagram teen mental health:</strong>
            Internal research showed the platform harms teenagers, but the company continued prioritizing engagement
          </li>
          <li>
            <strong>Location tracking:</strong>
            Continued tracking users even when they explicitly opted out of location services
          </li>
        </ul>
        <p>
          Each time, Meta promised to do better. Each time, they found new ways to prioritize profit over people. Now they're simply removing the human reviewers who were supposed to prevent these violations from happening again.
        </p>

        <hr />
        <h2 id="we-are-the-opposite">
          <a href="#we-are-the-opposite">
            We are the opposite
          </a>
        </h2>
        <p>
          At MOSSLET, we represent everything Meta is not. Where Meta guts privacy protections, we build them in from the ground up. Where Meta prioritizes speed over safety, we prioritize your rights over our profits. Where Meta automates away human oversight, we maintain human accountability at every level.
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            MOSSLET's Privacy-First Approach
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-2">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>No data collection for advertising purposes</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>Human oversight of all privacy-related decisions</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>Transparent about what data we need and why</span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>User control over their information at all times</span>
            </div>
          </div>
        </div>

        <p>
          We don't collect data to build advertising profiles. We don't track or sell your information to third parties. We don't use AI to monitor your behavior for profit. When Mark Zuckerberg called users "f***ing stupid" for trusting him, he revealed Meta's true attitude toward the people who use their platform.
        </p>

        <p>
          Our attitude is different: we believe you deserve respect, privacy, and control over your digital life. That's not just marketing talk — it's literally built into how our platform works.
        </p>

        <p>
          Meta's latest layoffs reveal a company that has given up any pretense of caring about user privacy. By gutting the very teams responsible for protecting your data, they've made their priorities crystal clear: profit comes first, people come last.
        </p>

        <p>
          You don't have to accept this. You have a choice. At <a href="/">MOSSLET</a>, we believe social media can exist without surveillance, without manipulation, and without treating you like a product to be sold. We're building the alternative that respects your humanity instead of exploiting it.
        </p>

        <p>
          Join us in creating a social media platform that puts people first.
          <a href="/auth/register">
            Switch to MOSSLET
          </a>
          today and experience what social media feels like when it's designed for you, not against you.
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
       "Blog | Meta Layoffs Included Employees Who Monitored Risks to User Privacy"
     )
     |> assign_new(:meta_description, fn ->
       "Meta laid off over 100 people from its risk review organization — the very team responsible for ensuring the company's products comply with Federal Trade Commission agreements and global privacy regulations. While Meta's AI division shed 600 employees to 'make decisions faster,' the cuts to privacy oversight represent something far more troubling. This isn't just corporate restructuring. It's a deliberate gutting of the safeguards meant to protect your personal information."
     end)}
  end
end
