defmodule MossletWeb.HomeLive do
  use MossletWeb, :live_view
  alias MossletWeb.Components.LandingPage

  @impl true
  def render(assigns) do
    # This UI renders on the web
    ~H"""
    <.layout
      type="public"
      user={assigns[:user]}
      current_page={:landing}
      container_max_width={@max_width}
      key={@key}
    >
      <LandingPage.hero
        li_logo={@li_logo}
        wsc_logo={@wsc_logo}
        pft_logo={@pft_logo}
        max_width={@max_width}
        background_hero_image={~p"/images/landing_page/background-features.jpg"}
      >
      </LandingPage.hero>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:max_width, fn -> "full" end)
      |> assign_new(:description, fn -> "This is our description" end)
      |> assign_new(:mp_logo, fn ->
        ~p"/images/landing_page/mosspiglet.svg"
      end)
      |> assign_new(:m_logo, fn ->
        ~p"/images/landing_page/mosslet.svg"
      end)
      |> assign_new(:li_logo, fn -> ~p"/images/partners/li_logo.png" end)
      |> assign_new(:wsc_logo, fn ->
        ~p"/images/partners/wsc_logo.jpg"
      end)
      |> assign_new(:pft_logo, fn ->
        ~p"/images/partners/pft_logo.png"
      end)
      |> assign_new(:in_app_encr_img, fn ->
        ~p"/images/screenshots/group_light.png"
      end)
      |> assign_new(:people_queue_img, fn ->
        ~p"/images/screenshots/posts_light.png"
      end)
      |> assign_new(:people_details_img, fn ->
        ~p"/images/screenshots/connections_light.png"
      end)
      |> assign_new(:memory_promo_img, fn ->
        ~p"/images/screenshots/memories_light.png"
      end)
      |> assign_new(:onboarding_promo_img, fn ->
        ~p"/images/screenshots/memory_upload_light.png"
      end)
      |> assign_new(:pwned_email_promo_img, fn ->
        ~p"/images/screenshots/settings_light.png"
      end)
      |> assign_new(:people_search_promo_img, fn ->
        ~p"/images/screenshots/memory_show_light.png"
      end)
      |> assign_new(:bg_cta_img, fn ->
        ~p"/images/landing_page/background-call-to-action.jpg"
      end)
      |> assign_new(:features_title, fn ->
        gettext("Everything you need to share without worry")
      end)
      |> assign_new(:features_description, fn ->
        gettext("Share with with privacy and ease.")
      end)
      |> assign_new(:meta_description, fn ->
        Application.get_env(:mosslet, :seo_description)
      end)
      |> assign(:page_title, "Welcome")

    # ... all other assigns preserved
    {:ok, socket}
  end
end
