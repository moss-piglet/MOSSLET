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

  Crop values are normalized fractions (0.0–1.0) relative to the image
  dimensions, as sent by the `ImageCropHook` JS. They are scaled to pixels and
  clamped to the image bounds so out-of-range selections can never reach
  libvips' `extract_area` (which raises "bad extract area").

  Returns `{:ok, image}` unchanged when crop is nil, empty, or degenerate.
  """
  def maybe_apply_crop(image, nil), do: {:ok, image}
  def maybe_apply_crop(image, crop) when crop == %{}, do: {:ok, image}

  def maybe_apply_crop(image, %{x: x, y: y, width: w, height: h}) do
    img_width = Image.width(image)
    img_height = Image.height(image)

    case pixel_crop(x, y, w, h, img_width, img_height) do
      {cx, cy, cw, ch} -> Image.crop(image, cx, cy, cw, ch)
      :full -> {:ok, image}
    end
  end

  def maybe_apply_crop(image, _crop), do: {:ok, image}

  @doc """
  Generates a JPEG data URL preview of a cropped image region.

  Crop values are normalized fractions (0.0–1.0), clamped to image bounds.
  Returns `{:ok, data_url}` or `{:error, reason}`.
  """
  def generate_cropped_preview(nil, _crop), do: {:error, :no_path}

  def generate_cropped_preview(path, %{x: x, y: y, width: w, height: h}) do
    with {:ok, image} <- Image.open(path),
         {:ok, cropped} <- maybe_apply_crop(image, %{x: x, y: y, width: w, height: h}),
         {:ok, binary} <- Image.write(cropped, :memory, suffix: ".jpg", quality: 90) do
      {:ok, "data:image/jpeg;base64,#{Base.encode64(binary)}"}
    end
  end

  def generate_cropped_preview(_path, _crop), do: {:error, :invalid_crop}

  # Scales normalized crop fractions to integer pixels and clamps the region
  # to the image bounds. Returns `{x, y, width, height}` in pixels, or `:full`
  # when the selection covers (or exceeds) the whole image.
  defp pixel_crop(x, y, w, h, img_width, img_height) do
    x = clamp_fraction(x)
    y = clamp_fraction(y)
    w = clamp_fraction(w)
    h = clamp_fraction(h)

    cx = floor(x * img_width)
    cy = floor(y * img_height)
    cw = min(round(w * img_width), img_width - cx)
    ch = min(round(h * img_height), img_height - cy)

    if cw >= img_width and ch >= img_height do
      :full
    else
      {cx, cy, max(cw, 1), max(ch, 1)}
    end
  end

  defp clamp_fraction(v) when is_number(v), do: v |> min(1.0) |> max(0.0)

  defp clamp_fraction(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> clamp_fraction(f)
      :error -> 0.0
    end
  end

  defp clamp_fraction(_), do: 0.0

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
