defmodule MossletWeb.PublicLive.InTheKnow do
  @moduledoc false
  use MossletWeb, :live_view

  alias MossletWeb.PublicLive.Components

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
        <Components.in_the_know />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Huh? Be In The Know")
     |> assign_new(:meta_description, fn ->
       "MOSSLET helps you reclaim the truth. The #1 product of surveillance capitalism is disinformation. You can protect yourself by choosing organizations and sources of information that are factual and on the side of people, not profit. It may not be pretty or feel-good, because what profit-seekers are doing isn't pretty. But once we break free from Big Tech's disinformation silos, then we can start fixing problems and making progress again. MOSSLET is here to help you do that."
     end)}
  end
end
