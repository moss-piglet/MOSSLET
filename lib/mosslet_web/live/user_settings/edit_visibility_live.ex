defmodule MossletWeb.EditVisibilityLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       form: to_form(Accounts.change_user_visibility(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_visibility} current_user={@current_user} key={@key}>
      <.form
        id="change_visibility_form"
        for={@form}
        phx-submit="update_visibility"
        phx-change="validate_visibility"
      >
        <.field
          type="select"
          field={@form[:visibility]}
          options={Ecto.Enum.values(User, :visibility)}
          label={gettext("Change your account visibility")}
          autocomplete="visibility"
          help_text={visibility_help_text(@form[:visibility].value)}
          {alpine_autofocus()}
        />

        <div class="flex justify-end">
          <.button class="rounded-full">{gettext("Change visibility")}</.button>
        </div>
      </.form>
    </.settings_layout>
    """
  end

  def handle_event("validate_visibility", %{"user" => user_params}, socket) do
    form =
      socket.assigns.current_user
      |> Accounts.change_user_visibility(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("update_visibility", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_visibility(user, user_params, key: socket.assigns.key) do
      {:ok, user} ->
        visibility_form =
          user
          |> Accounts.change_user_visibility(user_params)
          |> to_form()

        info = "Your visibility has been updated successfully."

        {:noreply,
         socket
         |> put_flash(:success, info)
         |> assign(visibility_form: visibility_form)
         |> push_navigate(to: ~p"/app/users/edit-visibility")}

      {:error, changeset} ->
        info = "Visibility did not change."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> assign(visibility_form: to_form(changeset))
         |> push_navigate(to: ~p"/app/users/edit-visibility")}
    end
  end

  def valid_visibility_atoms do
    [:connections, :public, :private]
  end

  defp visibility_help_text(value) when is_atom(value) do
    case value do
      :connections ->
        "Mosslet users can send you connection requests and only you and your connections can view your profile."

      :public ->
        "Mosslet users can send you connection requests and anyone can view your profile."

      :private ->
        "No one can send you connection requests and only you can view your profile. You can still send connection requests and make new connections."

      _rest ->
        "This is not a valid visibility setting."
    end
  end

  defp visibility_help_text(value) when is_binary(value) do
    case String.to_existing_atom(value) do
      :connections ->
        "Mosslet users can send you connection requests and only you and your connections can view your profile."

      :public ->
        "Mosslet users can send you connection requests and anyone can view your profile."

      :private ->
        "No one can send you connection requests and only you can view your profile. You can still send connection requests and make new connections."

      _rest ->
        "This is not a valid visibility setting."
    end
  end
end
