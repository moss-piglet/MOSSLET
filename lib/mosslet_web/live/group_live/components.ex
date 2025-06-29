defmodule MossletWeb.GroupLive.Components do
  @moduledoc """
  Components for groups.
  """
  use MossletWeb, :component
  use MossletWeb, :verified_routes

  def group_pagination(assigns) do
    ~H"""
    <nav
      :if={@group_count > 0}
      id="group-pagination"
      class="flex items-center justify-between border-t border-gray-200 dark:border-gray-700 px-4 sm:px-0"
    >
      <div class="-mt-px flex w-0 flex-1">
        <.link
          :if={@options.page > 1}
          patch={~p"/app/groups?#{%{@options | page: @options.page - 1}}"}
          class="inline-flex items-center border-t-2 border-transparent pr-1 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
        >
          <svg
            class="mr-3 h-5 w-5 text-gray-400"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a.75.75 0 01-.75.75H4.66l2.1 1.95a.75.75 0 11-1.02 1.1l-3.5-3.25a.75.75 0 010-1.1l3.5-3.25a.75.75 0 111.02 1.1l-2.1 1.95h12.59A.75.75 0 0118 10z"
              clip-rule="evenodd"
            />
          </svg>
          Previous
        </.link>
      </div>
      <div class="hidden md:-mt-px md:flex">
        <.link
          :for={{page_number, current_page?} <- group_pages(@options, @group_count)}
          class={
            if current_page?,
              do:
                "inline-flex items-center border-t-2 border-primary-500 px-4 pt-4 text-sm font-medium text-primary-600",
              else:
                "inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
          }
          patch={~p"/app/groups?#{%{@options | page: page_number}}"}
          aria-current="page"
        >
          {page_number}
        </.link>
      </div>
      <div class="-mt-px flex w-0 flex-1 justify-end">
        <.link
          :if={more_group_pages?(@options, @group_count)}
          patch={~p"/app/groups?#{%{@options | page: @options.page + 1}}"}
          class="inline-flex items-center border-t-2 border-transparent pl-1 pt-4 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
        >
          Next
          <svg
            class="ml-3 h-5 w-5 text-gray-400"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M2 10a.75.75 0 01.75-.75h12.59l-2.1-1.95a.75.75 0 111.02-1.1l3.5 3.25a.75.75 0 010 1.1l-3.5 3.25a.75.75 0 11-1.02-1.1l2.1-1.95H2.75A.75.75 0 012 10z"
              clip-rule="evenodd"
            />
          </svg>
        </.link>
      </div>
    </nav>
    """
  end

  defp more_group_pages?(options, post_count) do
    options.page * options.per_page < post_count
  end

  defp group_pages(options, post_count) do
    page_count = ceil(post_count / options.per_page)

    for page_number <- (options.page - 2)..(options.page + 2),
        page_number > 0 do
      if page_number <= page_count do
        current_page? = page_number == options.page
        {page_number, current_page?}
      end
    end
  end
end
