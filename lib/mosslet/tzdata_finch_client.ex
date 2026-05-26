defmodule Mosslet.TzdataFinchClient do
  @moduledoc """
  Custom Tzdata HTTP client using Finch instead of hackney.

  Configured via:

      config :tzdata, :http_client, Mosslet.TzdataFinchClient

  This eliminates tzdata's hard dependency on hackney for tz database downloads.
  """

  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, headers, options) do
    finch_headers = normalize_headers(headers)
    request = Finch.build(:get, url, finch_headers)

    case do_request(request, options) do
      {:ok, %Finch.Response{status: status, headers: resp_headers, body: body}} ->
        {:ok, {status, resp_headers, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def head(url, headers, options) do
    finch_headers = normalize_headers(headers)
    request = Finch.build(:head, url, finch_headers)

    case do_request(request, options) do
      {:ok, %Finch.Response{status: status, headers: resp_headers}} ->
        {:ok, {status, resp_headers}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_request(request, options) do
    follow_redirect? = Keyword.get(options, :follow_redirect, false)

    case Finch.request(request, Mosslet.Finch, receive_timeout: 60_000) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}}
      when status in [301, 302, 303, 307, 308] and follow_redirect? ->
        case List.keyfind(headers, "location", 0) do
          {_, location} ->
            redirect_request = Finch.build(:get, location, [])
            Finch.request(redirect_request, Mosslet.Finch, receive_timeout: 60_000)

          nil ->
            {:ok, %Finch.Response{status: status, headers: headers, body: body}}
        end

      result ->
        result
    end
  end

  defp normalize_headers(headers) do
    Enum.map(headers, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
