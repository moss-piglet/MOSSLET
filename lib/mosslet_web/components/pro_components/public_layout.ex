defmodule MossletWeb.PublicLayout do
  @moduledoc """
  This layout is for public pages like landing / about / pricing.
  """
  use Phoenix.Component
  use PetalComponents
  use MossletWeb, :verified_routes

  attr :current_page, :atom, required: true
  attr :public_menu_items, :list, default: []
  attr :user_menu_items, :list, default: []
  attr :avatar_src, :string, default: nil
  attr :current_user_name, :string, default: "nil"
  attr :copyright_text, :string, default: "Moss Piglet Corporation, All Rights Reserved."
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  attr :header_class, :string, default: ""
  attr :twitter_url, :string, default: nil
  attr :github_url, :string, default: nil
  attr :discord_url, :string, default: nil
  slot(:inner_block)
  slot(:top_right)
  slot(:logo)

  def mosslet_public_layout(assigns) do
    ~H"""
    <style>
      /* Hover effects for the top menu */
      header .menu-item {
        position: relative;
      }

      header .menu-item:before {
        content: '';
        position: absolute;
        right: 0;
        width: 0;
        bottom: 0;
        height: 2px;
        background: #4b5563;
        transition: 0.3s all ease;
      }

      .dark header .menu-item:before {
        background: #ccc;
      }

      header .menu-item:hover:before {
        left: 0;
        width: 100%;
      }

      header .menu-item.is-active:before {
        left: 0;
        width: 100%;
      }

      /* Translucent effects for the the navbar when you scroll down the page */
      header.is-active {
        background: rgba(255, 255, 255, .55);
        @apply shadow;
      }

      .dark header.is-active {
        background: rgba(0,0,0,.45);
        @apply shadow;
      }

      header.is-active.semi-translucent {
        backdrop-filter: saturate(180%) blur(10px);
        -webkit-backdrop-filter: saturate(180%) blur(10px);
        -moz-backdrop-filter: saturate(180%) blur(10px);
      }
    </style>

    <header
      x-data="{ isOpen: false}"
      x-init="window.makeHeaderTranslucentOnScroll()"
      class={[
        "fixed top-0 left-0 z-30 w-full transition duration-500 ease-in-out lg:sticky semi-translucent bg-white dark:bg-[#0B1120]",
        @header_class
      ]}
    >
      <.container max_width={@max_width}>
        <div class="flex flex-wrap items-center h-16 lg:h-18">
          <div class="lg:w-3/12">
            <div class="flex items-center">
              <.link class="inline-block ml-1 text-2xl font-bold leading-none" href="/">
                {render_slot(@logo)}
              </.link>

              <.link class="hidden ml-3 lg:block" href="/"></.link>
            </div>
          </div>

          <div class="hidden lg:w-6/12 lg:block">
            <ul class="justify-center lg:flex">
              <.list_menu_items
                li_class="ml-8 lg:mx-4 xl:mx-6"
                a_class="block font-medium leading-7 dark:text-gray-100 menu-item"
                menu_items={@public_menu_items}
              />
            </ul>
          </div>

          <div class="flex items-center justify-end ml-auto lg:w-3/12">
            <div class="flex items-center gap-3 mr-4">
              {render_slot(@top_right)}
            </div>

            <div class="hidden lg:block">
              <.user_dropdown_menu
                user_menu_items={@user_menu_items}
                avatar_src={~p"/images/logo.svg"}
                current_user_name={@current_user_name}
              />
            </div>

            <div
              @click="isOpen = !isOpen"
              class="relative inline-block w-5 h-5 cursor-pointer lg:hidden text-gray-600 hover:text-black dark:text-gray-400 hover:dark:text-white"
            >
              <svg
                x-bind:class="{ 'opacity-100' : !isOpen, 'opacity-0' : isOpen }"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="size-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
                />
              </svg>

              <svg
                x-bind:class="{ 'opacity-0' : !isOpen }"
                width="24"
                height="24"
                fill="none"
                class="absolute -mt-3 -ml-3 transform opacity-0 top-1/2 left-1/2 scale-80"
              >
                <path
                  d="M6 18L18 6M6 6l12 12"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
            </div>
          </div>
        </div>

        <div x-bind:class="{ 'block' : isOpen, 'hidden' : !isOpen }" class="lg:hidden">
          <hr class="border-primary-900 border-opacity-10 dark:border-gray-700" />
          <ul class="py-6">
            <.list_menu_items
              li_class="mb-2 last:mb-0 dark:text-gray-400"
              a_class="inline-block font-medium menu-item"
              menu_items={@public_menu_items}
            />

            <%= if @current_user_name do %>
              <div class="pt-4 pb-3">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <%= if @current_user_name || @avatar_src do %>
                      <.avatar name={@current_user_name} src={@avatar_src} size="sm" random_color />
                    <% else %>
                      <.avatar size="sm" />
                    <% end %>
                  </div>
                  <div class="ml-3">
                    <div class="text-base font-medium text-gray-800 dark:text-gray-300">
                      {@current_user_name}
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <.list_menu_items
              li_class="mb-2 last:mb-0"
              a_class="inline-block font-medium capitalize menu-item dark:text-gray-400"
              menu_items={@user_menu_items}
            />
          </ul>
        </div>
      </.container>
    </header>

    <div class="bg-white dark:bg-gray-950 pt-[64px] lg:pt-0">
      {render_slot(@inner_block)}
    </div>

    <section class="bg-white dark:bg-gray-950">
      <.container max_width={@max_width}>
        <MossletWeb.CoreComponents.footer current_user={@current_user} max_width={@max_width} />
      </.container>
    </section>
    """
  end

  attr :li_class, :string, default: ""
  attr :a_class, :string, default: ""
  attr :menu_items, :list, default: [], doc: "list of maps with keys :method, :path, :label"

  defp list_menu_items(assigns) do
    ~H"""
    <%= for menu_item <- @menu_items do %>
      <li class={@li_class}>
        <.link
          href={menu_item.path}
          class={@a_class}
          method={if menu_item[:method], do: menu_item[:method], else: nil}
        >
          {menu_item.label}
        </.link>
      </li>
    <% end %>
    """
  end
end
