defmodule MetamorphicWeb.ConversationLive.Index do
  use MetamorphicWeb, :live_view
  require Logger

  alias Metamorphic.Conversations
  alias Metamorphic.Conversations.Conversation

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:ai_tokens, socket.assigns.current_user.ai_tokens)
      |> assign(:ai_tokens_used, socket.assigns.current_user.ai_tokens_used)
      |> assign(
        :tokens_available,
        monthly_tokens(socket.assigns.current_user.ai_tokens, socket.assigns.current_user)
      )
      |> assign(:conversations, Conversations.load_conversations(socket.assigns.current_user))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Conversation")
    |> assign(:conversation, Conversations.get_conversation!(id, socket.assigns.current_user))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Conversation")
    |> assign(:conversation, %Conversation{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Conversations")
    |> assign(:conversation, nil)
  end

  @impl true
  def handle_info({MetamorphicWeb.ConversationLive.FormComponent, {:saved, conversation}}, socket) do
    {:noreply, stream_insert(socket, :conversations, conversation)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    if user do
      conversation = Conversations.get_conversation!(id, user)
      {:ok, _} = Conversations.delete_conversation(conversation, user)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
end
