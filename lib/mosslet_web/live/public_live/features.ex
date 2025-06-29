defmodule MossletWeb.PublicLive.Features do
  @moduledoc false
  use MossletWeb, :live_view

  alias MossletWeb.Components.LandingPage

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
        <LandingPage.landing_features />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign_new(:max_width, fn -> "full" end) |> assign(:page_title, "Features")}
  end
end
