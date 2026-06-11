defmodule MossletWeb.Layouts do
  use MossletWeb, :html

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

  def og_image_alt(%{assigns: %{og_image_alt: og_image_alt}}), do: og_image_alt
  def og_image_alt(_conn), do: "MOSSLET - Privacy-first social network logo and branding"

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

  @doc """
  A single liquid-metal theme toggle that flips between light and dark.

  The active theme is driven entirely by the `data-theme` attribute on `<html>`
  (set before paint in `head.html.heex`), so the correct icon is shown via the
  `dark:` variant without any LiveView round-trip. Clicking dispatches
  `phx:set-theme` with `data-phx-theme="toggle"`, which the inline script
  resolves against the currently applied theme.

  See `<head>` in `head.html.heex` which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={JS.dispatch("phx:set-theme")}
      data-phx-theme="toggle"
      aria-label="Toggle light and dark theme"
      title="Toggle theme"
      class={[
        "group relative flex items-center justify-center rounded-xl p-2.5 overflow-hidden",
        "text-slate-500 dark:text-slate-400",
        "transition-all duration-300 ease-out hover:scale-105 active:scale-95",
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500/50 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-slate-900"
      ]}
    >
      <%!-- Liquid background on hover --%>
      <span class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-50/40 via-emerald-50/60 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15 group-hover:opacity-100 rounded-xl">
      </span>
      <%!-- Shimmer sweep on hover --%>
      <span class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full rounded-xl">
      </span>

      <%!-- Moon shown in light mode (click → dark) --%>
      <MossletWeb.CoreComponents.phx_icon
        name="hero-moon"
        class="relative h-4 w-4 transition-colors duration-200 group-hover:text-emerald-600 dark:hidden"
      />
      <%!-- Sun shown in dark mode (click → light) --%>
      <MossletWeb.CoreComponents.phx_icon
        name="hero-sun"
        class="relative h-4 w-4 transition-colors duration-200 hidden dark:block dark:group-hover:text-emerald-400"
      />
    </button>
    """
  end
end
