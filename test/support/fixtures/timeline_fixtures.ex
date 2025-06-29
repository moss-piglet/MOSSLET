defmodule Mosslet.TimelineFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mosslet.Timeline` context.
  """
  @valid_password "hello world hello world"

  def unique_user_email, do: Faker.Internet.email()
  def unique_username, do: Faker.Internet.user_name()

  def valid_post_attributes(attrs \\ %{}, options \\ []) do
    Enum.into(attrs, %{
      avatar_url: attrs[:avatar_url] || nil,
      username: attrs[:username] || "some_username",
      username_hash: attrs[:username] || "some_username",
      favs_count: attrs[:favs_count] || 0,
      reposts_count: attrs[:reposts_count] || 0,
      favs_list: attrs[:favs_list] || [],
      user_id: attrs[:user_id] || options[:user].id,
      visibility: attrs[:visibility] || "connections",
      group_id: attrs[:group_id] || nil,
      user_group_id: attrs[:user_group_id] || nil,
      body: attrs[:body] || "some body",
      image_urls: attrs[:image_urls] || [],
      image_urls_updated_at: attrs[:image_urls_updated_at] || nil
    })
  end

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}, options \\ []) do
    key = options[:key]
    trix_key = options[:trix_key]

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
      |> valid_post_attributes(options)

    {:ok, post} = Mosslet.Timeline.create_post(attrs, user: user, key: key, trix_key: trix_key)

    # return the post from the db to update the encrypted fields
    Mosslet.Timeline.get_post!(post.id)
  end
end
