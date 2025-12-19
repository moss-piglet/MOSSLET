defmodule Mosslet.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mosslet.Accounts` context.
  """

  def unique_user_email, do: Faker.Internet.email()
  def unique_username, do: Faker.Internet.user_name()
  def valid_user_password, do: "hello world hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: attrs[:email] || unique_user_email(),
      password: attrs[:password] || valid_user_password(),
      password_reminder: attrs[:password_reminder] || true,
      username: attrs[:username] || unique_username(),
      is_onboarded?: attrs[:is_onboarded?] || false,
      connection_map: %{}
    })
  end

  def user_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> valid_user_attributes()

    # we use the changeset directly because we want to hash the password
    # if we go through the accounts changeset, it will not hash the password
    # because we use that for validating the changeset on the UI side
    user_changeset =
      Mosslet.Accounts.User.registration_changeset(%Mosslet.Accounts.User{}, attrs)

    c_attrs = Map.get(user_changeset.changes, :connection_map, %{})

    {:ok, user} = Mosslet.Accounts.register_user(user_changeset, c_attrs)

    # the user needs to be reloaded to get the hashed email/username attrs
    user = Mosslet.Accounts.get_user_with_preloads(user.id)

    # Confirm the user by default so tests don't fail on email confirmation checks
    Mosslet.Accounts.confirm_user!(user)
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    # this is only used in testing and was apparently an older way of doing it
    # [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    # with our current email templates/layouts we need to grab the token another way
    token = String.split(captured_email.assigns.url, "/") |> List.last()

    token =
      if String.contains?(token, "[TOKEN]"), do: String.replace(token, "[TOKEN]", ""), else: token

    token
  end
end
