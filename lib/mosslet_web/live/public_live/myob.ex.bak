defmodule MossletWeb.PublicLive.Myob do
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
        <LandingPage.myob />
      </.container>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Mind Your Own Business")
     |> assign_new(:meta_description, fn ->
       "At MOSSLET, our business model is as basic as it is boring: We charge our customers a fair price for our products. That's it. We don't take your personal data as payment, we don't try to monetize your eyeballs, we don't target you, we don't sell, broker, or barter ads. We will never track you, spy on you, or enable others to either. It's absolutely none of their business, and it's none of ours either."
     end)}
  end
end
