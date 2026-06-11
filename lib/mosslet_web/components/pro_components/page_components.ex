defmodule MossletWeb.PageComponents do
  @moduledoc false
  use Phoenix.Component

  @doc """
  Allows you to have a heading on the left side, and some action buttons on the right (default slot)
  """

  attr :class, :string, default: ""
  attr :title, :string, required: true
  slot(:inner_block)

  def page_header(assigns) do
    assigns = assign_new(assigns, :inner_block, fn -> nil end)

    ~H"""
    <div class={["mb-8 sm:flex sm:justify-between sm:items-center", @class]}>
      <div class="mb-4 sm:mb-0">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
          {@title}
        </h1>
      </div>

      <div class="">
        <%= if @inner_block do %>
          {render_slot(@inner_block)}
        <% end %>
      </div>
    </div>
    """
  end

  @doc "Gives you a white background with shadow."
  attr :class, :string, default: ""
  attr :padded, :boolean, default: false
  attr :rest, :global
  slot(:inner_block)

  def box(assigns) do
    ~H"""
    <div
      {@rest}
      class={[
        "bg-white dark:bg-gray-800 dark:border dark:border-gray-700 rounded-lg shadow overflow-hidden",
        @class,
        if(@padded, do: "spx-4 py-8 sm:px-10", else: "")
      ]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
