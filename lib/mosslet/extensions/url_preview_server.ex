defmodule Mosslet.Extensions.URLPreviewServer do
  use GenServer
  require Logger

  alias Mosslet.Encrypted.Utils

  @table_name :url_preview_cache
  @cache_ttl :timer.hours(24)
  @cleanup_interval :timer.minutes(30)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, state}
  end

  @doc """
  Simple fetch - fetches URL metadata without encryption
  Returns plain preview data for display in LiveView forms
  """
  def fetch(url, timeout \\ 5_000) do
    GenServer.call(__MODULE__, {:fetch, url}, timeout)
  end

  @doc """
  Async fetch - returns immediately, broadcasts result via PubSub
  """
  def fetch_async(url, context) do
    GenServer.cast(__MODULE__, {:fetch, url, context})
  end

  @doc """
  Sync fetch and cache - fetches URL metadata, encrypts with post_key, and caches by post_id
  Returns encrypted preview data ready for database storage
  """
  def fetch_and_cache(url, post_id, post_key, timeout \\ 5_000) do
    GenServer.call(__MODULE__, {:fetch_and_cache, url, post_id, post_key}, timeout)
  end

  @doc """
  Get cached encrypted preview by post_id
  Returns the encrypted preview map or nil if not cached
  """
  def get_cached_preview(post_id) do
    case :ets.lookup(@table_name, post_id) do
      [{^post_id, encrypted_preview, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          encrypted_preview
        else
          :ets.delete(@table_name, post_id)
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Cache an encrypted preview by post_id
  """
  def cache_preview(post_id, encrypted_preview) do
    GenServer.cast(__MODULE__, {:cache, post_id, encrypted_preview})
  end

  @doc """
  Encrypt a preview map with the provided post_key
  Used when storing preview data in the database or cache
  """
  def encrypt_preview_with_key(nil, _post_key), do: nil

  def encrypt_preview_with_key(preview, post_key) when is_map(preview) do
    preview
    |> Enum.map(fn {field_key, value} ->
      encrypted_value =
        if is_binary(value) && value != "" do
          Utils.encrypt(%{key: post_key, payload: value})
        else
          value
        end

      {field_key, encrypted_value}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Decrypt a preview map using the provided post_key
  Used when displaying preview data from the database or cache
  """
  def decrypt_preview_with_key(nil, _post_key), do: nil

  def decrypt_preview_with_key(encrypted_preview, post_key) when is_map(encrypted_preview) do
    encrypted_preview
    |> Enum.map(fn {field_key, encrypted_value} ->
      decrypted_value =
        if is_binary(encrypted_value) && encrypted_value != "" do
          case Utils.decrypt(%{key: post_key, payload: encrypted_value}) do
            {:ok, value} -> value
            _ -> nil
          end
        else
          encrypted_value
        end

      {field_key, decrypted_value}
    end)
    |> Enum.into(%{})
  end

  def handle_cast({:fetch, url, context}, state) do
    Task.start(fn ->
      case fetch_preview(url) do
        {:ok, preview} ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "url_preview:#{context.request_id}",
            {:preview_ready, preview}
          )

        {:error, reason} ->
          Logger.debug("URL preview failed for #{url}: #{inspect(reason)}")
      end
    end)

    {:noreply, state}
  end

  def handle_cast({:cache, post_id, encrypted_preview}, state) do
    do_cache_preview(post_id, encrypted_preview)
    {:noreply, state}
  end

  def handle_call({:fetch, url}, _from, state) do
    result = fetch_preview(url)
    {:reply, result, state}
  end

  def handle_call({:fetch_and_cache, url, post_id, post_key}, _from, state) do
    result =
      case get_cached_preview(post_id) do
        nil ->
          case fetch_preview(url) do
            {:ok, preview} ->
              encrypted_preview = encrypt_preview_with_key(preview, post_key)
              do_cache_preview(post_id, encrypted_preview)
              {:ok, encrypted_preview}

            error ->
              error
          end

        cached_encrypted_preview ->
          {:ok, cached_encrypted_preview}
      end

    {:reply, result, state}
  end

  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp fetch_preview(url) do
    with {:ok, normalized_url} <- normalize_url(url) do
      case Req.get(normalized_url,
             max_redirects: 3,
             retry: :transient,
             max_retries: 2,
             receive_timeout: 5_000,
             headers: [
               {"user-agent", "MossletBot/1.0 (+https://mosslet.com)"}
             ]
           ) do
        {:ok, %{status: 200, body: html}} ->
          preview = parse_metadata(html, normalized_url)
          {:ok, preview}

        {:ok, %{status: status}} ->
          Logger.debug("URL preview HTTP #{status} for #{url}")
          {:error, :http_error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      error -> error
    end
  end

  defp normalize_url(url) do
    url = String.trim(url)

    cond do
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        {:ok, url}

      String.match?(url, ~r/^[a-zA-Z0-9]/) ->
        {:ok, "https://" <> url}

      true ->
        {:error, :invalid_url}
    end
  end

  defp do_cache_preview(post_id, encrypted_preview) do
    expires_at = System.system_time(:millisecond) + @cache_ttl
    :ets.insert(@table_name, {post_id, encrypted_preview, expires_at})
  end

  defp parse_metadata(html, url) do
    {:ok, document} = Floki.parse_document(html)

    %{
      "url" => url,
      "title" => extract_meta(document, "og:title") || extract_title(document),
      "description" =>
        extract_meta(document, "og:description") || extract_meta(document, "description"),
      "image" => extract_meta(document, "og:image") || extract_first_image(document),
      "site_name" => extract_meta(document, "og:site_name") || extract_domain(url),
      "type" => extract_meta(document, "og:type") || "website"
    }
  end

  defp extract_meta(document, property) do
    Floki.attribute(document, "meta[property='#{property}']", "content")
    |> List.first()
    |> case do
      nil ->
        Floki.attribute(document, "meta[name='#{property}']", "content")
        |> List.first()

      content ->
        content
    end
    |> case do
      "" -> nil
      content -> content
    end
  end

  defp extract_title(document) do
    case Floki.find(document, "title") |> Floki.text() do
      "" -> nil
      title -> String.trim(title)
    end
  end

  defp extract_first_image(document) do
    Floki.attribute(document, "img", "src")
    |> Enum.find(&valid_image_url?/1)
  end

  defp valid_image_url?(url) when is_binary(url) do
    String.starts_with?(url, "http") and
      String.match?(url, ~r/\.(jpg|jpeg|png|gif|webp)$/i)
  end

  defp valid_image_url?(_), do: false

  defp extract_domain(url) do
    case URI.parse(url) do
      %{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    now = System.system_time(:millisecond)

    @table_name
    |> :ets.tab2list()
    |> Enum.each(fn {post_id, _encrypted_preview, expires_at} ->
      if now >= expires_at do
        :ets.delete(@table_name, post_id)
      end
    end)
  end
end
