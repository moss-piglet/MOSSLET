defmodule Mosslet.BackgroundTask do
  @moduledoc """
  Run a function in a separate process parallel to the current one. Useful for things that take a bit of time but you want to send a response back quickly.

  Mosslet.BackgroundTask.run(fn ->
    do_some_time_instensive_stuff()
  end)

  """

  # adjust the timeout if the background task is expected to run longer than 5 seconds
  @shutdown_timeout_ms 5_000

  def run(f) do
    # Tests were failing when a background task was run. Hence in test mode we just run the function syncronously
    if Mosslet.config(:env) != :test || Mosslet.config(:force_async_background_task) do
      # Docs: https://hexdocs.pm/elixir/Task.html#module-dynamically-supervised-tasks
      Task.Supervisor.start_child(
        __MODULE__,
        fn ->
          Process.flag(:trap_exit, true)

          f.()
        end,
        restart: :transient,
        shutdown: @shutdown_timeout_ms
      )
    else
      f.()
    end
  end
end
