defmodule Mosslet.Sync.Connectivity do
  @moduledoc """
  Online/offline detection for native desktop/mobile apps.

  Provides utilities for checking network connectivity and determining
  if the app should operate in offline mode. Works without authentication,
  useful for pre-login connectivity checks.

  ## Usage

  Check if online (unauthenticated):

      Mosslet.Sync.Connectivity.online?()

  Classify an error:

      case Mosslet.Sync.Connectivity.classify_error(error) do
        :offline -> "No internet connection"
        :server_unavailable -> "Server is temporarily unavailable"
        :client_error -> "Request error"
        :server_error -> "Server error"
        :unknown -> "Unknown error"
      end
  """

  alias Mosslet.API.Client

  @health_timeout 5_000

  @doc """
  Check if the device can reach the server.

  Makes a lightweight unauthenticated request to verify connectivity.
  Returns `true` if reachable, `false` otherwise.
  """
  def online? do
    case check_server() do
      :ok -> true
      {:error, _} -> false
    end
  end

  @doc """
  Perform a connectivity check against the server.

  Uses the `/api/health` endpoint which requires no authentication
  and minimal server-side processing.

  Returns `:ok` if server is reachable, `{:error, reason}` otherwise.
  """
  def check_server do
    url = Client.base_url() <> "/api/health"

    case Req.get(url, receive_timeout: @health_timeout) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, %{reason: reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Classify an error as network-related (offline) or server-related.

  ## Error Categories

  - `:offline` - Network errors, device cannot reach the internet
  - `:server_unavailable` - Server is down or overloaded (5xx, timeouts)
  - `:client_error` - Bad request, auth errors (4xx)
  - `:server_error` - Server-side errors (5xx)
  - `:unknown` - Unclassified error
  """
  def classify_error({:error, reason}), do: classify_error(reason)
  def classify_error(%{reason: reason}), do: classify_error(reason)

  def classify_error(reason)
      when reason in [:timeout, :econnrefused, :nxdomain, :ehostunreach, :enetunreach, :enotconn] do
    :offline
  end

  def classify_error({status, _body}) when status in [408, 502, 503, 504] do
    :server_unavailable
  end

  def classify_error({status, _body}) when status in 400..499 do
    :client_error
  end

  def classify_error({status, _body}) when status in 500..599 do
    :server_error
  end

  def classify_error(_), do: :unknown

  @doc """
  Returns a user-friendly message for an error category.
  """
  def error_message(:offline), do: "No internet connection"
  def error_message(:server_unavailable), do: "Server is temporarily unavailable"
  def error_message(:client_error), do: "Request error"
  def error_message(:server_error), do: "Server error, please try again later"
  def error_message(:unknown), do: "An unexpected error occurred"
end
