defmodule MossletWeb.Helpers.UploadHelpers do
  @moduledoc """
  Shared helpers for avatar and banner upload flows in LiveViews.

  Extracts common image processing, cropping, and encryption utilities
  used by both `EditDetailsLive` (avatars) and `EditProfileLive` (banners).
  """

  alias Mosslet.Encrypted

  @doc """
  Returns whether an upload stage indicates active processing.

  ## Examples

      iex> processing?(nil)
      false
      iex> processing?({:ready, 100})
      false
      iex> processing?({:converting, 30})
      true
  """
  def processing?(nil), do: false
  def processing?({:ready, _}), do: false
  def processing?({:error, _}), do: false
  def processing?(_), do: true

  @doc """
  Applies an optional crop region to a `Vix.Vips.Image`.

  Returns `{:ok, image}` unchanged when crop is nil or empty.
  """
  def maybe_apply_crop(image, nil), do: {:ok, image}
  def maybe_apply_crop(image, crop) when crop == %{}, do: {:ok, image}

  def maybe_apply_crop(image, %{x: x, y: y, width: w, height: h}) do
    Image.crop(image, x, y, w, h)
  end

  @doc """
  Generates a JPEG data URL preview of a cropped image region.

  Returns `{:ok, data_url}` or `{:error, reason}`.
  """
  def generate_cropped_preview(nil, _crop), do: {:error, :no_path}

  def generate_cropped_preview(path, %{x: x, y: y, width: w, height: h}) do
    with {:ok, image} <- Image.open(path),
         {:ok, cropped} <- Image.crop(image, x, y, w, h),
         {:ok, binary} <- Image.write(cropped, :memory, suffix: ".jpg", quality: 90) do
      {:ok, "data:image/jpeg;base64,#{Base.encode64(binary)}"}
    end
  end

  def generate_cropped_preview(_path, _crop), do: {:error, :invalid_crop}

  @doc """
  Builds an upload map for template display from an upload entry.

  Returns `nil` if the entry is nil.
  """
  def build_upload_map(nil, _alt_text, _preview_url), do: nil

  def build_upload_map(entry, alt_text, preview_url) do
    %{
      ref: entry.ref,
      alt_text: alt_text,
      preview_data_url: preview_url,
      entry: entry
    }
  end

  @doc """
  Encrypts alt text with the user's conn_key for storage.

  Returns `nil` for nil or empty alt text.
  """
  def encrypt_alt_text(nil, _user, _key), do: nil
  def encrypt_alt_text("", _user, _key), do: nil

  def encrypt_alt_text(alt_text, user, key) do
    case Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key) do
      {:ok, d_conn_key} ->
        Encrypted.Utils.encrypt(%{key: d_conn_key, payload: alt_text})

      {:error, _reason} ->
        nil
    end
  end
end
