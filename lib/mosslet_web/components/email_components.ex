defmodule MossletWeb.EmailComponents do
  @moduledoc """
  A set of html components for use in html email templates. Similar to petal_components but for email templates.
  See templates/email/template.html.heex for examples on what you can add to emails.
  """
  use Phoenix.Component

  # When you want some vertical space
  def gap(assigns) do
    ~H"""
    <div style="margin: 35px 0;"></div>
    """
  end

  # Use this to center something like a button.
  # <.centered><button /></.centered>

  slot(:inner_block)

  def centered(assigns) do
    ~H"""
    <table
      class="body-action"
      align="center"
      width="100%"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
    >
      <tr>
        <td align="center">
          <table width="100%" border="0" cellspacing="0" cellpadding="0" role="presentation">
            <tr>
              <td align="center">
                {render_slot(@inner_block)}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    """
  end

  slot(:inner_block)

  def gray_box(assigns) do
    ~H"""
    <table class="attributes" width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td class="attributes_content">
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  slot(:inner_block)

  def dotted_gray_box(assigns) do
    ~H"""
    <table
      class="discount"
      align="center"
      width="100%"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
    >
      <tr>
        <td class="f-fallback" align="center">
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  slot(:inner_block)

  def top_border(assigns) do
    ~H"""
    <table class="top-border" width="100%" role="presentation">
      <tr>
        <td>
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  slot(:inner_block)

  def small_text(assigns) do
    ~H"""
    <p class="sub">
      {render_slot(@inner_block)}
    </p>
    """
  end

  attr :to, :string, required: true
  attr :color, :string, default: "blue", values: ["blue", "green", "red"]
  attr :size, :string, default: "md", values: ["sm", "md", "lg"]
  slot(:inner_block)

  def button(assigns) do
    ~H"""
    <a href={@to} class={"f-fallback button button--#{@color} button--#{@size}"} target="_blank">
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :to, :string, required: true
  attr :color, :string, default: "blue", values: ["blue", "green", "red"]
  attr :size, :string, default: "md", values: ["sm", "md", "lg"]
  slot(:inner_block)

  def button_centered(assigns) do
    ~H"""
    <.centered>
      <.button {assigns} />
    </.centered>
    """
  end
end
