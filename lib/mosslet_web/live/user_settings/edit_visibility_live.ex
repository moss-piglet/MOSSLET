defmodule MossletWeb.EditVisibilityLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       form: to_form(Accounts.change_user_visibility(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={:edit_visibility} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Account Visibility
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Control who can view your profile and send you connection requests on MOSSLET.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <%!-- Visibility Settings Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
                  <.phx_icon name="hero-eye" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
                </div>
                <span>Privacy Settings</span>
                <%!-- Current visibility badge --%>
                <DesignSystem.liquid_badge
                  variant="soft"
                  color={visibility_badge_color(@current_user.visibility)}
                  size="sm"
                >
                  {String.capitalize(Atom.to_string(@current_user.visibility))}
                </DesignSystem.liquid_badge>
              </div>
            </:title>

            <.form
              id="change_visibility_form"
              for={@form}
              phx-submit="update_visibility"
              phx-change="validate_visibility"
              class="space-y-6"
            >
              <%!-- Current visibility status --%>
              <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
                <div class="flex items-center gap-3 mb-3">
                  <.phx_icon name="hero-information-circle" class="h-5 w-5 text-slate-500" />
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Current Status
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  {visibility_help_text(@current_user.visibility)}
                </p>
              </div>

              <%!-- Visibility selector --%>
              <DesignSystem.liquid_select
                field={@form[:visibility]}
                label="Change your account visibility"
                options={Ecto.Enum.values(User, :visibility)}
                help="Choose who can view your profile and send you connection requests"
              />

              <%!-- Dynamic help text for selected option --%>
              <div
                :if={@form[:visibility].value && @form[:visibility].value != @current_user.visibility}
                class="p-4 rounded-xl bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-700"
              >
                <div class="flex items-center gap-3 mb-3">
                  <.phx_icon
                    name="hero-arrow-right"
                    class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
                  />
                  <span class="text-sm font-medium text-emerald-900 dark:text-emerald-100">
                    New Setting Preview
                  </span>
                </div>
                <p class="text-sm text-emerald-700 dark:text-emerald-300">
                  {visibility_help_text(@form[:visibility].value)}
                </p>
              </div>

              <%!-- Action button --%>
              <div class="flex justify-end pt-4">
                <DesignSystem.liquid_button
                  type="submit"
                  phx-disable-with="Updating..."
                  icon="hero-check"
                  color="purple"
                  disabled={@form[:visibility].value == @current_user.visibility}
                >
                  Update Visibility
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Privacy explanation card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">Privacy Levels Explained</span>
              </div>
            </:title>

            <div class="space-y-6">
              <%!-- Public explanation --%>
              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <DesignSystem.liquid_badge variant="soft" color="blue" size="sm">
                    Public
                  </DesignSystem.liquid_badge>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Maximum Visibility
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 pl-4 border-l-2 border-blue-200 dark:border-blue-700">
                  Anyone can view your profile and send connection requests. Best for networking and meeting new people.
                </p>
              </div>

              <%!-- Connections explanation --%>
              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <DesignSystem.liquid_badge variant="soft" color="emerald" size="sm">
                    Connections
                  </DesignSystem.liquid_badge>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Balanced Privacy
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 pl-4 border-l-2 border-emerald-200 dark:border-emerald-700">
                  Only you and your connections can view your profile. Anyone can still send connection requests.
                </p>
              </div>

              <%!-- Private explanation --%>
              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <DesignSystem.liquid_badge variant="soft" color="rose" size="sm">
                    Private
                  </DesignSystem.liquid_badge>
                  <span class="text-sm font-medium text-slate-900 dark:text-slate-100">
                    Maximum Privacy
                  </span>
                </div>
                <p class="text-sm text-slate-600 dark:text-slate-400 pl-4 border-l-2 border-rose-200 dark:border-rose-700">
                  Only you can view your profile. No one can send connection requests, but you can still reach out to others.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
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

  defp visibility_badge_color(visibility) do
    case visibility do
      :public -> "blue"
      :connections -> "emerald"
      :private -> "rose"
      _ -> "slate"
    end
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
