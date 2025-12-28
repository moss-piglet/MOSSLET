defmodule MossletWeb.PublicLive.Blog.Blog03 do
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
        date="June 10, 2025"
        title="Major Airlines Sold Your Data to Homeland Security"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          With the summer months upon us and a sense of travel in the air, it's disappointing to learn about a secretive contract between the Customs and Border Patrol (CBP) and the Airlines Reporting Corporation (ARC) that began in June of 2024 and could extend to 2029.
        </p>

        <p>
          If flying on a major airline wasn't trouble enough, with increasing prices and crashes (due to faulty Boeing airplanes and understaffed and outdated air traffic control systems), the airlines have also been secretly selling passenger data to the Department of Homeland Security.
        </p>

        <p>
          Thanks to this <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.404media.co/airlines-dont-want-you-to-know-they-sold-your-flight-data-to-dhs/"
          >
          investigation by 404 Media</a>, and the <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://en.wikipedia.org/wiki/Freedom_of_Information_Act_(United_States)"
          >Freedom of Information Act (FOIA)</a>, we have proof of this
          <em>corporate data trickery</em>
          and can take steps to correct this violation of American civil liberties.
        </p>

        <hr />
        <h2 id="who-is-the-arc">
          <a href="#who-is-the-arc">
            Who is the ARC?
          </a>
        </h2>
        <p>
          The Airlines Reporting Corporation
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www2.arccorp.com/about-us/leadership-governance?utm_source=Global_Navigation#board-of-directors"
          >
            board of directors
          </a>
          is made up of executives from the major airlines: Air Canada, Air France, Alaska Airlines, American Airlines, Delta Air Lines, JetBlue Airways, Lufthansa, and Southwest Airlines. They are a
          <em>data broker</em>
          that collects and monetizes the data on all of their airline passengers (see <a href="/blog/articles/01">our article on data brokers</a>).
        </p>
        <p>
          The ARC also facilitates business between the airlines and travel agencies like Expedia. The sale of passenger data to the United States government is part of the data broker's Travel Intelligence Program (TIP). This TIP program updates the travel data of passengers every single day and "contains more than
          <em>1 billion records</em>
          spanning 39 months of past and future travel."
        </p>

        <p>
          Anyone with access to the TIP program can search for airline passengers by name, credit card, or airline.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/june_10_2025_asdf.jpg"}
              class="w-full"
              alt="Airlines selling passenger data illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@mylenecaneso/illustrations"
              class="ml-1"
            >
              Mylene Cañeso
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="loophole-for-surveillance">
          <a href="#loophole-for-surveillance">
            A loophole for surveillance
          </a>
        </h2>

        <p>
          We mentioned earlier our
          <a href="/blog/articles/01">
            first blog article
          </a>
          covering the government's refusal to protect Americans from data brokers, a decision that functions to keep alive a loophole for surveillance — legally outsourcing the spying on American citizens to private corporations.
        </p>
        <p>
          Not too long ago the American public rejected this kind of mass surveillance, then along came the tragedy on 9/11 and our leaders found a new argument to passify the public as they began bypassing our civil liberties and legal protections afforded us by the Constitution of the United States of America.
        </p>

        <hr />
        <h2 id="what-you-can-do">
          <a href="#what-you-can-do">
            What you can do
          </a>
        </h2>
        <p>
          As far as we know, the data in the ARC's Travel Intelligence Program is collected from third party travel agencies like Expedia. So,
          <strong>
            book your flights directly with the airline
          </strong>
          to possibly avoid this spying.
        </p>
        <p>
          Here are your steps for change:
        </p>
        <ol>
          <li>
            Write and call your congressmembers (try <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://5calls.org/"
            >5calls.org</a>).
          </li>
          <li>
            Contact your airline and tell them to stop selling your data to the government.
          </li>
          <li>Book your air travel directly with the airline.</li>
          <li>
            Read the Electronic Frontier Foundation's
            <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://www.eff.org/press/releases/digital-privacy-us-border-new-how-guide-eff"
            >
              privacy tips
            </a>
            at the border.
          </li>
        </ol>
        <p>
          Lastly, you can further protect your rights and your information by deleting your Big Tech social accounts and
          <a href="/">switching to MOSSLET</a>
          today.
        </p>

        <p>
          Thank you for being here and your interest in the growing movement for simple and ethical software. I look forward to writing about something happier next time — like all the ways MOSSLET keeps you safe.
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
       "Blog | Major Airlines Sold Your Data to Homeland Security"
     )
     |> assign_new(:meta_description, fn ->
       "If flying on a major airline wasn't trouble enough, with increasing prices and crashes (due to faulty Boeing airplanes and understaffed and outdated air traffic control systems), the airlines have also been secretly selling passenger data to the Department of Homeland Security."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/june_10_2025_asdf.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Airlines selling passenger data illustration")}
  end
end
