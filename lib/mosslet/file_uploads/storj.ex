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

  def prepare_banner_file_path(entry, connection_id) do
    {:ok, "uploads/user/#{connection_id}/banners/#{filename(entry)}"}
  end

  def prepare_encrypted_blob(blob, user, key) do
    {:ok, d_conn_key} =
      Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

    encrypted_avatar_blob = Encrypted.Utils.encrypt(%{key: d_conn_key, payload: blob})

    {:ok, encrypted_avatar_blob}
  end

  def make_aws_requests(entry, avatars_bucket, file_path, e_blob, user, key) do
    with {:ok, _resp} <- maybe_delete_old_avatar(avatars_bucket, user, key),
         {:ok, _resp} <- ex_aws_put_request(avatars_bucket, file_path, e_blob) do
      {:ok, {entry, file_path, e_blob}}
    else
      _rest ->
        ex_aws_put_request(avatars_bucket, file_path, e_blob)
    end
  end

  def make_banner_aws_requests(entry, banners_bucket, file_path, e_blob, user, key) do
    with {:ok, _resp} <- maybe_delete_old_banner(banners_bucket, user, key),
         {:ok, _resp} <- ex_aws_put_request(banners_bucket, file_path, e_blob) do
      {:ok, {entry, file_path, e_blob}}
    else
      _rest ->
        ex_aws_put_request(banners_bucket, file_path, e_blob)
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

  def maybe_delete_old_banner(banners_bucket, user, key) do
    profile = Map.get(user.connection, :profile)

    case profile && Map.get(profile, :custom_banner_url) do
      nil ->
        {:ok, "no banner"}

      _rest ->
        d_url = decr_banner(profile.custom_banner_url, user, user.conn_key, key)

        case ex_aws_delete_request(banners_bucket, d_url) do
          {:ok, resp} -> {:ok, resp}
          _rest -> ex_aws_delete_request(banners_bucket, d_url)
        end
    end
  end

  def make_async_aws_requests(avatars_bucket, url, _user, _key) do
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

  def make_async_banner_delete_request(banners_bucket, url) do
    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      case ex_aws_delete_request(banners_bucket, url) do
        {:ok, _resp} ->
          {:ok, :banner_deleted_from_storj, "Banner successfully deleted from the private cloud."}

        _rest ->
          ex_aws_delete_request(banners_bucket, url)
          {:error, :make_async_banner_delete_request}
      end
    end)
  end
end
