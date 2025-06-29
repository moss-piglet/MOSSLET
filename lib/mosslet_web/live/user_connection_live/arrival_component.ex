defmodule MossletWeb.UserConnectionLive.ArrivalComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias MossletWeb.UserConnectionLive.Components

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.page_header :if={@action == :greet} title={@title} />
      <.p>
        View your awaiting connections below and accept, ignore, or privately decline.
      </.p>

      <Components.cards_greeter
        id="arrivals_greeter"
        stream={@stream}
        current_user={@user}
        key={@key}
        card_click={fn _uconn -> nil end}
        arrivals_count={@arrivals_count}
        options={@options}
        loading_list={@loading_list}
      />
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end
end
