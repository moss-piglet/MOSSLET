defmodule Mosslet.FileUploads.Cloudinary do
  @moduledoc """
  Provides methods for enabling direct uploads to Cloudinary via LiveView.
  See https://cloudinary.com/documentation/upload_images#direct_upload

  ## Setup

  Expects the following environment variables:

  ```
  export CLOUDINARY_CLOUD_NAME=""
  export CLOUDINARY_API_KEY=""
  export CLOUDINARY_API_SECRET=""
  export CLOUDINARY_FOLDER=""
  ```

  The module should be used in a liveview form module that allows image uploads.

  ## Examples
  ```
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> allow_upload(:image,
       accept: ~w(image/*),
       max_entries: 3,
       external: &Mosslet.FileUploads.Cloudinary.presign_upload/2
     )}
  ```

  While we provide a function consume_uploaded_entries/3, it is more there as an example.
  We actually recommend consuming the entries yourself and then storing the "public_id" in the database.
  The public_id is not a URL, but rather a unique identifier for the file in Cloudinary.
  With the public_id you can generate a URL. The cool thing is that you can manipulate the image with the URL.
  For example, you can resize the image on the fly. See https://cloudinary.com/documentation/image_transformations#resizing_and_cropping_images.

  To do transforms in Elixir, you can use the [cloudex library](https://github.com/smeevil/cloudex).

  For example, you can do the following:

      iex> Cloudex.Url.for("a_public_id")
      "//res.cloudinary.com/my_cloud_name/image/upload/a_public_id"

      iex> Cloudex.Url.for("a_public_id", %{width: 400, height: 300})
      "//res.cloudinary.com/my_cloud_name/image/upload/h_300,w_400/a_public_id"

      iex> Cloudex.Url.for("a_public_id", %{
        crop: "fill",
        fetch_format: 'auto',
        flags: 'progressive',
        width: 300,
        height: 254,
        quality: "jpegmini",
        sign_url: true
      })
      "//res.cloudinary.com/my_cloud_name/image/upload/s--jwB_Ds4w--/c_fill,f_auto,fl_progressive,h_254,q_jpegmini,w_300/a_public_id"

  You can handle a submit event like this:
  ```
  @impl Phoenix.LiveComponent
  def handle_event("submit", _params, socket) do
    cloudinary_public_ids =
      consume_uploaded_entries(socket, :avatar, fn %{fields: fields}, _entry ->
        {:ok, fields["public_id"]}
      end)

    # save cloudinary_public_ids to the database

    {:noreply, socket}
  end
  ```
  """

  @spec presign_upload(map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def presign_upload(entry, socket) do
    fields =
      %{public_id: entry.uuid}
      |> maybe_put_folder()
      |> sign()
      |> unify()

    meta = %{
      uploader: "ExternalUploader",
      fields: fields,
      url: url()
    }

    {:ok, meta, socket}
  end

  @spec consume_uploaded_entries(Phoenix.LiveView.Socket.t(), any) :: list
  def consume_uploaded_entries(socket, uploads_key) do
    Phoenix.LiveView.consume_uploaded_entries(socket, uploads_key, fn %{fields: fields}, _entry ->
      {:ok, file_id_to_url(fields["public_id"])}
    end)
  end

  @spec file_id_to_url(any) :: String.t()
  defp file_id_to_url(public_id) do
    cloud_name = Mosslet.config([:cloudinary, :cloud_name])
    folder = Mosslet.config([:cloudinary, :folder])
    "https://res.cloudinary.com/#{cloud_name}/image/upload/#{folder}/#{public_id}.jpg"
  end

  @spec sign(map) :: map
  defp sign(config) do
    timestamp = current_time()
    secret = Mosslet.config([:cloudinary, :api_secret])
    api_key = Mosslet.config([:cloudinary, :api_key])

    config_without_secret =
      config
      |> Map.drop([:file, :resource_type])
      |> Map.put("timestamp", timestamp)
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.sort()
      |> Enum.join("&")

    sig = sha(config_without_secret <> secret)

    Map.merge(config, %{"signature" => sig, "timestamp" => timestamp, "api_key" => api_key})
  end

  @spec maybe_put_folder(map()) :: map()
  defp maybe_put_folder(config) do
    case Mosslet.config([:cloudinary, :folder]) do
      nil -> config
      folder -> Map.put(config, :folder, folder)
    end
  end

  @spec sha(String.t()) :: String.t()
  defp sha(query) do
    :sha
    |> :crypto.hash(query)
    |> Base.encode16()
    |> String.downcase()
  end

  @spec current_time :: String.t()
  defp current_time do
    DateTime.utc_now()
    |> DateTime.to_unix()
    |> round()
    |> Integer.to_string()
  end

  @spec unify(map()) :: map()
  defp unify(m), do: Enum.reduce(m, %{}, fn {k, v}, acc -> Map.put(acc, "#{k}", v) end)

  @spec url :: String.t()
  defp url,
    do:
      Path.join([
        "https://api.cloudinary.com/v1_1",
        Mosslet.config([:cloudinary, :cloud_name]),
        "image/upload"
      ])
end
