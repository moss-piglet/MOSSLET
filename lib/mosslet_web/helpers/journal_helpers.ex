defmodule MossletWeb.Helpers.JournalHelpers do
  @moduledoc """
  Privacy helper functions shared across journal LiveViews (Index, Entry, Book).
  Uses a shared GenServer to manage countdown state across LiveViews.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [get_connect_params: 1]

  alias Mosslet.Journal.PrivacyTimer

  def get_local_today(socket) do
    case get_connect_params(socket) do
      %{"timezone" => tz} when is_binary(tz) and tz != "" ->
        DateTime.utc_now()
        |> DateTime.shift_zone(tz)
        |> case do
          {:ok, local_dt} -> DateTime.to_date(local_dt)
          _ -> Date.utc_today()
        end

      _ ->
        Date.utc_today()
    end
  end

  def assign_privacy_state(socket, user) do
    if Phoenix.LiveView.connected?(socket) do
      PrivacyTimer.subscribe(user.id)
    end

    if user.journal_privacy_enabled do
      state = PrivacyTimer.get_state(user.id)

      if state.active do
        socket
        |> assign(:privacy_active, true)
        |> assign(:privacy_countdown, state.countdown)
        |> assign(:privacy_needs_password, state.needs_password)
      else
        socket
        |> assign(:privacy_active, true)
        |> assign(:privacy_countdown, 0)
        |> assign(:privacy_needs_password, true)
      end
    else
      socket
      |> assign(:privacy_active, false)
      |> assign(:privacy_countdown, 0)
      |> assign(:privacy_needs_password, false)
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
