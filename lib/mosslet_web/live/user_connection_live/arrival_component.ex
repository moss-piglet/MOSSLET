defmodule MossletWeb.UserConnectionLive.ArrivalComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias MossletWeb.UserConnectionLive.Components

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header Section --%>
      <div class="text-center sm:text-left space-y-3">
        <h2 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">
          {@title}
        </h2>
        <p class="text-base sm:text-lg text-gray-600 dark:text-gray-300 max-w-2xl mx-auto sm:mx-0">
          Review your pending connections below. You can accept, decline, or ignore each request.
        </p>
      </div>

      <%!-- Connection Cards --%>
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
