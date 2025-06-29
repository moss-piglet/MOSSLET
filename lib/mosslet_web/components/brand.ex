defmodule MossletWeb.Components.Brand do
  @moduledoc false
  use Phoenix.Component

  @doc "Displays your full logo. "
  def logo(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "h-16" end)
      |> assign_new(:variant, fn -> nil end)

    ~H"""
    <%= if @variant do %>
      <img class={@class} src={"/images/logo_#{@variant}.svg"} />
    <% else %>
      <img class={@class <> " block dark:hidden"} src="/images/logo_dark.svg" />
      <img class={@class <> " hidden dark:block"} src="/images/logo_light.svg" />
    <% end %>
    """
  end

  @doc "Displays just the icon part of your logo"
  def logo_icon(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "h-9 w-9" end)
      |> assign_new(:variant, fn -> nil end)

    ~H"""
    <%= if @variant do %>
      <img class={@class} src={"/images/logo_icon_#{@variant}.svg"} />
    <% else %>
      <img class={@class <> " block dark:hidden"} src="/images/logo_icon_dark.svg" />
      <img class={@class <> " hidden dark:block"} src="/images/logo_icon_light.svg" />
    <% end %>
    """
  end

  def logo_for_emails(assigns) do
    ~H"""
    <img height="60" src={Mosslet.config(:logo_url_for_emails)} />
    """
  end
end
