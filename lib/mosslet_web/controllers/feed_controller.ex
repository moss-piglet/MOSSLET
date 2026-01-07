defmodule MossletWeb.FeedController do
  use MossletWeb, :controller

  alias Mosslet.Timeline
  alias Mosslet.Encrypted

  @posts_limit 50

  def public(conn, _params) do
    posts = load_public_posts()

    conn
    |> put_resp_content_type("application/rss+xml")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> send_resp(200, build_rss_feed(posts))
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
        safe_content = String.replace(content, "]]>", "]]&gt;")
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
