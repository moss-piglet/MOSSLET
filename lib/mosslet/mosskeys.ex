defmodule Mosslet.Mosskeys do
  @moduledoc """
  Client for the mosskeys transparency-log API of the configured namespace
  (`:mosskeys_namespace_slug`, default `"mosslet"`).

  WRITE (owner-scoped, bearer-authenticated with `MOSSKEYS_NAMESPACE_TOKEN`):

    * `publish_key/3` — appends a user's public key material as a leaf
      (`POST /api/:slug/log/entries`). Idempotent server-side on the content
      `dedup_key`, so retries never duplicate a leaf.
    * `request_checkpoint_head/0` + `publish_checkpoint/1` — the two-phase
      client-signing checkpoint handshake (`POST /api/:slug/log/checkpoints`).

  READ (public, unauthenticated — the log's verifier-facing surface):

    * `fetch_latest_checkpoint/0` — the latest signed checkpoint (tree head),
      used by the checkpoint worker to sign only when the tree has advanced.
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
          {:ok,
           %{
             origin: body["origin"],
             name: body["name"] || body["origin"],
             size: body["size"],
             root: body["root"]
           }}

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

  @doc """
  Fetches the latest signed checkpoint from the namespace's PUBLIC read API
  (no bearer token — this is the log's verifier-facing surface).

  Returns `{:ok, %{origin, size, root, note, cosigners}}`, `{:error, :not_found}`
  when no checkpoint has been published yet, or `{:error, reason}`.
  """
  def fetch_latest_checkpoint do
    case get("/checkpoint") do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok,
         %{
           origin: body["origin"],
           size: body["size"],
           root: body["root"],
           note: body["note"],
           cosigners: body["cosigners"] || []
         }}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, resp} ->
        {:error, resp.status}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  The fully-qualified API URL for a namespace path. Exposed for tests and for
  the checkpoint worker's logging.
  """
  def api_url(path \\ "") do
    Application.fetch_env!(:mosslet, :mosskeys_api_url) <>
      @base_path <> "/" <> namespace_slug() <> path
  end

  defp post(path, token, opts \\ []) do
    url = api_url(path)

    base_opts = [
      method: :post,
      url: url,
      auth: {:bearer, token},
      receive_timeout: 10_000
    ]

    case Req.request(base_opts ++ Keyword.take(opts, [:json]) ++ req_test_options()) do
      {:ok, response} ->
        Logger.debug("[Mosskeys] POST #{url} -> #{response.status}")
        {:ok, response}

      {:error, reason} ->
        Logger.warning("[Mosskeys] POST #{url} failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get(path) do
    url = api_url(path)

    case Req.get(url, [receive_timeout: 10_000] ++ req_test_options()) do
      {:ok, response} ->
        Logger.debug("[Mosskeys] GET #{url} -> #{response.status}")
        {:ok, response}

      {:error, reason} ->
        Logger.warning("[Mosskeys] GET #{url} failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Test seam: extra Req options (e.g. a `plug:` stub) injected only in the
  # test environment via Application env. Empty everywhere else.
  defp req_test_options do
    Application.get_env(:mosslet, :mosskeys_req_options, [])
  end

  defp namespace_slug do
    Application.get_env(:mosslet, :mosskeys_namespace_slug, "mosslet")
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
