defmodule MossletWeb.ViewSetupHook do
  @moduledoc """
  A LiveView setup hook, useful for resetting the page title, etc.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:reset_page_title, _params, _session, socket) do
    page_title = MossletWeb.Layouts.app_name()

    {:cont,
     socket
     |> assign(:page_title, page_title)
     |> attach_hook(:reset_page_title, :handle_event, fn
       "close_modal", _params, socket ->
         {:cont, assign(socket, :page_title, page_title)}

       _event, _params, socket ->
         {:cont, socket}
     end)}
  end
end
