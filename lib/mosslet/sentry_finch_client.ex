defmodule Mosslet.SentryFinchClient do
  @moduledoc """
  Custom Sentry HTTP client using Finch instead of hackney.

  This eliminates the hackney dependency for Sentry error reporting,
  using the existing Mosslet.Finch pool instead.
  """

  @behaviour Sentry.HTTPClient

  @impl true
  def child_spec do
    %{id: __MODULE__, start: {Function, :identity, [:ignore]}, type: :worker}
  end

  @impl true
  def post(url, headers, body) do
    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, Mosslet.Finch, receive_timeout: 30_000) do
      {:ok, %Finch.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, status, resp_headers, resp_body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
