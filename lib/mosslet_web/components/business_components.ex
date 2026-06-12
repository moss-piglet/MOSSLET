defmodule MossletWeb.BusinessComponents do
  @moduledoc """
  Shared UI components for the Business (org-scoped circles) feature.

  Business orgs do NOT use guardianship — only the `:admin`/`:member` org roles
  matter here. See `docs/BUSINESS_CIRCLES_DESIGN.md`.
  """
  use Phoenix.Component

  attr :role, :atom, required: true

  def business_role_badge(assigns) do
    {label, classes} =
      case assigns.role do
        :admin ->
          {"Admin", "bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-300"}

        _ ->
          {"Member", "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium",
      @classes
    ]}>
      {@label}
    </span>
    """
  end
end
