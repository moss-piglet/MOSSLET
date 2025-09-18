defmodule MossletWeb.LiquidEmailComponents do
  @moduledoc """
  Email components following the Mosslet liquid metal design system.

  These components maintain the liquid metal aesthetic while working
  within email client constraints. Uses inline styles for maximum
  compatibility across email clients.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  @doc """
  Liquid metal button for emails.

  ## Examples

      <.liquid_email_button to="/confirm">Confirm Account</.liquid_email_button>
      <.liquid_email_button to="/reset" color="red">Reset Password</.liquid_email_button>
  """
  attr :to, :string, required: true

  attr :color, :string,
    default: "teal",
    values: ~w(teal blue purple amber rose cyan indigo red green gray)

  attr :size, :string, default: "md", values: ~w(sm md lg)
  slot :inner_block, required: true

  def liquid_email_button(assigns) do
    ~H"""
    <a
      href={@to}
      style={liquid_button_styles(@color, @size)}
      target="_blank"
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc """
  Centered liquid email button.

  ## Examples

      <.liquid_email_button_centered to="/confirm">Confirm Account</.liquid_email_button_centered>
  """
  attr :to, :string, required: true

  attr :color, :string,
    default: "teal",
    values: ~w(teal blue purple amber rose cyan indigo red green gray)

  attr :size, :string, default: "md", values: ~w(sm md lg)
  slot :inner_block, required: true

  def liquid_email_button_centered(assigns) do
    ~H"""
    <.liquid_email_centered>
      <.liquid_email_button {assigns} />
    </.liquid_email_centered>
    """
  end

  @doc """
  Liquid metal PIN display for emails.

  ## Examples

      <.liquid_email_pin pin="123456" />
  """
  attr :pin, :string, required: true

  def liquid_email_pin(assigns) do
    ~H"""
    <.liquid_email_centered>
      <div style={liquid_pin_styles()}>
        {@pin}
      </div>
    </.liquid_email_centered>
    """
  end

  @doc """
  Centers content in email.
  """
  slot :inner_block, required: true

  def liquid_email_centered(assigns) do
    ~H"""
    <table
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
  Vertical spacing between email sections.
  """
  def liquid_email_gap(assigns) do
    ~H"""
    <div style="margin: 35px 0;"></div>
    """
  end

  @doc """
  Liquid metal card/box for emails.
  """
  slot :inner_block, required: true

  def liquid_email_card(assigns) do
    ~H"""
    <table class="attributes" width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <tr>
        <td style={liquid_card_styles()}>
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  @doc """
  Small text for disclaimers and notes.
  """
  slot :inner_block, required: true

  def liquid_email_small_text(assigns) do
    ~H"""
    <p style={liquid_small_text_styles()}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Top border section for email footer areas.
  """
  slot :inner_block, required: true

  def liquid_email_top_border(assigns) do
    ~H"""
    <table
      width="100%"
      role="presentation"
      style="margin-top: 25px; padding-top: 25px; border-top: 1px solid #E2E8F0;"
    >
      <tr>
        <td>
          {render_slot(@inner_block)}
        </td>
      </tr>
    </table>
    """
  end

  # Private helper functions for inline styles

  defp liquid_button_styles(color, size) do
    base_styles = """
    display: inline-block;
    text-decoration: none;
    border-radius: 9999px;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    -webkit-text-size-adjust: none;
    box-sizing: border-box;
    line-height: 1.625;
    font-weight: 600;
    transition: all 0.2s ease-out;
    """

    size_styles =
      case size do
        "sm" -> "font-size: 0.8rem; padding: 8px 16px;"
        "md" -> "font-size: 1rem; padding: 12px 24px;"
        "lg" -> "font-size: 1.2rem; padding: 16px 32px;"
      end

    color_styles =
      case color do
        "teal" -> "background: linear-gradient(to right, #14B8A6, #10B981); color: #FFFFFF;"
        "blue" -> "background: linear-gradient(to right, #3B82F6, #06B6D4); color: #FFFFFF;"
        "purple" -> "background: linear-gradient(to right, #8B5CF6, #7C3AED); color: #FFFFFF;"
        "amber" -> "background: linear-gradient(to right, #F59E0B, #F97316); color: #FFFFFF;"
        "rose" -> "background: linear-gradient(to right, #F43F5E, #EC4899); color: #FFFFFF;"
        "cyan" -> "background: linear-gradient(to right, #06B6D4, #14B8A6); color: #FFFFFF;"
        "indigo" -> "background: linear-gradient(to right, #6366F1, #3B82F6); color: #FFFFFF;"
        "red" -> "background: linear-gradient(to right, #DC2626, #EF4444); color: #FFFFFF;"
        "green" -> "background: linear-gradient(to right, #059669, #10B981); color: #FFFFFF;"
        "gray" -> "background: linear-gradient(to right, #4B5563, #6B7280); color: #FFFFFF;"
        _ -> "background: linear-gradient(to right, #14B8A6, #10B981); color: #FFFFFF;"
      end

    base_styles <> size_styles <> color_styles
  end

  defp liquid_pin_styles do
    """
    font-weight: bold;
    font-size: 24px;
    margin: 0;
    letter-spacing: 6px;
    padding: 20px 30px;
    background: linear-gradient(to right, #F0FDFA, #ECFDF5);
    border: 2px solid #14B8A6;
    border-radius: 12px;
    color: #065F46;
    display: inline-block;
    font-family: 'Inter', ui-monospace, monospace;
    """
  end

  defp liquid_card_styles do
    """
    background: linear-gradient(to bottom right, #F8FAFC, #F1F5F9);
    border: 1px solid #E2E8F0;
    border-radius: 12px;
    padding: 20px;
    color: #334155;
    """
  end

  defp liquid_small_text_styles do
    """
    font-size: 13px;
    color: #64748B;
    line-height: 1.5;
    margin: 0.4em 0 1.1875em;
    """
  end
end
