defmodule MossletWeb.Helpers.URLPreviewHelpers do
  @moduledoc """
  Helper functions for handling URL preview fetching and display across LiveViews.
  Provides consistent async fetching and message handling for website URL previews.
  """

  alias Mosslet.Encrypted
  alias Mosslet.Extensions.URLPreviewServer
  alias Phoenix.LiveView.Socket

  @doc """
  Assigns default URL preview state to a socket.
  Call this in mount/3 to initialize the required assigns.
  """
  @spec assign_url_preview_defaults(Socket.t()) :: Socket.t()
  def assign_url_preview_defaults(socket) do
    socket
    |> Phoenix.Component.assign(:website_url_preview, nil)
    |> Phoenix.Component.assign(:website_url_preview_loading, false)
  end

  @doc """
  Starts an async fetch for website URL preview if a URL is present.
  Returns the socket with loading state set appropriately.

  ## Parameters
    - socket: The LiveView socket
    - website_url: The decrypted website URL string (or nil)
    - profile_key: The decrypted profile encryption key
    - connection_id: The connection ID used for cache key generation
  """
  @spec maybe_start_preview_fetch(Socket.t(), String.t() | nil, binary() | nil, String.t()) ::
          Socket.t()
  def maybe_start_preview_fetch(socket, website_url, profile_key, connection_id) do
    if is_binary(website_url) && website_url != "" && profile_key do
      url_hash =
        :crypto.hash(:sha3_512, "#{website_url}-#{connection_id}") |> Base.encode16(case: :lower)

      Task.async(fn ->
        {:website_preview_result,
         URLPreviewServer.fetch_and_cache(website_url, url_hash, profile_key,
           profile_key: connection_id
         )}
      end)

      Phoenix.Component.assign(socket, :website_url_preview_loading, true)
    else
      socket
    end
  end

  @doc """
  Handles the async website preview result message in handle_info/2.
  Returns `{:handled, socket}` if the message was handled, `{:not_handled, socket}` otherwise.

  ## Parameters
    - message: The message received in handle_info
    - socket: The LiveView socket
    - profile_key: The decrypted profile key used to decrypt the preview
  """
  @spec handle_preview_result(term(), Socket.t(), binary() | nil) ::
          {:handled, Socket.t()} | {:not_handled, Socket.t()}
  def handle_preview_result({ref, {:website_preview_result, result}}, socket, profile_key) do
    Process.demonitor(ref, [:flush])

    socket =
      case result do
        {:ok, encrypted_preview} ->
          preview = URLPreviewServer.decrypt_preview_with_key(encrypted_preview, profile_key)
          preview_with_image = maybe_fetch_and_decrypt_preview_image(preview, profile_key)

          socket
          |> Phoenix.Component.assign(:website_url_preview, preview_with_image)
          |> Phoenix.Component.assign(:website_url_preview_loading, false)

        {:error, _reason} ->
          socket
          |> Phoenix.Component.assign(:website_url_preview, nil)
          |> Phoenix.Component.assign(:website_url_preview_loading, false)
      end

    {:handled, socket}
  end

  def handle_preview_result({:DOWN, _ref, :process, _pid, _reason}, socket, _profile_key) do
    {:handled, Phoenix.Component.assign(socket, :website_url_preview_loading, false)}
  end

  def handle_preview_result(_message, socket, _profile_key), do: {:not_handled, socket}

  @doc """
  Decrypts a public profile field using the public profile key.
  Returns the decrypted string or empty string on failure.
  """
  @spec decrypt_public_field(binary() | nil, binary() | nil) :: String.t()
  def decrypt_public_field(encrypted_value, encrypted_profile_key) do
    case Encrypted.Users.Utils.decrypt_public_item(encrypted_value, encrypted_profile_key) do
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  @doc """
  Gets the decrypted profile key from an encrypted public profile key.
  """
  @spec get_public_profile_key(binary() | nil) :: binary() | nil
  def get_public_profile_key(encrypted_profile_key) do
    Encrypted.Users.Utils.decrypt_public_item_key(encrypted_profile_key)
  end

  @doc """
  Gets the decrypted profile key for a private/connections profile.
  Returns `{:ok, key}` or `{:error, reason}`.
  """
  @spec get_private_profile_key(binary() | nil, map(), binary()) ::
          {:ok, binary()} | {:error, term()}
  def get_private_profile_key(encrypted_profile_key, current_user, session_key) do
    Encrypted.Users.Utils.decrypt_user_attrs_key(
      encrypted_profile_key,
      current_user,
      session_key
    )
  end

  @doc """
  Fetches and decrypts the preview image from a presigned URL if needed.
  The image field may contain a presigned URL to an encrypted blob that needs
  to be fetched, decrypted, and converted to a data URL.
  """
  @spec maybe_fetch_and_decrypt_preview_image(map() | nil, binary() | nil) :: map() | nil
  def maybe_fetch_and_decrypt_preview_image(nil, _key), do: nil
  def maybe_fetch_and_decrypt_preview_image(preview, nil), do: preview

  def maybe_fetch_and_decrypt_preview_image(preview, key) do
    case preview["image"] do
      nil ->
        preview

      "" ->
        preview

      image_url when is_binary(image_url) ->
        if encrypted_image_url?(image_url) do
          case fetch_and_decrypt_image(image_url, key) do
            {:ok, data_url} -> Map.put(preview, "image", data_url)
            {:error, _reason} -> Map.put(preview, "image", nil)
          end
        else
          preview
        end

      _ ->
        preview
    end
  end

  defp encrypted_image_url?(url) do
    String.ends_with?(url, ".enc") or String.contains?(url, ".enc?")
  end

  defp fetch_and_decrypt_image(presigned_url, key) do
    with {:ok, %{status: 200, body: encrypted_image}} <- Req.get(presigned_url),
         {:ok, decrypted_binary} <-
           Encrypted.Utils.decrypt(%{key: key, payload: encrypted_image}) do
      data_url = "data:image/jpeg;base64," <> Base.encode64(decrypted_binary)
      {:ok, data_url}
    else
      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        require Logger
        Logger.warning("Failed to fetch URL preview image, status: #{status}")
        {:error, :fetch_failed}

      {:error, reason} ->
        require Logger
        Logger.error("Failed to fetch/decrypt URL preview image: #{inspect(reason)}")
        {:error, reason}

      error ->
        require Logger
        Logger.error("Unexpected error fetching/decrypting URL preview image: #{inspect(error)}")
        {:error, :unknown}
    end
  end
end
