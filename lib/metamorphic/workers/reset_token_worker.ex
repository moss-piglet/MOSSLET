defmodule Metamorphic.Workers.ResetTokenWorker do
  @moduledoc """
  Oban job for reseting tokens on a monthly basis.
  """
  use Oban.Worker, queue: :tokens
  alias Metamorphic.Accounts

  def perform(%Oban.Job{
        args: %{
          "user_id" => user_id,
          "tokens" => tokens,
          "interval" => interval
        }
      }) do
    user = Accounts.get_user!(user_id)

    reset_user_ai_tokens_used(user, tokens, interval)
  end

  defp reset_user_ai_tokens_used(user, tokens, interval) do
    case interval do
      "year" ->
        # Reset the tokens
        Accounts.update_user_tokens(user, %{ai_tokens: tokens, ai_tokens_used: 0})

        # Insert the job to run in a month
        schedule_next_job(user, tokens, interval)

        :ok

      _rest ->
        :ok
    end
  end

  defp schedule_next_job(user, tokens, interval) do
    keys = [:user_id, :interval]

    %{user_id: user.id, interval: interval, tokens: tokens}
    |> Metamorphic.Workers.ResetTokenWorker.new(
      schedule_in: 2_628_000,
      unique: [fields: [:args, :worker], keys: keys]
    )
    |> Oban.insert()
  end
end
