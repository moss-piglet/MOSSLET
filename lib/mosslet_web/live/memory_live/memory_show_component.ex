defmodule MossletWeb.MemoryLive.MemoryShowComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Accounts
  alias Mosslet.Memories
  alias MossletWeb.Endpoint

  import MossletWeb.MemoryLive.Components

  def render(assigns) do
    ~H"""
    <div class="bg-gray-50 dark:bg-gray-900 transition-all px-1 py-2">
      <div class="grid grid-cols-1 gap-x-4 gap-y-8 xs:grid-cols-3 sm:grid-cols-6">
        <%!-- Memory image --%>
        <.memory_image
          current_user={@current_user}
          key={@key}
          memory={@memory}
          memory_list={@memory_list}
          user_connection={@user_connection}
        />

        <div class="space-y-4 xs:col-span-1 sm:col-span-2">
          <%!-- Memory details (including actions and reactions) --%>
          <.memory_details
            current_user={@current_user}
            key={@key}
            memory={@memory}
            memory_list={@memory_list}
            user_connection={@user_connection}
            excited_count={@excited_count}
            loved_count={@loved_count}
            happy_count={@happy_count}
            sad_count={@sad_count}
            thumbsy_count={@thumbsy_count}
            temp_socket={@temp_socket}
          />

          <.memory_remarks
            current_user={@current_user}
            key={@key}
            memory={@memory}
            user_connection={@user_connection}
            remark_count={@remark_count}
            remarks={@remarks}
            loading_list={@loading_list}
            patch={@patch}
            remark={@remark}
          />

          <.memory_remarks_feed
            current_user={@current_user}
            key={@key}
            memory={@memory}
            user_connection={@user_connection}
            remark_count={@remark_count}
            remarks={@remarks}
            loading_list={@loading_list}
            options={@options}
            patch={@patch}
            remark={@remark}
          />
        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    # remarks = Memories.list_remarks(memory, options)
    memory = assigns.memory
    current_user = assigns.current_user

    if connected?(socket) do
      if current_user do
        Accounts.private_subscribe(current_user)
        Memories.subscribe()
        Memories.connections_subscribe(current_user)
        Endpoint.subscribe("memory:#{memory.id}")
      else
        Accounts.subscribe()
        Memories.subscribe()
      end
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:remark_count, Memories.remark_count(memory))
     |> assign(:excited_count, Memories.get_remarks_excited_count(memory))
     |> assign(:loved_count, Memories.get_remarks_loved_count(memory))
     |> assign(:happy_count, Memories.get_remarks_happy_count(memory))
     |> assign(:sad_count, Memories.get_remarks_sad_count(memory))
     |> assign(:thumbsy_count, Memories.get_remarks_thumbsy_count(memory))}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
