defmodule MossletWeb.AuthLayout do
  @moduledoc false
  use Phoenix.Component
  use PetalComponents

  attr :title, :string
  attr :home_page, :string, default: "/"
  slot(:inner_block)
  slot(:logo)
  slot(:top_links)
  slot(:bottom_links)

  def auth_layout(assigns) do
    ~H"""
    <div class="fixed w-full h-full overflow-y-scroll bg-gray-100 dark:bg-gray-900">
      <div class="flex flex-col justify-center py-12 sm:px-6 lg:px-8">
        <div class="text-center sm:mx-auto sm:w-full sm:max-w-md">
          <div class="flex justify-center mb-10">
            <.link href={@home_page}>
              {render_slot(@logo)}
            </.link>
          </div>

          <.h2>
            {@title}
          </.h2>

          <%= if render_slot(@top_links) do %>
            <.p>
              {render_slot(@top_links)}
            </.p>
          <% end %>
        </div>
      </div>

      <div class="pb-20 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="px-4 py-8 bg-white shadow sm:rounded-lg sm:px-10 dark:bg-gray-800">
          {render_slot(@inner_block)}
        </div>

        <%= if render_slot(@bottom_links) do %>
          <div class="mt-5 text-center">
            {render_slot(@bottom_links)}
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
