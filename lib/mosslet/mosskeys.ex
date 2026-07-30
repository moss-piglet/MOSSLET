defmodule Mosslet.Mosskeys do
  @moduledoc """
  Client for the mosskeys write API.

  Publishes key rotation events and signed checkpoints to the configured
  mosskeys namespace via the POST API. All requests authenticate with a
  namespace-scoped bearer token (`MOSSKEYS_NAMESPACE_TOKEN`).
  """

  require Logger

  @base_path "/api"

  @doc """
  Publishes a user's public key to the transparency log.

  The `entry_json` is the signed key-history entry blob produced by the browser
  (which includes `enc_x25519`, `enc_pq`, and `sign_pub` fields).
  `signing_public_key` is used as a fallback for `signing_pub`.

  Returns `{:ok, index}` on success, `{:error, reason}` otherwise.
  """
  def publish_key(label, entry_json, signing_public_key \\ nil) do
    entry = decode_entry(entry_json)

    body = %{
      label: label,
      enc_x25519: entry["enc_x25519"] || "",
      enc_pq: entry["enc_pq"] || "",
      signing_pub: signing_public_key || entry["sign_pub"] || ""
    }

    with {:ok, token} <- namespace_token(),
         {:ok, resp} <- post("/log/entries", token, json: body) do
      case resp do
        %{status: 200, body: %{"index" => index}} -> {:ok, index}
        resp -> {:error, resp.status}
      end
    end
  end

  @doc """
  Phase 1 of checkpoint signing: asks mosskeys for the current tree head.

  Returns `{:ok, %{origin: origin, size: size, root: root}}`.
  """
  def request_checkpoint_head do
    with {:ok, token} <- namespace_token(),
         {:ok, resp} <- post("/log/checkpoints", token) do
      case resp do
        %{status: 200, body: body} when is_map(body) ->
          {:ok, %{origin: body["origin"], size: body["size"], root: body["root"]}}

        resp ->
          {:error, resp.status}
      end
    end
  end

  @doc """
  Phase 2 of checkpoint signing: publishes a signed checkpoint note.

  Returns `:ok` on success, `{:error, reason}` otherwise.
  """
  def publish_checkpoint(note_text) when is_binary(note_text) do
    with {:ok, token} <- namespace_token(),
         {:ok, resp} <- post("/log/checkpoints", token, json: %{note_text: note_text}) do
      case resp do
        %{status: 201} -> :ok
        resp -> {:error, resp.status}
      end
    end
  end

  defp post(path, token, opts \\ []) do
    url = api_url() <> @base_path <> path

    base_opts = [
      method: :post,
      url: url,
      auth: {:bearer, token},
      receive_timeout: 10_000
    ]

    case Req.request(base_opts ++ Keyword.take(opts, [:json])) do
      {:ok, response} ->
        Logger.debug("[Mosskeys] POST #{url} -> #{response.status}")
        {:ok, response}

      {:error, reason} ->
        Logger.warning("[Mosskeys] POST #{url} failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp api_url do
    Application.fetch_env!(:mosslet, :mosskeys_api_url)
  end

  defp namespace_token do
    case System.fetch_env("MOSSKEYS_NAMESPACE_TOKEN") do
      {:ok, token} when token != "" -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp decode_entry(nil), do: %{}

  defp decode_entry(entry) when is_binary(entry) do
    case Jason.decode(entry) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  defp decode_entry(_), do: %{}
end
