defmodule Mosslet.UserConnectionFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mosslet.Accounts` context.
  """

  def unique_username, do: Faker.Internet.user_name()

  def valid_user_connection_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      # for testing we currently force the selection by username
      "color" => attrs["color"] || "emerald",
      "connection_id" => attrs["connection_id"],
      "temp_label" => attrs["temp_label"] || "friend",
      "reverse_user_id" => attrs["reverse_user_id"],
      "selector" => "username",
      "username" => attrs["username"] || unique_username(),
      "user_id" => attrs["user_id"]
    })
  end

  @doc """
  Generate a user_connection.
  """
  def user_connection_fixture(attrs \\ %{}, options \\ []) do
    key = options[:key]
    r_key = options[:r_key]
    user = options[:user]
    reverse_user = options[:reverse_user]

    attrs =
      attrs
      |> valid_user_connection_attributes()

    uconn_changeset =
      Mosslet.Accounts.change_user_connection(%Mosslet.Accounts.UserConnection{}, attrs,
        selector: attrs["selector"],
        user: user,
        key: key
      )

    upd_attrs =
      uconn_changeset.changes

    {:ok, user_connection} =
      Mosslet.Accounts.create_user_connection(upd_attrs,
        user: user,
        key: key
      )

    # maybe create the confirmed user_connection for reverse_user
    if options[:confirm?] do
      {:ok, d_r_conn_key} =
        Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
          reverse_user.conn_key,
          reverse_user,
          r_key
        )

      d_req_email =
        Mosslet.Encrypted.Users.Utils.decrypt_user_item(
          user_connection.request_email,
          reverse_user,
          user_connection.key,
          r_key
        )

      d_req_username =
        Mosslet.Encrypted.Users.Utils.decrypt_user_item(
          user_connection.request_username,
          reverse_user,
          user_connection.key,
          r_key
        )

      d_label =
        Mosslet.Encrypted.Users.Utils.decrypt_user_item(
          user_connection.label,
          reverse_user,
          user_connection.key,
          r_key
        )

      # TODO
      # reverse_user_id is the requesting user when accepting
      # req_user = Accounts.get_user_by_email(d_req_email)

      confirm_attrs =
        %{
          key: d_r_conn_key,
          connection_id: reverse_user.connection.id,
          user_id: user_connection.reverse_user_id,
          reverse_user_id: reverse_user.id,
          email: d_req_email,
          username: d_req_username,
          temp_label: d_label,
          request_username: d_req_username,
          request_email: d_req_email,
          color: user_connection.color
        }

      {:ok, user_connection, _ins_uconn} =
        Mosslet.Accounts.confirm_user_connection(user_connection, confirm_attrs,
          user: reverse_user,
          key: r_key,
          confirm: true
        )

      user_connection
    else
      user_connection
    end
  end
end
