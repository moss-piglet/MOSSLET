defmodule MossletWeb.Components.Copyright do
  @moduledoc false
  use Phoenix.Component

  def copyright(assigns) do
    ~H"""
    <div class="relative">
      <span class="flex flex-wrap justify-center items-center pt-20 pb-4 text-sm italic font-light text-gray-500 dark:text-gray-300">
        <span class="mb:6 xs:mb-0">
          <iframe
            src="https://github.com/sponsors/moss-piglet/button"
            title="Sponsor moss-piglet"
            height="35"
            width="116"
            style="border: 0;"
          >
          </iframe>
        </span>
        <span class="ml-4">
          Made with 💙 by <a
            class="text-gray-500 underline dark:text-gray-300"
            href="https://mosspiglet.dev"
            target="_blank"
            rel="_noopener"
          >Moss Piglet Corporation</a>. &copy; 2023 All rights reserved.
        </span>
      </span>
    </div>
    """
  end
end
