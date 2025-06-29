defmodule Mosslet.FileUploads.Storj do
  @moduledoc false
  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  import MossletWeb.Helpers

  def file_ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{ext}"
  end

  def filename(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "#{entry.uuid}.#{ext}"
  end

  def prepare_file_path(entry, connection_id) do
    {:ok, "uploads/user/#{connection_id}/avatars/#{filename(entry)}"}
  end

  def prepare_encrypted_blob(blob, user, key) do
    {:ok, d_conn_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

    # This only returns an encrypted binary
    encrypted_avatar_blob = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: blob})

    {:ok, encrypted_avatar_blob}
  end

  def make_aws_requests(entry, avatars_bucket, file_path, e_blob, user, key) do
    with {:ok, _resp} <- maybe_delete_old_avatar(avatars_bucket, user, key),
         {:ok, _resp} <- ex_aws_put_request(avatars_bucket, file_path, e_blob) do
      # Return the encrypted_blob in the tuple for putting
      # the encrypted avatar into ets.
      {:ok, {entry, file_path, e_blob}}
    else
      _rest ->
        ex_aws_put_request(avatars_bucket, file_path, e_blob)
    end
  end

  def ex_aws_delete_request(avatars_bucket, url) do
    ExAws.S3.delete_object(avatars_bucket, url)
    |> ExAws.request()
  end

  def ex_aws_put_request(avatars_bucket, file_path, e_blob) do
    ExAws.S3.put_object(avatars_bucket, file_path, e_blob)
    |> ExAws.request()
  end

  def maybe_delete_old_avatar(avatars_bucket, user, key) do
    case user.connection.avatar_url do
      nil ->
        {:ok, "no avatar"}

      _rest ->
        d_url = decr_avatar(user.connection.avatar_url, user, user.conn_key, key)

        case ex_aws_delete_request(avatars_bucket, d_url) do
          {:ok, resp} -> {:ok, resp}
          _rest -> ex_aws_delete_request(avatars_bucket, d_url)
        end
    end
  end

  def make_async_aws_requests(avatars_bucket, url, _user, _key) do
    # delete only the user avatar because the
    # profile has already been deleted
    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      case ex_aws_delete_request(avatars_bucket, url) do
        {:ok, _resp} ->
          {:ok, :avatar_deleted_from_storj, "Avatar successfully deleted from the private cloud."}

        _rest ->
          ex_aws_delete_request(avatars_bucket, url)
          {:error, :make_async_aws_requests}
      end
    end)
  end

  def make_async_aws_requests(avatars_bucket, url, profile_avatar_url, user, key) do
    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      profile_attrs =
        %{
          "profile" => %{
            "avatar_url" => nil,
            "show_avatar?" => false,
            "opts_map" => %{"user" => user, "key" => key, "update_profile" => true}
          }
        }

      # delete both the profile and the user avatar
      with {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, url),
           {:ok, _resp} <- ex_aws_delete_request(avatars_bucket, profile_avatar_url),
           {:ok, _user} <- Accounts.update_user_profile(user, profile_attrs) do
        {:ok, :avatar_deleted_from_storj, "Avatar successfully deleted from the private cloud."}
      else
        _rest ->
          ex_aws_delete_request(avatars_bucket, url)
          ex_aws_delete_request(avatars_bucket, profile_avatar_url)
          {:error, :make_async_aws_requests}
      end
    end)
  end
end
