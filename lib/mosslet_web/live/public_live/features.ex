defmodule MossletWeb.PublicLive.Features do
  @moduledoc false
  use MossletWeb, :live_view

  alias MossletWeb.Components.LandingPage

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
        <LandingPage.landing_features />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Features")
     |> assign_new(:meta_description, fn ->
       "Social media, unexpected. Tired of feeling anxious and stressed every time you log in? Unlike Facebook and other Big Tech platforms, MOSSLET protects your privacy, is easier to use, and doesn't secretly control you."
     end)}
  end
end
