defmodule MossletWeb.Layouts do
  use MossletWeb, :html

  alias MossletWeb.LandingPageComponents

  require Logger

  embed_templates "layouts/*"

  def favicon_link_meta(assigns) do
    ~H"""
    <!-- favicon -->
    <link rel="apple-touch-icon" sizes="180x180" href={~p"/favicon/apple-touch-icon.png"} />
    <link rel="icon" type="image/png" sizes="32x32" href={~p"/favicon/favicon-32x32.png"} />
    <link rel="icon" type="image/png" sizes="16x16" href={~p"/favicon/favicon-16x16.png"} />
    <link rel="manifest" href={~p"/favicon/site.webmanifest"} />
    <link rel="mask-icon" href={~p"/favicon/safari-pinned-tab.svg"} color="#5bbad5" />

    <link rel="apple-touch-icon" sizes="180x180" href={~p"/images/apple-touch-icon.png"} />
    <link rel="icon" type="image/png" sizes="32x32" href={~p"/images/favicon-32x32.png"} />
    <link rel="icon" type="image/png" sizes="16x16" href={~p"/images/favicon-16x16.png"} />
    <link rel="manifest" href={~p"/images/site.webmanifest"} />
    <link rel="mask-icon" href={~p"/images/safari-pinned-tab.svg"} color="#5bbad5" />
    <meta name="msapplication-TileColor" content="#da532c" />
    <meta name="theme-color" content="#ffffff" />
    """
  end

  def app_name, do: Mosslet.config(:app_name)

  def title(%{assigns: %{page_title: page_title}}), do: page_title

  def title(conn) do
    if public_page?(conn.request_path) do
      Logger.warning(
        "Warning: no title defined for path #{conn.request_path}. Defaulting to #{app_name()}. Assign `page_title` in controller action or live view mount to fix."
      )
    end

    app_name()
  end

  def description(%{assigns: %{meta_description: meta_description}}), do: meta_description

  def description(conn) do
    if conn.request_path == "/" do
      Mosslet.config(:seo_description)
    else
      if public_page?(conn.request_path) do
        Logger.warning(
          "Warning: no meta description for public path #{conn.request_path}. Assign `meta_description` in controller action or live view mount to fix."
        )
      end

      ""
    end
  end

  def og_image(%{assigns: %{og_image: og_image}}), do: og_image
  def og_image(_conn), do: url(~p"/images/open-graph.png")

  def og_image_width(%{assigns: %{og_image_width: og_image_width}}), do: og_image_width
  def og_image_width(_conn), do: "1200"

  def og_image_height(%{assigns: %{og_image_height: og_image_height}}), do: og_image_height
  def og_image_height(_conn), do: "630"

  def og_image_type(%{assigns: %{og_image_type: og_image_type}}), do: og_image_type
  def og_image_type(_conn), do: "image/png"

  def current_page_url(%{request_path: request_path}),
    do: MossletWeb.Endpoint.url() <> request_path

  def current_page_url(_conn), do: MossletWeb.Endpoint.url()

  def twitter_creator(%{assigns: %{twitter_creator: twitter_creator}}), do: twitter_creator
  def twitter_creator(_conn), do: twitter_site(%{})

  def twitter_site(%{assigns: %{twitter_site: twitter_site}}), do: twitter_site

  def twitter_site(_conn) do
    if Mosslet.config(:twitter_url) do
      "@" <> (:twitter_url |> Mosslet.config() |> String.split("/") |> List.last())
    else
      ""
    end
  end

  def public_page?(request_path) do
    stripped_path = URI.parse(request_path).path

    Enum.find(
      MossletWeb.Menus.public_menu_items(),
      &(URI.parse(&1.path).path == stripped_path)
    )
  end
end
