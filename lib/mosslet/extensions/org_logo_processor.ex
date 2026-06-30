defmodule Mosslet.Extensions.OrgLogoProcessor do
  @moduledoc """
  A GenServer + named ETS table caching the ENCRYPTED (opaque) org brand-logo
  blobs (Task #228, #349).

  Mirrors `Mosslet.Extensions.AvatarProcessor`: the cached value is the raw
  org_key-secretbox CIPHERTEXT fetched from object storage — never the plaintext
  image (invariant I3). It is delivered to the browser inline (base64) so the
  member's browser decrypts it with the `org_key` it already holds, WITHOUT a
  cross-origin presigned fetch. This is why the logo now renders identically on
  the apex (`mosslet.com`) and on a branded subdomain (`acme.mosslet.com`): there
  is no Tigris CORS dependency.

  Cross-node invalidation rides PubSub topic `"org_logo_cache_global"` so that
  replacing/removing a logo on one instance drops the stale ciphertext on all of
  them; the next render re-fetches the fresh blob.
  """
  use GenServer

  @topic "org_logo_cache_global"

  ## Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Cache key for an org's logo blob."
  def key(org_id), do: "org-logo-#{org_id}"

  def put(key, blob) when is_binary(key) and is_binary(blob) do
    :ets.insert(__MODULE__, {key, blob})
  end

  def get(key) when is_binary(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def delete(key) when is_binary(key) do
    :ets.delete(__MODULE__, key)
  end

  @doc """
  Invalidates an org's cached logo blob locally AND on every other instance
  (PubSub fan-out), so a replace/remove takes effect everywhere immediately.
  """
  def invalidate(org_id) do
    delete(key(org_id))
    Phoenix.PubSub.broadcast(Mosslet.PubSub, @topic, {:org_logo_invalidated, org_id})
  end

  ## Server

  @impl true
  def init(_) do
    :ets.new(__MODULE__, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    Phoenix.PubSub.subscribe(Mosslet.PubSub, @topic)
    {:ok, nil}
  end

  @impl true
  def handle_info({:org_logo_invalidated, org_id}, state) do
    delete(key(org_id))
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
