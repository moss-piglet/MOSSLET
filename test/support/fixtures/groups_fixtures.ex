defmodule Mosslet.GroupsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mosslet.Groups` context.
  """

  @valid_password "hello world hello world"

  def unique_user_email, do: Faker.Internet.email()
  def unique_username, do: Faker.Internet.user_name()

  def valid_group_attributes(attrs \\ %{}, options \\ []) do
    Enum.into(attrs, %{
      name: attrs[:name] || "some name",
      name_hash: attrs[:name_hash] || "some name",
      description: attrs[:description] || "some description",
      password: attrs[:password] || @valid_password,
      require_password?: attrs[:require_password?] || options[:require_password?],
      public?: attrs[:public?] || false,
      user_id: attrs[:user_id] || options[:user].id,
      # used when making user_group
      user_name: attrs[:name] || "some name",
      users: attrs[:users] || attrs["users"] || []
    })
  end

  @doc """
  Generate a group.
  """
  def group_fixture(attrs \\ %{}, options \\ []) do
    key = options[:key]
    require_password? = attrs[:require_password?] || options[:require_password?] || false

    username = attrs[:username] || unique_username()
    password = attrs[:password] || @valid_password

    user =
      options[:user] ||
        Mosslet.AccountsFixtures.user_fixture(%{
          username: username,
          email: unique_user_email(),
          password: password
        })

    attrs =
      attrs
      |> valid_group_attributes(options)

    {:ok, group} =
      Mosslet.Groups.create_group(attrs,
        user: user,
        key: key,
        require_password?: require_password?
      )

    # return the post from the db to update the encrypted fields
    Mosslet.Groups.get_group!(group.id)
  end
end
