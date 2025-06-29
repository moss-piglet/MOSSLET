defmodule MossletWeb.BillingComponents do
  @moduledoc false
  use Phoenix.Component
  use MossletWeb, :verified_routes
  use PetalComponents

  use Gettext, backend: MossletWeb.Gettext

  attr :panels, :integer, default: 3
  attr :interval_selector, :boolean, default: false
  attr :rest, :global
  slot :default

  def pricing_panels_container(assigns) do
    ~H"""
    <div x-data="{ interval: 'one_time' }">
      <div :if={@interval_selector} class="flex justify-center">
        <div class="grid grid-cols-1 p-1 text-xs font-semibold leading-5 text-center text-black bg-background-200 rounded-full dark:text-white gap-x-1 dark:bg-white/20">
          <label
            class="px-4 py-2 rounded-full cursor-pointer"
            @click="interval = 'one_time'"
            x-bind:class="{ 'bg-primary-600 text-white dark:bg-primary-500': interval == 'one_time' }"
          >
            <input type="radio" name="frequency" value="personal" class="sr-only" />
            <span>Personal</span>
          </label>
          <%!--
            <label
              class="px-4 py-2 rounded-full cursor-pointer"
              @click="interval = 'year'"
              x-bind:class="{ 'bg-primary-500 text-white': interval == 'year' }"
            >
              <input type="radio" name="frequency" value="family" class="sr-only" />
              <span>Family</span>
            </label>
          --%>
        </div>
      </div>

      <div
        {@rest}
        class={[
          "grid max-w-md grid-cols-1 gap-8 mx-auto mt-10 isolate",
          pricing_panels_container_css(@panels)
        ]}
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil, doc: "Outer div class"
  attr :label, :string
  attr :description, :string
  attr :features, :list, default: []
  attr :most_popular, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :default

  def pricing_panel(assigns) do
    ~H"""
    <div class={"relative p-8 transition duration-500 ease-in-out shadow-xl rounded-3xl xl:p-10 #{@class} " <> if @most_popular, do: "bg-emerald-400/5 ring-emerald-950/5 shadow-emerald-400/5 dark:shadow-emerald-400 dark:ring-emerald-500/50 ring-2", else: "bg-white dark:bg-gray-800 ring-gray-950/5 shadow-gray-400/5 dark:shadow-emerald-500/50 dark:ring-emerald-500/50 ring-1"}>
      <%= if @most_popular do %>
        <div class="absolute top-0 right-0 mr-6 -mt-4">
          <div class="inline-flex px-3 py-1 mt-px text-sm font-semibold rounded-full text-emerald-600 bg-emerald-200 dark:bg-emerald-800 dark:text-emerald-100">
            {gettext("Most Popular")}
          </div>
        </div>
      <% end %>

      <div class="flex items-center justify-between gap-x-4">
        <h3 class="text-lg font-semibold leading-8 text-black dark:text-white">
          {@label}
        </h3>
        <.badge color="warning" label="Save 40%" variant="soft" class="rounded-full" />
      </div>
      <p class="mt-4 text-sm leading-6 text-gray-700 dark:text-gray-300">
        {@description}
      </p>
      {render_slot(@inner_block)}
      <ul class="mt-8 space-y-3 text-sm leading-6 text-gray-700 dark:text-gray-300 xl:mt-10">
        <%= for feature <- @features do %>
          <li class="flex gap-x-3">
            <svg
              class="flex-none w-6 h-6 text-black dark:text-white"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                clip-rule="evenodd"
              />
            </svg>

            <span>
              {feature}
              <.badge :if={future_check(feature)} color="warning" label="Future" class="ml-2" />
            </span>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr :id, :string
  attr :interval, :atom
  attr :amount, :integer
  attr :button_label, :string, default: "Pay Once"
  attr :button_props, :map, default: %{}
  attr :is_public, :boolean, default: false
  attr :is_current_plan, :boolean, default: false
  attr :is_already_paid, :boolean, default: false
  attr :most_popular, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :billing_path, :string, default: "/app/billing"

  def item_price(assigns) do
    ~H"""
    <div id={@id} x-bind:class={"{ 'hidden': interval != '#{@interval}' }"}>
      <p class="flex items-baseline mt-6 gap-x-1">
        <span class="text-4xl font-bold tracking-tight text-black dark:text-white">
          <%= case @interval do %>
            <% :one_time -> %>
              {@amount |> Util.format_money()}
            <% :year -> %>
              {(@amount / 12) |> ceil() |> Util.format_money()}
          <% end %>
        </span>
        <span class="text-sm font-semibold leading-6 text-gray-700 dark:text-gray-300">
          /
          <%= case @interval do %>
            <% :one_time -> %>
              {gettext("once")}
            <% :year -> %>
              {gettext("month (paid yearly)")}
          <% end %>
        </span>
      </p>

      <%= if @is_public do %>
        <.button
          color="light"
          class="w-full px-3 py-2 mt-6 text-sm font-semibold leading-6 text-center text-black bg-gray-200 border-none rounded-md hover:bg-gray-300 dark:text-white dark:bg-white/20 dark:hover:bg-white/30"
          label={@button_label}
          link_type="live_redirect"
          to={~p"/auth/register"}
        />
      <% else %>
        <%= if @is_already_paid do %>
          <.button
            to={@billing_path}
            link_type="live_redirect"
            label={@button_label}
            class="w-full mt-6"
            {@button_props}
            disabled={@disabled}
          />
        <% else %>
          <.button label={@button_label} class="w-full mt-6" {@button_props} />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp pricing_panels_container_css(1), do: ""
  defp pricing_panels_container_css(n), do: "lg:grid-cols-#{n}"

  defp future_check(feature) do
    cond do
      String.contains?(feature, "Roadmap") -> true
      String.contains?(feature, "organizations") -> true
      String.contains?(feature, "Live customer support") -> true
      true -> false
    end
  end
end
