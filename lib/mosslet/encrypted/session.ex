defmodule Mosslet.Encrypted.Session do
  @moduledoc false

  def signing_salt, do: System.fetch_env!("SESSION_SIGNING_SALT")
  def encryption_salt, do: System.fetch_env!("SESSION_ENCRYPTION_SALT")
  def server_public_key, do: System.fetch_env!("SERVER_PUBLIC_KEY")
  def server_private_key, do: System.fetch_env!("SERVER_PRIVATE_KEY")
  def avatars_bucket, do: System.fetch_env!("AVATARS_BUCKET")
  def banners_bucket, do: System.fetch_env!("AVATARS_BUCKET")
  def memories_bucket, do: System.fetch_env!("MEMORIES_BUCKET")
  def admin_email, do: System.fetch_env!("ADMIN_EMAIL")
  def s3_endpoint, do: System.fetch_env!("AWS_ENDPOINT_URL_S3")
  def s3_region, do: System.fetch_env!("AWS_REGION")
  def s3_access_key_id, do: System.fetch_env!("AWS_ACCESS_KEY_ID")
  def s3_secret_key_access, do: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
  def s3_host, do: System.fetch_env!("AWS_HOST")
end
