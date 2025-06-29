defmodule MossletWeb.FaqLive.Index do
  use MossletWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "FAQ")

    {:ok, socket}
  end
end
