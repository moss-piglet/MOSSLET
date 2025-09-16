defmodule MossletWeb.Components.MossletAuthLayout do
  @moduledoc """
  Modern auth layout component with liquid metal aesthetics and improved visual hierarchy.
  """
  use Phoenix.Component
  use PetalComponents, except: [:button]
  use MossletWeb, :verified_routes

  attr :conn, :any, required: true
  attr :title, :string, required: true

  slot :logo
  slot :top_right
  slot :inner_block, required: true

  def mosslet_auth_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900">
      <%!-- Background decorative elements --%>
      <div class="absolute inset-0 overflow-hidden">
        <%!-- Primary gradient orb --%>
        <div class="absolute -top-40 -right-32 h-96 w-96 rounded-full bg-gradient-to-br from-teal-400/20 via-emerald-500/15 to-cyan-400/20 blur-3xl animate-pulse">
        </div>
        <%!-- Secondary gradient orb --%>
        <div
          class="absolute -bottom-40 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
          style="animation-delay: -2s;"
        >
        </div>
        <%!-- Subtle pattern overlay --%>
        <div class="absolute inset-0 opacity-20 dark:opacity-10">
          <div
            class="h-full w-full"
            style="background-image: radial-gradient(circle at 50% 50%, rgba(20, 184, 166, 0.1) 1px, transparent 1px); background-size: 40px 40px;"
          >
          </div>
        </div>
      </div>

      <%!-- Top navigation bar --%>
      <nav class="relative z-20 flex items-center justify-between p-4 sm:p-6 lg:px-8">
        <div class="flex items-center">
          <.link navigate={~p"/"} class="transition-transform duration-200 hover:scale-105">
            {render_slot(@logo)}
          </.link>
        </div>
        <div class="flex items-center gap-4">
          {render_slot(@top_right)}
        </div>
      </nav>

      <%!-- Main content --%>
      <div class="relative z-10 flex min-h-[calc(100vh-80px)] sm:min-h-[calc(100vh-120px)] items-center justify-center px-0 py-4 sm:px-6 sm:py-8 lg:px-8">
        <div class="w-full max-w-md sm:max-w-lg">
          <%!-- Auth card with liquid metal styling --%>
          <div class={[
            "relative overflow-hidden backdrop-blur-sm",
            "bg-white/95 dark:bg-slate-800/95",
            "border-0 sm:border border-slate-200/60 dark:border-slate-700/60",
            "shadow-none sm:shadow-2xl sm:shadow-slate-900/10 dark:sm:shadow-slate-900/30",
            "rounded-none sm:rounded-2xl",
            "p-6 sm:p-8 lg:p-12",
            "min-h-[calc(100vh-80px)] sm:min-h-0"
          ]}>
            <%!-- Card shimmer effect --%>
            <div class="absolute inset-0 opacity-30">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent transform -skew-x-12 -translate-x-full animate-[shimmer_3s_ease-in-out_infinite]">
              </div>
            </div>

            <%!-- Card content --%>
            <div class="relative">
              {render_slot(@inner_block)}
            </div>

            <%!-- Decorative elements --%>
            <div class="absolute top-0 left-0 h-px w-full bg-gradient-to-r from-transparent via-emerald-500/20 to-transparent">
            </div>
            <div class="absolute bottom-0 right-0 h-px w-full bg-gradient-to-l from-transparent via-teal-500/20 to-transparent">
            </div>
          </div>
        </div>
      </div>

      <%!-- Custom shimmer animation --%>
      <style>
        @keyframes shimmer {
          0% { transform: translateX(-100%) skewX(-12deg); }
          100% { transform: translateX(200%) skewX(-12deg); }
        }
      </style>
    </div>
    """
  end
end
