defmodule Mosslet.FileUploads.S3 do
  @moduledoc """
  Dependency-free S3 Form Upload using HTTP POST sigv4

  https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html

  ## Setup

  Create an S3 bucket and enable CORS. Click on Permissions, scroll down to "Cross-origin resource sharing (CORS)" and add:

        [
          {
            "AllowedHeaders": [
              "*"
            ],
            "AllowedMethods": [
              "PUT",
              "POST"
            ],
            "AllowedOrigins": [
              "*"
            ],
            "ExposeHeaders": []
          }
        ]

  You also need ACLs enabled.
  Go to Bucket > Permissions Tab.
  Scroll to Object Ownership and click on Edit.
  Set ACLs to enabled. Object ownership should be "Bucket owner preferred".
  Save.

  Create an IAM user with permissions to upload to the bucket. See https://medium.com/founders-coders/image-uploads-with-aws-s3-elixir-phoenix-ex-aws-step-1-f6ed1c918f14.

  Add the following environment variables to your .envrc:

      export AWS_ACCESS_KEY=""
      export AWS_SECRET=""
      export AWS_REGION=""
      export S3_FILE_UPLOAD_BUCKET=""

  In your live view mount() function:

      socket
      |> allow_upload(:avatar,
          accept: ~w(.jpg .jpeg .png .gif .svg .webp),
          max_entries: 1,
          external: &Mosslet.FileUploads.S3.presign_upload/2
        )}

  When you want to retrieve the URLs:

      def handle_event("submit", %{"user" => user_params}, socket) do
        uploaded_files = Mosslet.FileUploads.S3.consume_uploaded_entries(socket, :avatar)
        # => ["http://your-bucket.s3.your-region.amazonaws.com/file"]

        # Do something with the uploaded files
      end
  """

  @doc """
  Signs a form upload.

  The configuration is a map which must contain the following keys:

    * `:region` - The AWS region, such as "us-east-1"
    * `:access_key_id` - The AWS access key id
    * `:secret_access_key` - The AWS secret access key

  Returns a map of form fields to be used on the client via the JavaScript `FormData` API.

  ## Options

    * `:key` - The required key of the object to be uploaded.
    * `:max_file_size` - The required maximum allowed file size in bytes.
    * `:content_type` - The required MIME type of the file to be uploaded.
    * `:expires_in` - The required expiration time in milliseconds from now
      before the signed upload expires.

  ## Examples

      config = %{
        region: "us-east-1",
        access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
      }

      {:ok, fields} =
        S3.sign_form_upload(config, "my-bucket",
          key: "public/my-file-name",
          content_type: "image/png",
          max_file_size: 10_000,
          expires_in: :timer.hours(1)
        )
  """

  @typedoc """
  Your AWS config
  """
  @type s3_config :: %{
          :access_key_id => binary,
          :region => binary,
          :secret_access_key => binary
        }

  @spec presign_upload(map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def presign_upload(entry, socket) do
    uploads = socket.assigns.uploads
    bucket = Mosslet.config([:s3, :bucket])
    key = Ecto.UUID.generate() <> Path.extname(entry.client_name)

    config = %{
      region: Mosslet.config([:s3, :region]),
      access_key_id: Mosslet.config([:s3, :access_key]),
      secret_access_key: Mosslet.config([:s3, :secret])
    }

    {:ok, fields} =
      sign_form_upload(config, bucket,
        key: key,
        content_type: entry.client_type,
        max_file_size: uploads[entry.upload_config].max_file_size,
        expires_in: :timer.hours(1)
      )

    meta = %{
      uploader: "ExternalUploader",
      key: key,
      url: "http://#{bucket}.s3.#{config.region}.amazonaws.com",
      fields: fields
    }

    {:ok, meta, socket}
  end

  @spec consume_uploaded_entries(Phoenix.LiveView.Socket.t(), any) :: list
  def consume_uploaded_entries(socket, uploads_key) do
    Phoenix.LiveView.consume_uploaded_entries(socket, uploads_key, fn upload, _entry ->
      {:ok, file_id_to_url(upload.fields["key"])}
    end)
  end

  @spec file_id_to_url(any) :: String.t()
  defp file_id_to_url(key) do
    region = Mosslet.config([:s3, :region])
    bucket = Mosslet.config([:s3, :bucket])
    "http://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end

  @spec sign_form_upload(s3_config, any, keyword) :: {:ok, map()}
  def sign_form_upload(s3_config, bucket, opts) do
    key = Keyword.fetch!(opts, :key)
    max_file_size = Keyword.fetch!(opts, :max_file_size)
    content_type = Keyword.fetch!(opts, :content_type)
    expires_in = Keyword.fetch!(opts, :expires_in)

    expires_at = DateTime.add(DateTime.utc_now(), expires_in, :millisecond)
    amz_date = amz_date(expires_at)
    credential = credential(s3_config, expires_at)

    encoded_policy =
      Base.encode64("""
      {
        "expiration": "#{DateTime.to_iso8601(expires_at)}",
        "conditions": [
          {"bucket":  "#{bucket}"},
          ["eq", "$key", "#{key}"],
          ["eq", "$Content-Type", "#{content_type}"],
          ["content-length-range", 0, #{max_file_size}],
          {"x-amz-server-side-encryption": "AES256"},
          {"x-amz-credential": "#{credential}"},
          {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
          {"x-amz-date": "#{amz_date}"}
        ]
      }
      """)

    fields = %{
      "key" => key,
      "content-type" => content_type,
      "x-amz-server-side-encryption" => "AES256",
      "x-amz-credential" => credential,
      "x-amz-algorithm" => "AWS4-HMAC-SHA256",
      "x-amz-date" => amz_date,
      "policy" => encoded_policy,
      "x-amz-signature" => signature(s3_config, expires_at, encoded_policy)
    }

    {:ok, fields}
  end

  @spec amz_date(DateTime.t()) :: String.t()
  defp amz_date(time) do
    time
    |> NaiveDateTime.to_iso8601()
    |> String.split(".")
    |> List.first()
    |> String.replace("-", "")
    |> String.replace(":", "")
    |> Kernel.<>("Z")
  end

  @spec credential(s3_config, DateTime.t()) :: String.t()
  defp credential(%{} = s3_config, %DateTime{} = expires_at) do
    "#{s3_config.access_key_id}/#{short_date(expires_at)}/#{s3_config.region}/s3/aws4_request"
  end

  @spec signature(s3_config, DateTime.t(), binary) :: binary
  defp signature(config, %DateTime{} = expires_at, encoded_policy) do
    config
    |> signing_key(expires_at, "s3")
    |> sha256(encoded_policy)
    |> Base.encode16(case: :lower)
  end

  @spec signing_key(s3_config, DateTime.t(), binary) :: binary
  defp signing_key(
         %{secret_access_key: secret, region: region},
         %DateTime{} = expires_at,
         service
       )
       when service in ["s3"] do
    amz_date = short_date(expires_at)

    ("AWS4" <> secret)
    |> sha256(amz_date)
    |> sha256(region)
    |> sha256(service)
    |> sha256("aws4_request")
  end

  @spec short_date(DateTime.t()) :: binary
  defp short_date(%DateTime{} = expires_at) do
    expires_at
    |> amz_date()
    |> String.slice(0..7)
  end

  @spec sha256(binary(), binary()) :: binary()
  defp sha256(secret, msg), do: :crypto.mac(:hmac, :sha256, secret, msg)
end
