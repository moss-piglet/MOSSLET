defmodule MossletWeb.Helpers.JournalHelpers do
  @moduledoc """
  Shared helper functions across journal LiveViews (Index, Entry, Book).
  Includes privacy management, date helpers, and UI helpers.
  """

  import Phoenix.Component, only: [assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [get_connect_params: 1]

  alias Mosslet.Journal.PrivacyTimer

  def book_cover_gradient("emerald"), do: "bg-gradient-to-br from-emerald-500 to-teal-600"
  def book_cover_gradient("teal"), do: "bg-gradient-to-br from-teal-500 to-cyan-600"
  def book_cover_gradient("cyan"), do: "bg-gradient-to-br from-cyan-500 to-blue-600"
  def book_cover_gradient("blue"), do: "bg-gradient-to-br from-blue-500 to-indigo-600"
  def book_cover_gradient("violet"), do: "bg-gradient-to-br from-violet-500 to-purple-600"
  def book_cover_gradient("purple"), do: "bg-gradient-to-br from-purple-500 to-pink-600"
  def book_cover_gradient("pink"), do: "bg-gradient-to-br from-pink-500 to-rose-600"
  def book_cover_gradient("rose"), do: "bg-gradient-to-br from-rose-500 to-red-600"
  def book_cover_gradient("amber"), do: "bg-gradient-to-br from-amber-500 to-orange-600"
  def book_cover_gradient("orange"), do: "bg-gradient-to-br from-orange-500 to-red-600"
  def book_cover_gradient("yellow"), do: "bg-gradient-to-br from-yellow-400 to-amber-500"
  def book_cover_gradient(_), do: "bg-gradient-to-br from-slate-500 to-slate-600"

  def get_local_now(socket) do
    case get_connect_params(socket) do
      %{"timezone" => tz} when is_binary(tz) and tz != "" ->
        DateTime.utc_now()
        |> DateTime.shift_zone(tz)
        |> case do
          {:ok, local_dt} -> local_dt
          _ -> DateTime.utc_now()
        end

      _ ->
        DateTime.utc_now()
    end
  end

  def get_local_today(socket) do
    get_local_now(socket) |> DateTime.to_date()
  end

  def assign_privacy_state(socket, user) do
    if Phoenix.LiveView.connected?(socket) do
      PrivacyTimer.subscribe(user.id)
    end

    privacy_form = to_form(%{}, as: :privacy)

    if user.journal_privacy_enabled do
      state = PrivacyTimer.get_state(user.id)

      if state.active do
        socket
        |> assign(:privacy_active, true)
        |> assign(:privacy_countdown, state.countdown)
        |> assign(:privacy_needs_password, state.needs_password)
        |> assign(:privacy_form, privacy_form)
      else
        socket
        |> assign(:privacy_active, true)
        |> assign(:privacy_countdown, 0)
        |> assign(:privacy_needs_password, true)
        |> assign(:privacy_form, privacy_form)
      end
    else
      socket
      |> assign(:privacy_active, false)
      |> assign(:privacy_countdown, 0)
      |> assign(:privacy_needs_password, false)
      |> assign(:privacy_form, privacy_form)
    end
  end

  def handle_privacy_timer_update(socket, %{
        countdown: countdown,
        needs_password: needs_password,
        active: active
      }) do
    socket =
      socket
      |> assign(:privacy_active, active)
      |> assign(:privacy_countdown, countdown)
      |> assign(:privacy_needs_password, needs_password)
      |> update_user_privacy_enabled(active)

    if active do
      socket
    else
      Phoenix.LiveView.push_event(socket, "restore-body-scroll", %{})
    end
  end

  defp update_user_privacy_enabled(socket, active) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    updated_user = %{user | journal_privacy_enabled: active}
    updated_scope = %{current_scope | user: updated_user}
    assign(socket, :current_scope, updated_scope)
  end
end
