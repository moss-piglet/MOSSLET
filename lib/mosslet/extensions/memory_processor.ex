defmodule Mosslet.Extensions.MemoryProcessor do
  @moduledoc """
  A GenServer to handle the temp storage of
  people's encrypted memories.
  """
  use GenServer

  ## Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put_ets_memory(key, value) do
    :ets.insert(__MODULE__, {key, value})
  end

  def get_ets_memory(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def delete_ets_memory(key) do
    :ets.delete(__MODULE__, key)
  end

  ## Server
  def init(_) do
    :ets.new(__MODULE__, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # schedule_sweep()
    {:ok, nil}
  end

  # def handle_info(:sweep, state) do
  #  :ets.delete_all_objects(@tab)
  #  schedule_sweep()
  #  {:noreply, state}
  # end

  # defp schedule_sweep do
  #  Process.send_after(self(), :sweep, @sweep_after)
  # end
end
