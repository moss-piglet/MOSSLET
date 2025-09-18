defmodule MossletWeb.EmailComponents do
  @moduledoc """
  A set of liquid metal styled components for use in HTML email templates.

  These components follow the Mosslet Design System principles while maintaining
  email client compatibility through inline styles and table-based layouts.

  See templates/email/template.html.heex for examples of component usage.
  """
  use Phoenix.Component

  @doc """
  Vertical spacing gap between email sections.

  ## Examples

      <.gap />
      <.gap size="lg" />
  """
  attr :size, :string, default: "md", values: ~w(sm md lg)

  def gap(assigns) do
    spacing =
      case assigns.size do
        "sm" -> "20px"
        "md" -> "35px"
        "lg" -> "50px"
      end

    assigns = assign(assigns, :spacing, spacing)

    ~H"""
    <div style={"margin: #{@spacing} 0;"}></div>
    """
  end

  @doc """
  Centers content in emails using table-based layout for maximum compatibility.

  ## Examples

      <.centered>
        <.button to="/action">Action Button</.button>
      </.centered>
  """
  slot :inner_block, required: true

  def centered(assigns) do
    ~H"""
    <table
      class="body-action"
      align="center"
      width="100%"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
      style="margin: 30px auto;"
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

  @doc """
  Liquid metal styled card/box component.

  ## Examples

      <.gray_box>
        <strong>Account Details:</strong><br />
        Username: johndoe<br />
        Email: john@example.com
      </.gray_box>
  """
  slot :inner_block, required: true

  def gray_box(assigns) do
    ~H"""
    <table class="liquid-card" width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td style="background: linear-gradient(145deg, #f8fafc, #f1f5f9); border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; color: #334155; position: relative; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);">
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  @doc """
  Dotted bordered card for special announcements or discount codes.

  ## Examples

      <.dotted_gray_box>
        <h1 class="align-center">10% off your next purchase!</h1>
        <p class="align-center">Use code WELCOME10</p>
        <.button_centered to="/shop">Shop Now</.button_centered>
      </.dotted_gray_box>
  """
  slot :inner_block, required: true

  def dotted_gray_box(assigns) do
    ~H"""
    <table
      class="discount"
      align="center"
      width="100%"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
      style="margin: 24px 0;"
    >
      <tr>
        <td
          style="background: linear-gradient(145deg, #f0fdf4, #ecfdf5); border: 2px dashed #14b8a6; border-radius: 12px; padding: 24px; color: #065f46; text-align: center; position: relative; box-shadow: 0 4px 14px 0 rgba(20, 184, 166, 0.15);"
          align="center"
        >
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  @doc """
  Top border section for dividing content areas.

  ## Examples

      <.top_border>
        <.small_text>
          If you're having trouble clicking the button, copy and paste this URL:
          <a href="/confirm">https://mosslet.com/confirm</a>
        </.small_text>
      </.top_border>
  """
  slot :inner_block, required: true

  def top_border(assigns) do
    ~H"""
    <table
      class="top-border"
      width="100%"
      role="presentation"
      style="margin-top: 30px; padding-top: 30px; border-top: 1px solid #e2e8f0; position: relative;"
    >
      <tr>
        <td>
          <div style="position: absolute; top: -1px; left: 50%; transform: translateX(-50%); width: 60px; height: 2px; background: linear-gradient(90deg, #14B8A6, #10B981);">
          </div>
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  @doc """
  Small text for disclaimers, notes, and secondary information.

  ## Examples

      <.small_text>
        This email was sent to you because you signed up for our service.
      </.small_text>
  """
  slot :inner_block, required: true

  def small_text(assigns) do
    ~H"""
    <p style="font-size: 13px; color: #64748B; line-height: 1.5; margin: 0.4em 0 1.1875em;">
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Liquid metal styled button component with gradient backgrounds.

  ## Examples

      <.button to="/confirm">Confirm Account</.button>
      <.button to="/reset" color="red" size="lg">Reset Password</.button>
      <.button to="/welcome" color="blue" size="sm">Get Started</.button>
  """
  attr :to, :string, required: true

  attr :color, :string,
    default: "teal",
    values: ~w(teal blue purple amber rose cyan indigo red green gray)

  attr :size, :string, default: "md", values: ~w(sm md lg)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <a
      href={@to}
      class={"liquid-button liquid-button--#{@color} liquid-button--#{@size}"}
      target="_blank"
      style="display: inline-block; text-decoration: none; border-radius: 12px; font-weight: 600; line-height: 1.5; position: relative; overflow: hidden; transition: all 0.2s ease-out;"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  Centered liquid metal button.

  ## Examples

      <.button_centered to="/confirm">Confirm Account</.button_centered>
      <.button_centered to="/reset" color="red">Reset Password</.button_centered>
  """
  attr :to, :string, required: true

  attr :color, :string,
    default: "teal",
    values: ~w(teal blue purple amber rose cyan indigo red green gray)

  attr :size, :string, default: "md", values: ~w(sm md lg)
  slot :inner_block, required: true

  def button_centered(assigns) do
    ~H"""
    <.centered>
      <.button {assigns} />
    </.centered>
    """
  end

  @doc """
  Liquid metal styled PIN display for authentication codes.

  ## Examples

      <.pin_display pin="123456" />
      <.pin_display pin="ABC123" />
  """
  attr :pin, :string, required: true

  def pin_display(assigns) do
    ~H"""
    <.centered>
      <div
        class="liquid-pin-display"
        style="background: linear-gradient(145deg, #F0FDFA, #ECFDF5); border: 2px solid #14B8A6; border-radius: 12px; padding: 20px 30px; font-family: 'Inter', ui-monospace, monospace; font-weight: 700; font-size: 24px; letter-spacing: 6px; color: #065F46; display: inline-block; margin: 20px 0; box-shadow: 0 4px 14px 0 rgba(20, 184, 166, 0.15);"
      >
        {@pin}
      </div>
    </.centered>
    """
  end

  @doc """
  Liquid metal accent line for visual separation.

  ## Examples

      <.accent_line />
      <.accent_line width="50%" />
  """
  attr :width, :string, default: "100%"

  def accent_line(assigns) do
    ~H"""
    <div style={"height: 2px; background: linear-gradient(90deg, #14B8A6, #10B981, #06B6D4); border-radius: 1px; margin: 20px auto; width: #{@width};"}>
    </div>
    """
  end

  @doc """
  Highlighted text with liquid metal styling.

  ## Examples

      <.highlight>Important information</.highlight>
      <.highlight color="amber">Warning message</.highlight>
  """
  attr :color, :string, default: "teal", values: ~w(teal blue purple amber rose cyan)
  slot :inner_block, required: true

  def highlight(assigns) do
    background_color =
      case assigns.color do
        "teal" -> "#F0FDFA"
        "blue" -> "#EFF6FF"
        "purple" -> "#FAF5FF"
        "amber" -> "#FFFBEB"
        "rose" -> "#FFF1F2"
        "cyan" -> "#ECFEFF"
        _ -> "#F0FDFA"
      end

    text_color =
      case assigns.color do
        "teal" -> "#065F46"
        "blue" -> "#1E3A8A"
        "purple" -> "#581C87"
        "amber" -> "#92400E"
        "rose" -> "#9F1239"
        "cyan" -> "#164E63"
        _ -> "#065F46"
      end

    assigns = assign(assigns, :background_color, background_color)
    assigns = assign(assigns, :text_color, text_color)

    ~H"""
    <span style={"background-color: #{@background_color}; color: #{@text_color}; padding: 4px 8px; border-radius: 6px; font-weight: 600; font-size: 14px;"}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Status indicator with liquid metal styling.

  ## Examples

      <.status type="success">Account Verified</.status>
      <.status type="warning">Action Required</.status>
      <.status type="error">Payment Failed</.status>
  """
  attr :type, :string, default: "info", values: ~w(success warning error info)
  slot :inner_block, required: true

  def status(assigns) do
    styles =
      case assigns.type do
        "success" ->
          "background: linear-gradient(145deg, #ECFDF5, #F0FDF4); border-left: 4px solid #10B981; color: #065F46;"

        "warning" ->
          "background: linear-gradient(145deg, #FFFBEB, #FEF3C7); border-left: 4px solid #F59E0B; color: #92400E;"

        "error" ->
          "background: linear-gradient(145deg, #FEF2F2, #FEE2E2); border-left: 4px solid #EF4444; color: #991B1B;"

        "info" ->
          "background: linear-gradient(145deg, #EFF6FF, #DBEAFE); border-left: 4px solid #3B82F6; color: #1E40AF;"

        _ ->
          "background: linear-gradient(145deg, #F8FAFC, #F1F5F9); border-left: 4px solid #64748B; color: #334155;"
      end

    assigns = assign(assigns, :styles, styles)

    ~H"""
    <div style={"#{@styles} padding: 16px; border-radius: 8px; margin: 16px 0; font-weight: 500;"}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
