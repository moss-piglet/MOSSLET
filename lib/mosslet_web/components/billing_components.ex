defmodule MossletWeb.BillingComponents do
  @moduledoc false
  use Phoenix.Component
  use MossletWeb, :verified_routes
  use PetalComponents

  use Gettext, backend: MossletWeb.Gettext

  import MossletWeb.DesignSystem
  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  attr :panels, :integer, default: 3
  attr :interval_selector, :boolean, default: false
  attr :rest, :global
  slot :default

  def pricing_panels_container(assigns) do
    ~H"""
    <div x-data="{ interval: 'one_time' }">
      <div :if={@interval_selector} class="flex justify-center mb-8">
        <div class="relative p-1 rounded-full overflow-hidden bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30">
          <%!-- Liquid metal shimmer background --%>
          <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
          </div>

          <label
            class="relative flex items-center justify-center px-6 py-2 rounded-full cursor-pointer text-sm font-semibold transition-all duration-200 ease-out transform-gpu"
            @click="interval = 'one_time'"
            x-bind:class="{
              'bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg shadow-emerald-500/25': interval == 'one_time',
              'text-slate-600 dark:text-slate-300 hover:text-emerald-600 dark:hover:text-emerald-400': interval != 'one_time'
            }"
          >
            <input type="radio" name="frequency" value="personal" class="sr-only" />
            <span class="relative z-10">Personal</span>
          </label>
        </div>
      </div>

      <div
        {@rest}
        class={[
          "grid max-w-md grid-cols-1 gap-8 mx-auto isolate",
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
    <.liquid_card
      class={[
        "relative overflow-hidden transition-all duration-300 ease-out transform-gpu",
        "hover:scale-105 hover:shadow-2xl hover:shadow-emerald-500/20",
        if(@most_popular,
          do: "ring-2 ring-emerald-500 dark:ring-emerald-400 shadow-2xl shadow-emerald-500/30",
          else: "hover:ring-1 hover:ring-emerald-200 dark:hover:ring-emerald-800"
        ),
        if(@disabled, do: "opacity-60 cursor-not-allowed"),
        @class
      ]}
      padding="lg"
      {@rest}
    >
      <%!-- Most Popular Badge --%>
      <div :if={@most_popular} class="absolute -top-3 -right-3">
        <div class="inline-flex items-center px-4 py-2 rounded-full bg-gradient-to-r from-amber-500 to-orange-500 text-white text-sm font-semibold shadow-lg shadow-amber-500/30 transform rotate-12">
          <.phx_icon name="hero-star" class="w-4 h-4 mr-1" />
          {gettext("Most Popular")}
        </div>
      </div>

      <%!-- Liquid shimmer effect on hover --%>
      <div class={[
        "absolute inset-0 opacity-0 transition-all duration-500 ease-out transform-gpu",
        "bg-gradient-to-r from-transparent via-emerald-200/20 to-transparent",
        "dark:via-emerald-400/10",
        "group-hover:opacity-100 hover:opacity-100 hover:translate-x-full -translate-x-full"
      ]}>
      </div>

      <div class="relative z-10">
        <div class="flex items-center justify-between gap-x-4 mb-4">
          <h3 class="text-xl font-bold leading-8 text-slate-900 dark:text-slate-100">
            {@label}
          </h3>
          <div class="inline-flex items-center px-3 py-1 rounded-full bg-gradient-to-r from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30 text-amber-700 dark:text-amber-300 text-sm font-semibold">
            <.phx_icon name="hero-fire" class="w-4 h-4 mr-1" /> Save 40%
          </div>
        </div>

        <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-6">
          {@description}
        </p>

        {render_slot(@inner_block)}

        <ul class="mt-8 space-y-4">
          <%= for feature <- @features do %>
            <li class="flex items-start gap-x-3">
              <div class="flex-shrink-0 w-6 h-6 rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30 flex items-center justify-center mt-0.5">
                <.phx_icon
                  name="hero-check"
                  class="w-4 h-4 text-emerald-600 dark:text-emerald-400"
                />
              </div>
              <span class="text-slate-700 dark:text-slate-300 leading-relaxed">
                {feature}
                <span
                  :if={future_check(feature)}
                  class="inline-flex items-center px-2 py-0.5 rounded-full bg-gradient-to-r from-blue-100 to-cyan-100 dark:from-blue-900/30 dark:to-cyan-900/30 text-blue-700 dark:text-blue-300 text-xs font-medium ml-2"
                >
                  <.phx_icon name="hero-clock" class="w-3 h-3 mr-1" /> Future
                </span>
              </span>
            </li>
          <% end %>
        </ul>
      </div>
    </.liquid_card>
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
      <div class="flex items-baseline gap-x-2 mt-6 mb-8">
        <span class="text-5xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
          <%= case @interval do %>
            <% :one_time -> %>
              {@amount |> Util.format_money()}
            <% :year -> %>
              {(@amount / 12) |> ceil() |> Util.format_money()}
          <% end %>
        </span>
        <span class="text-lg font-medium text-slate-600 dark:text-slate-400">
          /
          <%= case @interval do %>
            <% :one_time -> %>
              {gettext("once")}
            <% :year -> %>
              {gettext("month (paid yearly)")}
          <% end %>
        </span>
      </div>

      <%= if @is_public do %>
        <.liquid_button
          variant="secondary"
          size="lg"
          href={~p"/auth/register"}
          class="w-full"
        >
          {@button_label}
        </.liquid_button>
      <% else %>
        <%= if @is_already_paid do %>
          <.liquid_button
            variant="primary"
            size="lg"
            navigate={@billing_path}
            class="w-full"
            icon="hero-check-circle"
            disabled={@disabled}
            {@button_props}
          >
            {@button_label}
          </.liquid_button>
        <% else %>
          <.liquid_button
            variant="primary"
            size="lg"
            class="w-full"
            icon="hero-credit-card"
            disabled={@disabled}
            {@button_props}
          >
            {@button_label}
          </.liquid_button>
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
