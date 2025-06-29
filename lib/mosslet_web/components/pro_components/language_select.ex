defmodule MossletWeb.LanguageSelect do
  @moduledoc false
  use Phoenix.Component

  import PetalComponents.Dropdown

  @doc """
  Usage:
  <.language_select
    current_locale={Gettext.get_locale(YourAppWeb.Gettext)}
    language_options={YourApp.config(:language_options)}
  />
  """

  attr :current_path, :string
  attr :current_locale, :string
  attr :language_options, :list, doc: "list of maps with keys :locale, :flag (emoji), :label"

  def language_select(assigns) do
    assigns = assign_new(assigns, :current_path, fn -> "" end)

    ~H"""
    <.dropdown>
      <:trigger_element>
        <div class="inline-flex items-center justify-center w-full gap-1 align-middle focus:outline-none">
          <div class="text-2xl">
            {Enum.find(@language_options, &(&1.locale == @current_locale)).flag}
          </div>
          <MossletWeb.CoreComponents.phx_icon
            name="hero-chevron-down-mini"
            class="w-4 h-4 text-gray-400 dark:text-gray-100"
          />
        </div>
      </:trigger_element>
      <%= for language <- @language_options do %>
        <.dropdown_menu_item link_type="a" to={@current_path <> "?locale=#{language.locale}"}>
          <div class="mr-2 text-2xl leading-none">{language.flag}</div>
          <div>{language.label}</div>
        </.dropdown_menu_item>
      <% end %>
    </.dropdown>
    """
  end
end
