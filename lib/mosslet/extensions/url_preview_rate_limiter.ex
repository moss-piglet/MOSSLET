defmodule Mosslet.Extensions.URLPreviewRateLimiter do
  @moduledoc """
  Rate limiting for URL preview fetches to prevent abuse.
  Uses ETS for fast, in-memory tracking of request counts per user.

  ## Rate Limits
  - Per Minute: 10 requests
  - Per Hour: 100 requests
  """

  @table_name :url_preview_rate_limit

  @per_minute_limit 10
  @per_hour_limit 100

  @doc """
  Initializes the ETS table for rate limiting.
  Should be called once during application startup.
  """
  def init() do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    :ok
  end

  @doc """
  Checks if a user is allowed to make a URL preview request.
  Returns :ok if allowed, {:error, reason} if rate limited.

  ## Parameters
    - user_id: The ID of the user making the request

  ## Examples

      iex> check_rate_limit(123)
      :ok

      iex> check_rate_limit(123)
      {:error, :rate_limit_exceeded}
  """
  def check_rate_limit(user_id) do
    now = System.system_time(:millisecond)
    minute_ago = now - 60_000
    hour_ago = now - 3_600_000

    case :ets.lookup(@table_name, user_id) do
      [] ->
        :ets.insert(@table_name, {user_id, [now]})
        :ok

      [{^user_id, timestamps}] ->
        recent_timestamps = Enum.filter(timestamps, &(&1 > hour_ago))
        minute_requests = Enum.count(recent_timestamps, &(&1 > minute_ago))
        hour_requests = length(recent_timestamps)

        cond do
          minute_requests >= @per_minute_limit ->
            {:error, :rate_limit_per_minute}

          hour_requests >= @per_hour_limit ->
            {:error, :rate_limit_per_hour}

          true ->
            updated_timestamps = [now | recent_timestamps]
            :ets.insert(@table_name, {user_id, updated_timestamps})
            :ok
        end
    end
  end

  @doc """
  Returns the current rate limit status for a user.
  Useful for displaying remaining requests to users.
  """
  def get_rate_limit_status(user_id) do
    now = System.system_time(:millisecond)
    minute_ago = now - 60_000
    hour_ago = now - 3_600_000

    case :ets.lookup(@table_name, user_id) do
      [] ->
        %{
          per_minute_remaining: @per_minute_limit,
          per_minute_limit: @per_minute_limit,
          per_hour_remaining: @per_hour_limit,
          per_hour_limit: @per_hour_limit
        }

      [{^user_id, timestamps}] ->
        recent_timestamps = Enum.filter(timestamps, &(&1 > hour_ago))
        minute_requests = Enum.count(recent_timestamps, &(&1 > minute_ago))
        hour_requests = length(recent_timestamps)

        %{
          per_minute_remaining: max(0, @per_minute_limit - minute_requests),
          per_minute_limit: @per_minute_limit,
          per_hour_remaining: max(0, @per_hour_limit - hour_requests),
          per_hour_limit: @per_hour_limit
        }
    end
  end

  @doc """
  Cleans up old entries from the rate limit table.
  Should be called periodically (e.g., every 5-10 minutes).
  """
  def cleanup_old_entries do
    now = System.system_time(:millisecond)
    hour_ago = now - 3_600_000

    @table_name
    |> :ets.tab2list()
    |> Enum.each(fn {user_id, timestamps} ->
      recent_timestamps = Enum.filter(timestamps, &(&1 > hour_ago))

      if recent_timestamps == [] do
        :ets.delete(@table_name, user_id)
      else
        :ets.insert(@table_name, {user_id, recent_timestamps})
      end
    end)

    :ok
  end
end
