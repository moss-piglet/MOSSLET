defmodule MossletWeb.PublicLive.Pricing do
  @moduledoc false
  use MossletWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      user={assigns[:user]}
      current_page={:pricing}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <MossletWeb.Components.LandingPage.beta_banner />
      <.container>
        <MossletWeb.Components.LandingPage.pricing_cards />
        <MossletWeb.Components.LandingPage.pricing_comparison />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign_new(:max_width, fn -> "full" end) |> assign(:page_title, "Pricing")}
  end
end
