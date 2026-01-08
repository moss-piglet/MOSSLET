defmodule Mosslet.Journal.PrivacyTimer do
  @moduledoc """
  GenServer that manages the privacy countdown timer for a user's journal.
  Each user has their own timer process, started on-demand and identified via Registry.
  """
  use GenServer

  @registry Mosslet.Journal.PrivacyTimerRegistry
  @supervisor Mosslet.Journal.PrivacyTimerSupervisor
  @countdown_seconds 30
  @pubsub Mosslet.PubSub

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, user_id, name: via_tuple(user_id))
  end

  def activate(user_id) do
    case ensure_started(user_id) do
      {:ok, pid} -> GenServer.call(pid, :activate)
      {:error, reason} -> {:error, reason}
    end
  end

  def deactivate(user_id) do
    case lookup(user_id) do
      {:ok, pid} -> GenServer.call(pid, :deactivate)
      :not_found -> :ok
    end
  end

  def get_state(user_id) do
    case lookup(user_id) do
      {:ok, pid} -> GenServer.call(pid, :get_state)
      :not_found -> %{countdown: 0, needs_password: false, active: false}
    end
  end

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  defp topic(user_id), do: "journal_privacy:#{user_id}"

  defp via_tuple(user_id) do
    {:via, Registry, {@registry, user_id}}
  end

  defp lookup(user_id) do
    case Registry.lookup(@registry, user_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :not_found
    end
  end

  defp ensure_started(user_id) do
    case lookup(user_id) do
      {:ok, pid} ->
        {:ok, pid}

      :not_found ->
        case DynamicSupervisor.start_child(@supervisor, {__MODULE__, user_id}) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @impl true
  def init(user_id) do
    {:ok,
     %{
       user_id: user_id,
       countdown: 0,
       needs_password: false,
       active: false,
       timer_ref: nil
     }}
  end

  @impl true
  def handle_call(:activate, _from, state) do
    state = cancel_timer(state)

    timer_ref = Process.send_after(self(), :tick, 1000)

    new_state = %{
      state
      | countdown: @countdown_seconds,
        needs_password: false,
        active: true,
        timer_ref: timer_ref
    }

    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:deactivate, _from, state) do
    state = cancel_timer(state)

    new_state = %{
      state
      | countdown: 0,
        needs_password: false,
        active: false,
        timer_ref: nil
    }

    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply,
     %{
       countdown: state.countdown,
       needs_password: state.needs_password,
       active: state.active
     }, state}
  end

  @impl true
  def handle_info(:tick, state) do
    countdown = state.countdown - 1

    new_state =
      if countdown <= 0 do
        %{state | countdown: 0, needs_password: true, timer_ref: nil}
      else
        timer_ref = Process.send_after(self(), :tick, 1000)
        %{state | countdown: countdown, timer_ref: timer_ref}
      end

    broadcast(new_state)
    {:noreply, new_state}
  end

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(state.user_id),
      {:privacy_timer_update,
       %{
         countdown: state.countdown,
         needs_password: state.needs_password,
         active: state.active
       }}
    )
  end
end
