defmodule MossletWeb.DataTable.Cell do
  @moduledoc false
  use Phoenix.Component

  import PetalComponents.Button

  def render(%{column: %{renderer: :checkbox}} = assigns) do
    ~H"""
    <%= if get_value(@item, @column) do %>
      <input type="checkbox" checked disabled />
    <% else %>
      <input type="checkbox" disabled />
    <% end %>
    """
  end

  def render(%{column: %{renderer: :date}} = assigns) do
    ~H"""
    {Calendar.strftime(get_value(@item, @column), @column[:date_format] || "%Y-%m-%d")}
    """
  end

  def render(%{column: %{renderer: :datetime}} = assigns) do
    ~H"""
    {Calendar.strftime(get_value(@item, @column), @column[:date_format] || "%I:%M%p %Y-%m-%d")}
    """
  end

  def render(%{column: %{renderer: :money}} = assigns) do
    ~H"""
    {parse_money(get_value(@item, @column), @column[:currency] || "USD") |> Money.to_string()}
    """
  end

  def render(%{column: %{renderer: :action_buttons}} = assigns) do
    ~H"""
    <%= for button <- @column.buttons.(@item) do %>
      <.button {button} />
    <% end %>
    """
  end

  # Plain text
  def render(assigns) do
    ~H"""
    {get_value(@item, @column)}
    """
  end

  defp parse_money(amount, currency) when is_integer(amount) do
    Money.new(amount * 100, currency)
  end

  defp parse_money(amount, currency) when is_float(amount) do
    amount |> Decimal.from_float() |> Money.parse!(currency)
  end

  defp parse_money(amount, currency) when is_binary(amount) do
    Money.parse!(amount, currency)
  end

  defp get_value(item, column) do
    cond do
      is_function(column[:renderer]) -> column.renderer.(item)
      !!column[:field] -> Map.get(item, column.field)
      true -> nil
    end
  end
end
