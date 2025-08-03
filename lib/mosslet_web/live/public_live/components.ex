defmodule MossletWeb.PublicLive.Components do
  @moduledoc false
  use MossletWeb, :component

  def in_the_know(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl pt-16 pb-10">
      <h1 class="text-center text-6xl font-black tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
        Be in the know
      </h1>
      <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
        MOSSLET helps you reclaim the truth
      </h2>
      <p class="text-center mt-6 font-regular text-xl/8 text-gray-600 text-balance dark:text-gray-400">
        The #1 product of surveillance capitalism is disinformation. You can protect yourself by choosing organizations and sources of information that are factual and on the side of people, not profit. It may not be pretty or feel-good, because what profit-seekers are doing isn't pretty. But once we break free from Big Tech's disinformation silos, then we can start fixing problems and making progress again. MOSSLET is here to help you do that.
      </p>
    </div>
    <div class="mx-auto max-w-2xl">
      <div class="flex justify-center pb-4">
        <img class="size-24 sm:size-32" src={~p"/images/logo.svg"} />
        <img class="size-24 sm:size-32" src={~p"/images/logo.svg"} />
        <img class="size-24 sm:size-32" src={~p"/images/logo.svg"} />
      </div>
      <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
        <strong class="text-black dark:text-gray-200">
          At MOSSLET, there's no algorithm or "feed":
        </strong>
        You will see the Posts that your friends have shared with you, and that's it. Your friends will see any Posts that you have shared with them. Simple as that.
      </p>
      <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
        <strong class="text-black dark:text-gray-200">
          News is not our business:
        </strong>
        When your social platform is your source for news, or decides what is newsworthy, news quickly fades from facts to whatever suits the business. What keeps your eyes on the screen? What triggers your emotions making you vulnerable to advertising? Disinformation arises. Soon we can no longer agree on what's fact or opinion, what's real or imaginary. Without a shared sense of truth, our society struggles to function and we all suffer.
      </p>
      <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
        We think social platforms should not be news outlets. Nor should news outlets care about shareholders. Here are some ideas for where to turn for reputable, truthful, and unbiased news — information that will empower you, even if it's not pretty.
      </p>
    </div>

    <div class="mx-auto max-w-4xl py-16">
      <h2 class="text-center font-black text-balance text-5xl font-black tracking-tight text-black dark:text-white sm:text-6xl lg:text-7xl ">
        Big Tech controls who knows and who decides who knows.
        <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          Don't let them control you.
        </span>
      </h2>
    </div>

    <div class="mx-auto max-w-2xl">
      <p class="font-regular pt-6 mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
        <strong class="text-black dark:text-gray-200 text-2xl">
          General News Sources:
        </strong>
        <ul class="font-regular mt-6 text-xl/8 underline">
          <li>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.capitolhillcitizen.com/"
              class="dark:text-gray-300"
            >
              Capitol Hill Citizen — democracy dies in broad daylight
            </.link>
          </li>
        </ul>
        <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
          The Capitol Hill Citizen is a newspaper! For as little as a $5 donation, you'll receive a copy of the best newspaper we've read in years. From tireless public defenders like Ralph Nader, this newspaper is a refreshing breath of fresh air in a world of disinformation and corporate media corruption.
        </p>
        <ul class="font-regular mt-6 text-xl/8 underline">
          <li>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.democracynow.org/"
              class="dark:text-gray-300"
            >
              Democracy Now! — a global, daily news hour
            </.link>
          </li>
        </ul>
        <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
          Democracy Now! is a non-profit founded in 1996 that does not accept government funding, corporate sponsorship, underwriting or advertising revenue. You can trust that what you hear and see here is actually happening.
        </p>

        <ul class="font-regular mt-6 text-xl/8 underline">
          <li>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.propublica.org/"
              class="dark:text-gray-300"
            >
              ProPublica — investigative journalism in the public interest
            </.link>
          </li>
        </ul>

        <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
          From privacy to healthcare, ProPublica investigates issues that matter to all of us — no matter who you are or what you believe. Winner of the Pullitzer Prize for Public Service, ProPublica is an important, non-profit news source that you can trust.
        </p>
      </p>

      <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
        <strong class="text-black dark:text-gray-200 text-2xl">
          Privacy & Technology News Sources:
        </strong>
        <ul class="font-regular mt-6 text-xl/8 underline">
          <li>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.404media.co/"
              class="dark:text-gray-300"
            >
              404 Media — unparalleled access to hidden worlds both online and IRL
            </.link>
          </li>
        </ul>
        <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
          404 Media is a journalist-funded investigative, digital news company. They focus on  how technology shapes, and is shaped by, our world. They offer a brave take on media and are investigating the hidden worlds of technology, surveillance, and the internet.
        </p>

        <ul class="font-regular mt-6 text-xl/8 underline">
          <li>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.eff.org/"
              class="dark:text-gray-300"
            >
              Electronic Frontier Foundation — defending digital privacy, free speech, and innovation
            </.link>
          </li>
        </ul>
        <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
          The Electronic Frontier Foundation (EFF) is a non-profit that has been defending civil liberties in the digital world since 1990. They are a leading and trusted source for technology information and tireless advocate on behalf of the public — that's us. On top of news, they also provide guides and tools to help protect you online.
        </p>

        <ul class="font-regular mt-6 text-xl/8 underline">
          <li>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://themarkup.org/"
              class="dark:text-gray-300"
            >
              The Markup — challenging technology to serve the public good
            </.link>
          </li>
        </ul>
        <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
          The Markup is a recently founded non-profit that conducts investigative journalism into the technology world. Their journalism has led to real world impact and they provide access to their methods and datasets so that the public can verify their work.
        </p>
      </p>
    </div>
    """
  end
end
