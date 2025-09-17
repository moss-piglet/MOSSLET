defmodule MossletWeb.PublicLive.Pricing do
  @moduledoc false
  use MossletWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:pricing}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <.container>
        <MossletWeb.Components.LandingPage.pricing_cards />
        <MossletWeb.Components.LandingPage.pricing_comparison />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Pricing")
     |> assign_new(:meta_description, fn ->
       "Simple, pay-once pricing. Say goodbye to never-ending subscription fees. Pay once and forget about it. With one, simple payment you get access to our service forever. No hidden fees, no subscriptions, no surprises. We also support lowering your upfront payment with Affirm."
     end)}
  end
end
