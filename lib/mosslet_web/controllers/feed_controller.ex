defmodule MossletWeb.FeedController do
  use MossletWeb, :controller

  alias Mosslet.Timeline
  alias Mosslet.Encrypted

  @posts_limit 50

  @blog_entries [
    %{
      id: "13",
      date: "January 15, 2026",
      title: "How We Built Privacy-First AI (And Why It Matters)",
      preview:
        "We get this question a lot: \"Wait, you have AI features? How is that private?\" Today I want to pull back the curtain on exactly how we've built AI into MOSSLET without compromising on privacy. No vague promises. No marketing speak. Just the technical reality of how this actually works.",
      path: "/blog/articles/13"
    },
    %{
      id: "12",
      date: "January 07, 2026",
      title: "Introducing Journal: Your Private Space for Reflection",
      preview:
        "I think a lot about what kind of world my kids are growing up in. A world where every thought shared online becomes data to be harvested. Where moments of vulnerability become training data for algorithms designed to manipulate. Where there's nowhere left to just... be.",
      path: "/blog/articles/12"
    },
    %{
      id: "11",
      date: "December 22, 2025",
      title: "Introducing Our Referral Program: Share the Love, Get Paid",
      preview:
        "We wanted to create something where growth benefits everyone. When MOSSLET grows, it's because real people told real friends about something they genuinely value. And those people get rewarded for helping us build a community that respects privacy.",
      path: "/blog/articles/11"
    },
    %{
      id: "10",
      date: "December 8, 2025",
      title: "How we built surveillance-resistant social media",
      preview:
        "I've been asked a few times now to write about how MOSSLET actually works under the hood. We're open source, so anyone can read the code, but code isn't documentation — and most people don't read Elixir. So here's the technical story of how we built a social network that can't spy on its own people.",
      path: "/blog/articles/10"
    },
    %{
      id: "09",
      date: "November 27, 2025",
      title: "Unlock Sessions: Privacy Meets Convenience This Holiday Season",
      preview:
        "The autumn leaves are falling and the coziness is here — a time for gathering with loved ones, sharing memories, and yes, spending a bit more time on our devices connecting with friends and family near and far. At MOSSLET, we've been thinking about how to make your experience both secure and convenient this holiday season.",
      path: "/blog/articles/09"
    },
    %{
      id: "08",
      date: "November 7, 2025",
      title: "Meta Layoffs Included Employees Who Monitored Risks to User Privacy",
      preview:
        "Mark Zuckerberg once said that people who trusted him with their personal information were 'f***ing stupid.' This week's news from Meta proves he was being honest about his company's true priorities — and it's not protecting your privacy.",
      path: "/blog/articles/08"
    },
    %{
      id: "07",
      date: "September 4, 2025",
      title: "Smart Doorbells Spying for Insurance Companies",
      preview:
        "What began as a convenient security device to protect your family, and packages, has morphed into a corporate (and state) surveillance tool that fundamentally changes the relationship between you and your insurance provider.",
      path: "/blog/articles/07"
    },
    %{
      id: "06",
      date: "August 19, 2025",
      title: "Disappearing Keyboard on Apple iOS Safari",
      preview:
        "This is great if you want Apple to create a password for you, and not so great if you want to create your own password with the onscreen keyboard. We have encountered this annoyance when trying to create a new account, so we thought we'd share some options for a quick workaround.",
      path: "/blog/articles/06"
    },
    %{
      id: "05",
      date: "August 13, 2025",
      title: "Companies Selling AI to Geolocate Your Social Media Photos",
      preview:
        "To get a better idea of what this means, imagine you share a photo on Instagram, Facebook, X, Bluesky, Mastodon, or other social media surveillance platform (even a video on TikTok or YouTube), and in that photo is a harmless object (like a car or a building). But to this company's surveillance algorithm, that harmless object is a clue that can be used to determine your location at the time the photo was taken.",
      path: "/blog/articles/05"
    },
    %{
      id: "04",
      date: "June 26, 2025",
      title: "How MOSSLET Keeps You Safe",
      preview:
        "Someone requesting to connect with you online shouldn't be more important to whatever you are doing in real life. But that's exactly what is happening on these Big Tech services, our brains are being rewired to prioritize responding to an online notification over our real life interactions.",
      path: "/blog/articles/04"
    },
    %{
      id: "03",
      date: "June 10, 2025",
      title: "Major Airlines Sold Your Data to Homeland Security",
      preview:
        "If flying on a major airline wasn't trouble enough, with increasing prices and crashes (due to faulty Boeing airplanes and understaffed and outdated air traffic control systems), the airlines have also been secretly selling passenger data to the Department of Homeland Security.",
      path: "/blog/articles/03"
    },
    %{
      id: "02",
      date: "May 20, 2025",
      title: "AI Algorithm Deciding Which Families Are Under Watch For Child Abuse",
      preview:
        "Which brings us to this unsettling report from the Markup about an artificial intelligence system that is being used to decide which families are more likely to harm their children, and as you can imagine, the system is filled with prejudice.",
      path: "/blog/articles/02"
    },
    %{
      id: "01",
      date: "May 14, 2025",
      title: "U.S. Government Abandons Rule to Shield Consumers from Data Brokers",
      preview:
        "Today, I learned that the Consumer Financial Protection Bureau (CFPB) quietly withdrew its own proposal to protect Americans from the data broker industry. Its original rule was proposed last December under former director Rohit Chopra and would have gone a long way in shielding us from the indiscriminate sharing of our personal information.",
      path: "/blog/articles/01"
    }
  ]

  def public(conn, _params) do
    posts = load_public_posts()

    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> send_resp(200, build_rss_feed(posts))
  end

  def blog(conn, _params) do
    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, build_blog_rss_feed())
  end

  defp build_blog_rss_feed do
    base_url = MossletWeb.Endpoint.url()

    items =
      @blog_entries
      |> Enum.map(&build_blog_item(&1, base_url))
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/">
      <channel>
        <title>MOSSLET Blog</title>
        <link>#{escape_xml(base_url)}/blog</link>
        <description>Learn about privacy, our company, and our opinions on the latest privacy news.</description>
        <language>en-us</language>
        <lastBuildDate>#{format_rfc822(DateTime.utc_now())}</lastBuildDate>
        <atom:link href="#{escape_xml(base_url)}/feed/blog.xml" rel="self" type="application/rss+xml"/>
        <image>
          <url>#{escape_xml(base_url)}/images/logo.svg</url>
          <title>MOSSLET Blog</title>
          <link>#{escape_xml(base_url)}/blog</link>
        </image>
    #{items}
      </channel>
    </rss>
    """
  end

  defp build_blog_item(entry, base_url) do
    pub_date = parse_blog_date(entry.date)
    link = "#{escape_xml(base_url)}#{escape_xml(entry.path)}"

    preview_html =
      entry.preview
      |> String.replace("]]>", "]]&gt;")
      |> then(&"<![CDATA[#{&1}]]>")

    """
        <item>
          <title>#{escape_xml(entry.title)}</title>
          <link>#{link}</link>
          <guid isPermaLink="true">#{link}</guid>
          <pubDate>#{pub_date}</pubDate>
          <dc:creator>MOSSLET</dc:creator>
          <description>#{preview_html}</description>
        </item>
    """
  end

  defp parse_blog_date(date_string) do
    [month_name, day_with_comma, year] = String.split(date_string)
    day = String.trim_trailing(day_with_comma, ",")

    month =
      case month_name do
        "January" -> 1
        "February" -> 2
        "March" -> 3
        "April" -> 4
        "May" -> 5
        "June" -> 6
        "July" -> 7
        "August" -> 8
        "September" -> 9
        "October" -> 10
        "November" -> 11
        "December" -> 12
      end

    {:ok, date} = Date.new(String.to_integer(year), month, String.to_integer(day))
    {:ok, datetime} = DateTime.new(date, ~T[12:00:00], "Etc/UTC")
    format_rfc822(datetime)
  end

  defp load_public_posts do
    options = %{
      post_page: 1,
      filter: %{post_per_page: @posts_limit}
    }

    Timeline.list_discover_posts(nil, options)
  end

  defp build_rss_feed(posts) do
    base_url = MossletWeb.Endpoint.url()

    items =
      posts
      |> Enum.map(&build_item(&1, base_url))
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:media="http://search.yahoo.com/mrss/">
      <channel>
        <title>MOSSLET Public Timeline</title>
        <link>#{escape_xml(base_url)}/discover</link>
        <description>Public posts from the MOSSLET community - a privacy-first social network.</description>
        <language>en-us</language>
        <lastBuildDate>#{format_rfc822(DateTime.utc_now())}</lastBuildDate>
        <atom:link href="#{escape_xml(base_url)}/feed/public.xml" rel="self" type="application/rss+xml"/>
        <image>
          <url>#{escape_xml(base_url)}/images/logo.svg</url>
          <title>MOSSLET Public Timeline</title>
          <link>#{escape_xml(base_url)}/discover</link>
        </image>
    #{items}
      </channel>
    </rss>
    """
  end

  defp build_item(post, base_url) do
    post_key = decrypt_post_key(post)
    content = decrypt_content(post.body, post_key)
    username = decrypt_content(post.username, post_key) || "MOSSLET User"
    pub_date = format_rfc822(post.inserted_at)
    guid = "#{escape_xml(base_url)}/post/#{escape_xml(to_string(post.id))}"
    image_enclosures = build_image_enclosures(post, post_key, base_url)
    media_content = build_media_content(post, post_key, base_url)

    content_html =
      if content do
        rendered = Mosslet.MarkdownRenderer.to_html(content)
        safe_content = String.replace(rendered, "]]>", "]]&gt;")
        "<![CDATA[#{safe_content}]]>"
      else
        "<![CDATA[Content unavailable]]>"
      end

    """
        <item>
          <title>Post by #{escape_xml(username)}</title>
          <link>#{guid}</link>
          <guid isPermaLink="false">#{escape_xml(post.id)}</guid>
          <pubDate>#{pub_date}</pubDate>
          <dc:creator>#{escape_xml(username)}</dc:creator>
          <description>#{content_html}</description>
    #{image_enclosures}#{media_content}
        </item>
    """
  end

  defp decrypt_post_key(post) do
    encrypted_key = get_post_key(post)

    case Encrypted.Users.Utils.decrypt_public_item_key(encrypted_key) do
      post_key when is_binary(post_key) -> post_key
      _ -> nil
    end
  end

  defp decrypt_content(_payload, nil), do: nil

  defp decrypt_content(payload, post_key) do
    case Encrypted.Utils.decrypt(%{key: post_key, payload: payload}) do
      {:ok, content} -> content
      _ -> nil
    end
  end

  defp get_post_key(post) do
    Enum.at(post.user_posts, 0).key
  end

  defp build_image_enclosures(post, post_key, base_url) do
    case decrypt_image_count(post, post_key) do
      0 ->
        ""

      count ->
        0..(count - 1)
        |> Enum.map(fn index ->
          url =
            "#{escape_xml(base_url)}/feed/public/posts/#{escape_xml(to_string(post.id))}/images/#{index}"

          "      <enclosure url=\"#{url}\" type=\"image/webp\" />"
        end)
        |> Enum.join("\n")
        |> then(&(&1 <> "\n"))
    end
  end

  defp build_media_content(post, post_key, base_url) do
    case decrypt_image_count(post, post_key) do
      0 ->
        ""

      count ->
        0..(count - 1)
        |> Enum.map(fn index ->
          url =
            "#{escape_xml(base_url)}/feed/public/posts/#{escape_xml(to_string(post.id))}/images/#{index}"

          "      <media:content url=\"#{url}\" medium=\"image\" type=\"image/webp\" />"
        end)
        |> Enum.join("\n")
        |> then(&(&1 <> "\n"))
    end
  end

  defp decrypt_image_count(_post, nil), do: 0

  defp decrypt_image_count(post, _post_key) do
    case post.image_urls do
      urls when is_list(urls) -> length(urls)
      _ -> 0
    end
  end

  defp format_rfc822(%NaiveDateTime{} = naive) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> format_rfc822()
  end

  defp format_rfc822(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S +0000")
  end

  defp escape_xml(nil), do: ""

  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp escape_xml(_), do: ""
end
