defmodule Mosslet.Extensions.URLPreviewServer do
  @moduledoc """
  URL preview fetching with ETS caching and rate limiting.

  The GenServer owns the ETS tables and runs periodic cache cleanup.
  All HTTP fetching runs in the caller's process (or in `start_async`
  tasks spawned by LiveViews), so slow external requests never block
  other users.
  """
  use GenServer

  alias Mosslet.Encrypted.Utils
  alias Mosslet.Extensions.URLPreviewSecurity
  alias Mosslet.Extensions.URLPreviewRateLimiter

  @table_name :url_preview_cache
  @cache_ttl :timer.hours(24)
  @cleanup_interval :timer.minutes(30)

  # -------------------------------------------------------------------
  # GenServer lifecycle — owns ETS tables and periodic cleanup
  # -------------------------------------------------------------------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    URLPreviewRateLimiter.init()
    schedule_cleanup()
    {:ok, state}
  end

  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Keep cast-based cache management for fire-and-forget callers
  def handle_cast({:cache, url_hash, encrypted_preview}, state) do
    do_cache_preview(url_hash, encrypted_preview)
    {:noreply, state}
  end

  def handle_cast({:delete_cache, url_hash}, state) do
    :ets.delete(@table_name, url_hash)
    {:noreply, state}
  end

  def handle_cast({:delete_cache_for_connection, connection_id}, state) do
    conn_id_suffix = "-#{connection_id}"

    @table_name
    |> :ets.tab2list()
    |> Enum.each(fn {url_hash, _encrypted_preview, _expires_at} ->
      if String.ends_with?(url_hash, conn_id_suffix) do
        :ets.delete(@table_name, url_hash)
      end
    end)

    {:noreply, state}
  end

  # -------------------------------------------------------------------
  # Public API — runs in the caller's process (no GenServer bottleneck)
  # -------------------------------------------------------------------

  @doc """
  Simple fetch — fetches URL metadata without encryption.
  Returns plain preview data with data URL image for CSP-safe display.

  Runs in the calling process. Call from `start_async` in LiveViews
  to keep the LiveView responsive.

  ## Options
    - user_id: Optional user ID for rate limiting
  """
  def fetch(url, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)

    with :ok <- maybe_check_rate_limit(user_id),
         {:ok, preview} <- fetch_preview(url) do
      preview_with_data_url = maybe_fetch_image_as_data_url(preview)
      {:ok, preview_with_data_url}
    end
  end

  @doc """
  Fetch preview image and convert to data URL for CSP-safe display.
  Returns {:ok, data_url} or {:error, reason}.

  Runs in the calling process.
  """
  def fetch_image_as_data_url(image_url) do
    do_fetch_image_as_data_url(image_url)
  end

  @doc """
  Async fetch — returns immediately, broadcasts result via PubSub.
  """
  def fetch_async(url, context) do
    Task.start(fn ->
      case fetch_preview(url) do
        {:ok, preview} ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "url_preview:#{context.request_id}",
            {:preview_ready, preview}
          )

        {:error, _reason} ->
          nil
      end
    end)
  end

  @doc """
  Fetch, encrypt, and cache — fetches URL metadata, encrypts with post_key,
  and caches by url_hash. Returns encrypted preview data.

  Runs in the calling process.

  ## Options
    - user_id: Optional user ID for rate limiting
    - profile_key: Optional storage key identifier for organizing cached images
  """
  def fetch_and_cache(url, url_hash, post_key, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    profile_key = Keyword.get(opts, :profile_key)
    storage_key = profile_key || url_hash

    with :ok <- maybe_check_rate_limit(user_id) do
      case get_cached_preview(url_hash) do
        nil ->
          case fetch_preview(url) do
            {:ok, preview} ->
              preview_with_proxied_image =
                maybe_proxy_preview_image(preview, storage_key, post_key)

              encrypted_preview = encrypt_preview_with_key(preview_with_proxied_image, post_key)
              do_cache_preview(url_hash, encrypted_preview)
              {:ok, encrypted_preview}

            error ->
              error
          end

        cached_encrypted_preview ->
          {:ok, cached_encrypted_preview}
      end
    end
  end

  @doc """
  Get cached encrypted preview by url_hash.
  Reads directly from the public ETS table (no GenServer call).
  """
  def get_cached_preview(url_hash) do
    case :ets.lookup(@table_name, url_hash) do
      [{^url_hash, encrypted_preview, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          encrypted_preview
        else
          :ets.delete(@table_name, url_hash)
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Cache an encrypted preview by url_hash.
  """
  def cache_preview(url_hash, encrypted_preview) do
    GenServer.cast(__MODULE__, {:cache, url_hash, encrypted_preview})
  end

  @doc """
  Delete cached preview by url_hash.
  """
  def delete_cached_preview(url_hash) do
    GenServer.cast(__MODULE__, {:delete_cache, url_hash})
  end

  @doc """
  Delete all cached previews for a connection_id.
  Used when a profile or account is deleted.
  """
  def delete_cached_previews_for_connection(connection_id) do
    GenServer.cast(__MODULE__, {:delete_cache_for_connection, connection_id})
  end

  @doc """
  Encrypt a preview map with the provided post_key.
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
  Decrypt a preview map using the provided post_key.
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

  # -------------------------------------------------------------------
  # Private — HTTP fetching and helpers (run in caller's process)
  # -------------------------------------------------------------------

  defp fetch_preview(url) do
    with {:ok, normalized_url} <- URLPreviewSecurity.validate_and_normalize_url(url) do
      case Req.get(normalized_url,
             max_redirects: 5,
             retry: :transient,
             max_retries: 1,
             receive_timeout: 8_000,
             headers: [
               {"user-agent",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
               {"accept",
                "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"},
               {"accept-language", "en-US,en;q=0.5"}
             ]
           ) do
        {:ok, %{status: 200, body: html}} ->
          preview = parse_metadata(html, normalized_url)
          sanitized_preview = URLPreviewSecurity.sanitize_metadata(preview)
          {:ok, sanitized_preview}

        {:ok, %{status: _status}} ->
          {:error, :http_error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      error -> error
    end
  end

  defp do_cache_preview(url_hash, encrypted_preview) do
    expires_at = System.system_time(:millisecond) + @cache_ttl
    :ets.insert(@table_name, {url_hash, encrypted_preview, expires_at})
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
      String.match?(url, ~r/\.(webp|jpg|jpeg|png|gif|webp)$/i)
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
    |> Enum.each(fn {url_hash, _encrypted_preview, expires_at} ->
      if now >= expires_at do
        :ets.delete(@table_name, url_hash)
      end
    end)
  end

  defp maybe_proxy_preview_image(preview, post_id, post_key) do
    case preview["image"] do
      nil ->
        preview

      "" ->
        preview

      image_url when is_binary(image_url) ->
        if external_image_url?(image_url) do
          url_hash =
            :crypto.hash(:sha3_512, "#{image_url}-#{post_id}") |> Base.encode16(case: :lower)

          case Mosslet.Extensions.URLPreviewImageProxy.fetch_and_store_preview_image(
                 image_url,
                 url_hash,
                 post_key,
                 post_id
               ) do
            {:ok, proxied_url} ->
              Map.put(preview, "image", proxied_url)

            {:error, _reason} ->
              preview
          end
        else
          preview
        end

      _ ->
        preview
    end
  end

  defp external_image_url?(url) when is_binary(url) do
    memories_bucket = Mosslet.Encrypted.Session.memories_bucket()
    s3_host = Mosslet.Encrypted.Session.s3_host()
    bucket_host = "#{memories_bucket}.#{s3_host}"

    not String.contains?(url, bucket_host)
  end

  defp external_image_url?(_), do: false

  defp maybe_fetch_image_as_data_url(preview) do
    case preview["image"] do
      nil ->
        preview

      "" ->
        preview

      image_url when is_binary(image_url) ->
        case do_fetch_image_as_data_url(image_url) do
          {:ok, data_url} ->
            preview
            |> Map.put("image", data_url)
            |> Map.put("original_image_url", image_url)

          {:error, _reason} ->
            Map.put(preview, "image", nil)
        end

      _ ->
        preview
    end
  end

  defp do_fetch_image_as_data_url(image_url) do
    with {:ok, validated_url} <- URLPreviewSecurity.validate_and_normalize_url(image_url) do
      case Req.get(validated_url,
             max_redirects: 5,
             retry: :transient,
             max_retries: 1,
             receive_timeout: 8_000,
             headers: [
               {"user-agent",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
               {"accept", "image/webp,image/apng,image/*,*/*;q=0.8"},
               {"accept-language", "en-US,en;q=0.5"}
             ]
           ) do
        {:ok, %{status: 200, body: body, headers: headers}} when is_binary(body) ->
          if byte_size(body) <= 5_242_880 do
            content_type = extract_content_type(headers)

            case resize_preview_image(body) do
              {:ok, resized_binary} ->
                base64 = Base.encode64(resized_binary)
                data_url = "data:#{content_type};base64,#{base64}"
                {:ok, data_url}

              error ->
                error
            end
          else
            {:error, :image_too_large}
          end

        {:ok, %{status: _status}} ->
          {:error, :fetch_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp resize_preview_image(binary) do
    case Image.from_binary(binary) do
      {:ok, image} ->
        {:ok, resized} =
          Image.thumbnail(image, "400x400",
            resize: :down,
            crop: :none,
            intent: :perceptual
          )

        Image.write(resized, :memory, suffix: ".webp", webp: [quality: 75])

      {:error, _reason} = error ->
        error
    end
  end

  defp extract_content_type(headers) do
    headers
    |> Enum.find(fn {key, _} -> String.downcase(to_string(key)) == "content-type" end)
    |> case do
      {_, content_type} ->
        content_type
        |> to_string()
        |> String.split(";")
        |> List.first()
        |> String.trim()

      nil ->
        "image/jpeg"
    end
  end

  defp maybe_check_rate_limit(nil), do: :ok

  defp maybe_check_rate_limit(user_id) do
    URLPreviewRateLimiter.check_rate_limit(user_id)
  end
end
