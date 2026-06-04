defmodule Mosslet.ObanReporter do
  @moduledoc false
  require Logger

  def attach do
    :telemetry.attach("oban-errors", [:oban, :job, :exception], &__MODULE__.handle_event/4, [])
  end

  def handle_event([:oban, :job, :exception], measure, meta, _) do
    extra =
      meta.job
      |> Map.take([:id, :meta, :queue, :worker])
      |> Map.merge(measure)

    Logger.error(
      "Oban job exception: #{Exception.format(:error, meta.reason, meta.stacktrace)}\n" <>
        "context: #{inspect(extra)}"
    )
  end
end
