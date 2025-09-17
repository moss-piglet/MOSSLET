defmodule MossletWeb.PublicLive.Faq do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

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
      <.container>
        <MossletWeb.Components.LandingPage.faq />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "FAQ")
     |> assign_new(:meta_description, fn ->
       "Frequently asked questions on MOSSLET. Can't find the answer you're looking for? Reach out to our customer support team. What is MOSSLET? MOSSLET is a privacy-first social network designed to protect users' privacy and human dignity from surveillance and the attention economy. We prioritize privacy, data protection, and creating a safe space for meaningful social interactions."
     end)}
  end
end
