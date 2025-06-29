defmodule MossletWeb.PublicLive.Faq do
  @moduledoc false
  use MossletWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:faq}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <MossletWeb.Components.LandingPage.beta_banner />
      <.container>
        <MossletWeb.Components.LandingPage.faq />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign_new(:max_width, fn -> "full" end) |> assign(:page_title, "FAQ")}
  end
end
