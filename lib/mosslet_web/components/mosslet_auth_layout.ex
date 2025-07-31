defmodule MossletWeb.Components.MossletAuthLayout do
  @moduledoc false
  use Phoenix.Component
  use PetalComponents, except: [:button]
  use MossletWeb, :verified_routes

  def mosslet_auth_layout(assigns) do
    assigns = assigns

    ~H"""
    <div class="relative flex min-h-screen justify-center md:px-12 lg:px-0">
      <div class="relative z-10 flex flex-1 flex-col justify-center bg-white dark:bg-gray-900 py-12 px-4 shadow-2xl md:flex-none md:px-28">
        <div class="mx-auto w-full max-w-lg sm:px-4">
          {render_slot(@inner_block)}
        </div>
      </div>
      <div class="absolute inset-0 hidden w-full flex-1 sm:block lg:relative lg:w-0">
        <div class="min-h-screen bg-gradient-to-r from-primary-200 to-primary-500 ..."></div>
      </div>
    </div>
    """
  end
end
