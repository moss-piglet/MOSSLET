defmodule MossletWeb.API.GroupController do
  @moduledoc """
  API endpoints for group operations.

  Handles group CRUD, membership management, and block operations.
  All encrypted data is passed through as-is - native apps handle
  encryption/decryption locally for zero-knowledge operation.
  """
  use MossletWeb, :controller

  alias Mosslet.Groups
  alias Mosslet.Groups.{Group, UserGroup}

  action_fallback MossletWeb.API.FallbackController

  def index(conn, params) do
    user = conn.assigns.current_user

    groups = Groups.list_groups(user, parse_options(params))

    conn
    |> put_status(:ok)
    |> json(%{
      groups: Enum.map(groups, &serialize_group/1),
      synced_at: DateTime.utc_now()
    })
  end

  def show(conn, %{"id" => id}) do
    case Groups.get_group(id) do
      nil ->
        {:error, :not_found}

      group ->
        conn
        |> put_status(:ok)
        |> json(%{group: serialize_group(group)})
    end
  end

  def create(conn, %{"group" => group_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = decode_group_attrs(group_params)
    attrs = Map.put(attrs, "user_id", user.id)
    opts = [key: session_key, user: user]

    case Groups.create_group(attrs, opts) do
      {:ok, group} ->
        conn
        |> put_status(:created)
        |> json(%{
          group: serialize_group(group),
          message: "Group created successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{"id" => id, "group" => group_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Groups.get_group(id) do
      nil ->
        {:error, :not_found}

      group ->
        if can_manage_group?(group, user) do
          attrs = decode_group_attrs(group_params)
          attrs = Map.put(attrs, "user_id", user.id)
          opts = [key: session_key, user: user]

          case Groups.update_group(group, attrs, opts) do
            {:ok, updated_group} ->
              conn
              |> put_status(:ok)
              |> json(%{
                group: serialize_group(updated_group),
                message: "Group updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def update(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Groups.get_group(id) do
      nil ->
        {:error, :not_found}

      group ->
        if can_delete_group?(group, user) do
          case Groups.delete_group(group) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Group deleted successfully"})

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def list_unconfirmed(conn, params) do
    user = conn.assigns.current_user

    groups = Groups.list_unconfirmed_groups(user, parse_options(params))

    conn
    |> put_status(:ok)
    |> json(%{groups: Enum.map(groups, &serialize_group/1)})
  end

  def list_public(conn, params) do
    user = conn.assigns.current_user
    search_term = params["search"]

    groups = Groups.list_public_groups(user, search_term, parse_options(params))

    conn
    |> put_status(:ok)
    |> json(%{
      groups: Enum.map(groups, &serialize_group/1),
      count: Groups.public_group_count(user, search_term)
    })
  end

  def count(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> put_status(:ok)
    |> json(%{
      total: Groups.group_count(user),
      confirmed: Groups.group_count_confirmed(user)
    })
  end

  def filter_with_users(conn, %{"user_id" => user_id} = params) do
    current_user = conn.assigns.current_user

    groups = Groups.filter_groups_with_users(user_id, current_user.id, parse_options(params))

    conn
    |> put_status(:ok)
    |> json(%{groups: Enum.map(groups, &serialize_group/1)})
  end

  def filter_with_users(_conn, _params), do: {:error, :missing_params}

  def join(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Groups.get_group(id) do
      nil ->
        {:error, :not_found}

      %Group{public?: true} = group ->
        opts = [join_password: params["password"]]

        case Groups.join_public_group(group, user, session_key, opts) do
          {:ok, user_group} ->
            group = Groups.get_group!(group.id)

            conn
            |> put_status(:ok)
            |> json(%{
              group: serialize_group(group),
              user_group: serialize_user_group(user_group),
              message: "Successfully joined group"
            })

          {:error, :blocked} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "You are blocked from this group"})

          {:error, changeset} ->
            {:error, changeset}
        end

      %Group{public?: false} ->
        {:error, :forbidden}
    end
  end

  def list_members(conn, %{"group_id" => group_id}) do
    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        user_groups = Groups.list_user_groups(group)

        conn
        |> put_status(:ok)
        |> json(%{members: Enum.map(user_groups, &serialize_user_group/1)})
    end
  end

  def create_user_group(conn, %{"user_group" => user_group_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = decode_user_group_attrs(user_group_params)
    opts = [key: session_key, user: user]

    case Groups.create_user_group(attrs, opts) do
      {:ok, {:ok, user_group}} ->
        conn
        |> put_status(:created)
        |> json(%{
          user_group: serialize_user_group(user_group),
          message: "Member added successfully"
        })

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_user_group(_conn, _params), do: {:error, :missing_params}

  def show_user_group(conn, %{"id" => id}) do
    case Groups.get_user_group(id) do
      nil ->
        {:error, :not_found}

      user_group ->
        conn
        |> put_status(:ok)
        |> json(%{user_group: serialize_user_group(user_group)})
    end
  end

  def update_user_group(conn, %{"id" => id, "user_group" => user_group_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Groups.get_user_group(id) do
      nil ->
        {:error, :not_found}

      user_group ->
        group = Groups.get_group!(user_group.group_id)

        if can_manage_group?(group, user) do
          attrs = decode_user_group_attrs(user_group_params)
          opts = [key: session_key, user: user]

          case Groups.update_user_group(user_group, attrs, opts) do
            {:ok, updated_user_group} ->
              conn
              |> put_status(:ok)
              |> json(%{
                user_group: serialize_user_group(updated_user_group),
                message: "Member updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def update_user_group(_conn, _params), do: {:error, :missing_params}

  def update_user_group_role(conn, %{"user_group_id" => user_group_id, "role" => role}) do
    user = conn.assigns.current_user

    case Groups.get_user_group(user_group_id) do
      nil ->
        {:error, :not_found}

      user_group ->
        group = Groups.get_group!(user_group.group_id)

        if can_manage_group?(group, user) do
          case Groups.update_user_group_role(user_group, role) do
            {:ok, updated_user_group} ->
              conn
              |> put_status(:ok)
              |> json(%{
                user_group: serialize_user_group(updated_user_group),
                message: "Role updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def update_user_group_role(_conn, _params), do: {:error, :missing_params}

  def delete_user_group(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Groups.get_user_group(id) do
      nil ->
        {:error, :not_found}

      user_group ->
        group = Groups.get_group!(user_group.group_id)
        is_self = user_group.user_id == user.id

        if is_self || can_manage_group?(group, user) do
          case Groups.delete_user_group(user_group) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Member removed successfully"})

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def confirm_user_group(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Groups.get_user_group(id) do
      nil ->
        {:error, :not_found}

      user_group ->
        if user_group.user_id == user.id do
          case Groups.adapter().join_group_confirm(user_group) do
            {:ok, confirmed_user_group} ->
              conn
              |> put_status(:ok)
              |> json(%{
                user_group: serialize_user_group(confirmed_user_group),
                message: "Group membership confirmed"
              })

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def list_blocked(conn, %{"group_id" => group_id}) do
    user = conn.assigns.current_user

    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        if can_manage_group?(group, user) do
          blocks = Groups.list_blocked_users(group)

          conn
          |> put_status(:ok)
          |> json(%{blocks: Enum.map(blocks, &serialize_group_block/1)})
        else
          {:error, :forbidden}
        end
    end
  end

  def check_blocked(conn, %{"group_id" => group_id, "user_id" => user_id}) do
    blocked = Groups.user_blocked?(group_id, user_id)

    conn
    |> put_status(:ok)
    |> json(%{blocked: blocked})
  end

  def show_block(conn, %{"group_id" => group_id, "user_id" => user_id}) do
    case Groups.get_group_block(group_id, user_id) do
      nil ->
        {:error, :not_found}

      block ->
        conn
        |> put_status(:ok)
        |> json(%{block: serialize_group_block(block)})
    end
  end

  def create_block(conn, %{"group_id" => group_id, "user_id" => blocked_user_id}) do
    user = conn.assigns.current_user

    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        if can_manage_group?(group, user) do
          case Groups.adapter().block_member_multi(group, blocked_user_id) do
            {:ok, %{insert_block: block}} ->
              conn
              |> put_status(:created)
              |> json(%{
                block: serialize_group_block(block),
                message: "User blocked from group"
              })

            {:error, _, changeset, _} ->
              {:error, changeset}

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def create_block(_conn, _params), do: {:error, :missing_params}

  def delete_block(conn, %{"group_id" => group_id, "id" => block_id}) do
    user = conn.assigns.current_user

    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        if can_manage_group?(group, user) do
          case Groups.get_group_block!(block_id) do
            nil ->
              {:error, :not_found}

            block ->
              case Groups.adapter().delete_group_block(block) do
                {:ok, _} ->
                  conn
                  |> put_status(:ok)
                  |> json(%{message: "User unblocked from group"})

                {:error, error} ->
                  {:error, error}
              end
          end
        else
          {:error, :forbidden}
        end
    end
  end

  defp can_manage_group?(group, user) do
    user_group = Groups.get_user_group_for_group_and_user(group, user)
    user_group && user_group.role in [:owner, :admin]
  end

  defp can_delete_group?(group, user) do
    user_group = Groups.get_user_group_for_group_and_user(group, user)
    user_group && user_group.role == :owner
  end

  defp serialize_group(nil), do: nil

  defp serialize_group(%Group{} = group) do
    %{
      id: group.id,
      name: encode_binary(group.name),
      name_hash: encode_binary(group.name_hash),
      description: encode_binary(group.description),
      avatar_url: encode_binary(group.avatar_url),
      public: group.public?,
      require_password: group.require_password?,
      member_count: length(group.user_groups || []),
      inserted_at: group.inserted_at,
      updated_at: group.updated_at,
      user_groups: Enum.map(group.user_groups || [], &serialize_user_group/1)
    }
  end

  defp serialize_user_group(nil), do: nil

  defp serialize_user_group(%UserGroup{} = user_group) do
    %{
      id: user_group.id,
      user_id: user_group.user_id,
      group_id: user_group.group_id,
      name: encode_binary(user_group.name),
      key: encode_binary(user_group.key),
      role: to_string(user_group.role),
      confirmed_at: user_group.confirmed_at,
      inserted_at: user_group.inserted_at,
      updated_at: user_group.updated_at
    }
  end

  defp serialize_group_block(nil), do: nil

  defp serialize_group_block(block) do
    %{
      id: block.id,
      group_id: block.group_id,
      user_id: block.user_id,
      blocker_id: block.blocker_id,
      inserted_at: block.inserted_at
    }
  end

  defp encode_binary(nil), do: nil
  defp encode_binary(data) when is_binary(data), do: Base.encode64(data)

  defp decode_binary(nil), do: nil

  defp decode_binary(data) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> decoded
      :error -> data
    end
  end

  defp decode_group_attrs(params) when is_map(params) do
    %{
      "name" => decode_binary(params["name"]),
      "name_hash" => decode_binary(params["name_hash"]),
      "description" => decode_binary(params["description"]),
      "avatar_url" => decode_binary(params["avatar_url"]),
      "public?" => params["public"],
      "require_password?" => params["require_password"],
      "password" => params["password"],
      "users" => params["users"] || []
    }
  end

  defp decode_group_attrs(_), do: %{}

  defp decode_user_group_attrs(params) when is_map(params) do
    %{
      "name" => decode_binary(params["name"]),
      "key" => decode_binary(params["key"]),
      "role" => params["role"],
      "group_id" => params["group_id"],
      "user_id" => params["user_id"]
    }
  end

  defp decode_user_group_attrs(_), do: %{}

  defp parse_options(params) do
    opts = []

    opts =
      if params["page"],
        do: Keyword.put(opts, :page, String.to_integer(params["page"])),
        else: opts

    opts =
      if params["per_page"],
        do: Keyword.put(opts, :per_page, String.to_integer(params["per_page"])),
        else: opts

    opts
  end
end
