defmodule Mosslet.Bluesky.RateLimiter do
  @moduledoc """
  Tracks Bluesky API rate limits from response headers.

  Uses :persistent_term for fast lock-free reads. Workers check
  `allow_request?/0` before making API calls and back off when
  rate-limited.

  ## Rate Limit Headers (AT Protocol)

    - `ratelimit-limit` - Total allowed requests in window
    - `ratelimit-remaining` - Requests remaining in window
    - `ratelimit-reset` - Unix timestamp when the window resets
    - `ratelimit-policy` - Policy description
  """

  require Logger

  @pt_key :bluesky_rate_limit

  @doc """
  Records rate limit info from response headers.
  """
  @spec record_headers(map() | list()) :: :ok
  def record_headers(headers) when is_map(headers) do
    remaining = parse_int_header(headers, "ratelimit-remaining")
    reset = parse_int_header(headers, "ratelimit-reset")
    limit = parse_int_header(headers, "ratelimit-limit")

    if remaining && reset do
      :persistent_term.put(@pt_key, %{
        remaining: remaining,
        reset: reset,
        limit: limit,
        recorded_at: System.system_time(:second)
      })
    end

    :ok
  end

  def record_headers(headers) when is_list(headers) do
    headers
    |> Map.new(fn {k, v} -> {k, v} end)
    |> record_headers()
  end

  def record_headers(_), do: :ok

  @doc """
  Returns true if a request is allowed based on last-known rate limit state.

  If we're out of remaining requests and the reset time hasn't passed yet,
  returns false.
  """
  @spec allow_request?() :: boolean()
  def allow_request? do
    case get_state() do
      %{remaining: 0, reset: reset} ->
        System.system_time(:second) >= reset

      _ ->
        true
    end
  end

  @doc """
  Returns milliseconds to wait before the next request is allowed.
  Returns 0 if no backoff is needed.
  """
  @spec backoff_ms() :: non_neg_integer()
  def backoff_ms do
    case get_state() do
      %{remaining: remaining, reset: reset} when remaining <= 5 ->
        now = System.system_time(:second)
        wait = max(0, reset - now)
        wait * 1_000

      _ ->
        0
    end
  end

  @doc """
  Returns the current rate limit state for monitoring/debugging.
  """
  @spec status() :: map() | nil
  def status, do: get_state()

  defp get_state do
    :persistent_term.get(@pt_key, nil)
  end

  defp parse_int_header(headers, key) do
    case Map.get(headers, key) do
      [val | _] when is_binary(val) -> parse_int(val)
      val when is_binary(val) -> parse_int(val)
      _ -> nil
    end
  end

  defp parse_int(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
end
