defmodule Mosslet.AccountsTest do
  use Mosslet.DataCase

  # Import conveniences for testing with connections
  import MossletWeb.ConnCase

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  alias Mosslet.Accounts.{User, UserToken}

  @valid_password "hello world hello world!"
  @valid_email "valid@example.com"

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = _user = user_fixture(%{email: @valid_email})
      assert %User{id: ^id} = Accounts.get_user_by_email(@valid_email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      _user = user_fixture(%{email: @valid_email})
      refute Accounts.get_user_by_email_and_password(@valid_email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = _user = user_fixture(%{email: @valid_email})

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(@valid_email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(Ecto.UUID.bingenerate() |> Ecto.UUID.cast!())
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "raises function clause error without changeset" do
      assert_raise FunctionClauseError,
                   "no function clause matching in Mosslet.Accounts.register_user/2",
                   fn ->
                     Accounts.register_user(%{email: "not valid", password: "not valid"})
                   end
    end

    test "invalid changeset if empty" do
      {:error, changeset} =
        Accounts.register_user(%Ecto.Changeset{}, %{})

      assert %{} = errors_on(changeset)
      assert changeset.valid? == false
    end

    test "validates email and password when given" do
      changeset =
        Accounts.change_user_registration(%User{}, %{email: "not valid", password: "not valid"})

      {:error, changeset} = Accounts.register_user(changeset)

      assert ["invalid or not a valid domain", "must have the @ sign and no spaces"] =
               errors_on(changeset).email

      assert [
               "try putting an extra word, number, or dash",
               "may be cracked in less than a second to less than a second",
               "should be at least 12 character(s)"
             ] = errors_on(changeset).password
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)

      changeset =
        Accounts.change_user_registration(%User{}, %{email: too_long, password: too_long})

      {:error, changeset} = Accounts.register_user(changeset)
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "requires password reminder" do
      changeset =
        Accounts.change_user_registration(%User{}, %{
          email: @valid_email,
          password: @valid_password
        })

      {:error, changeset} = Accounts.register_user(changeset)

      assert "please take a moment to understand and agree before continuing" in errors_on(
               changeset
             ).password_reminder
    end

    test "requires username" do
      changeset =
        Accounts.change_user_registration(%User{}, %{
          email: @valid_email,
          password: @valid_password,
          password_reminder: true
        })

      {:error, changeset} = Accounts.register_user(changeset)

      assert "can't be blank" in errors_on(changeset).username
    end

    test "validates email uniqueness" do
      user_changeset =
        Accounts.User.registration_changeset(%Mosslet.Accounts.User{}, %{
          email: @valid_email,
          password: @valid_password,
          password_reminder: true,
          username: unique_username()
        })

      c_attrs = user_changeset.changes.connection_map

      {:ok, _user} = Mosslet.Accounts.register_user(user_changeset, c_attrs)

      email = @valid_email

      changeset =
        Accounts.User.registration_changeset(%User{}, %{
          username: unique_username(),
          email: email,
          password: @valid_password,
          password_reminder: true
        })

      {:error, changeset} =
        Accounts.register_user(changeset, %{email: email})

      assert "invalid or already taken" in errors_on(changeset).email_hash

      # Now try with the upper cased email too, to check that email case is ignored.
      upper_changeset =
        Accounts.User.registration_changeset(%User{}, %{
          username: unique_username(),
          email: String.upcase(email),
          password: @valid_password,
          password_reminder: true
        })

      {:error, _changeset} =
        Accounts.register_user(upper_changeset, %{email: String.upcase(email)})

      assert "invalid or already taken" in errors_on(upper_changeset).email_hash
    end

    test "registers users with an encrypted email and username; and a hashed password, username, and email" do
      email = unique_user_email()
      username = unique_username()

      changeset =
        Accounts.User.registration_changeset(
          %User{},
          valid_user_attributes(email: email, username: username)
        )

      c_attrs = changeset.changes.connection_map

      {:ok, user} = Accounts.register_user(changeset, c_attrs)
      assert user.email != email
      assert user.username != username
      assert is_binary(user.hashed_password)
      assert is_binary(user.email_hash)
      assert is_binary(user.username_hash)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :username, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change", "invalid or not a valid domain"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["invalid or not a valid domain", "must have the @ sign and no spaces"]} =
               errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: _email} = user_fixture(%{email: @valid_email})
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: @valid_email})

      assert "invalid or already taken" in errors_on(changeset).email_hash
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture(%{email: @valid_email})}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn _url ->
          Accounts.deliver_user_update_email_instructions(
            user,
            @valid_email,
            "current@example.com",
            &url(~p"/app/users/settings/confirm-email/#{&1}")
          )
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha512, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == "current@example.com"
      assert user_token.context == "change:#{@valid_email}"
    end
  end

  describe "update_user_email/4" do
    setup do
      user = user_fixture(%{email: @valid_email})
      email = unique_user_email()

      token =
        extract_user_token(fn _url ->
          Accounts.deliver_user_update_email_instructions(
            user,
            @valid_email,
            email,
            &url(~p"/app/users/settings/confirm-email/#{&1}")
          )
        end)

      %{
        user: user,
        token: token,
        d_email: @valid_email,
        email: email,
        conn: Phoenix.ConnTest.build_conn()
      }
    end

    test "updates the email with a valid token", %{
      user: user,
      token: token,
      d_email: d_email,
      email: email,
      conn: conn
    } do
      key = get_key_from_user_session(conn, user)
      context = "change:#{@valid_email}"

      assert Accounts.update_user_email(user, d_email, token, key) == :ok
      changed_user = Repo.get!(User, user.id)

      # decrypt the email
      d_email = decrypt_user_data(changed_user.email, user, key)

      assert changed_user.email_hash != user.email_hash
      assert changed_user.email != email
      assert d_email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id, context: context)
    end

    test "does not update email with invalid token", %{
      user: user,
      d_email: d_email,
      conn: conn
    } do
      key = get_key_from_user_session(conn, user)
      context = "change:#{@valid_email}"

      assert Accounts.update_user_email(user, d_email, "oops", key) == :error

      # decrypt the emails
      existing_user_email = decrypt_user_data(user.email, user, key)
      db_user = Repo.get!(User, user.id)
      db_user_email = decrypt_user_data(db_user.email, db_user, key)

      assert db_user_email == existing_user_email
      assert Repo.get_by(UserToken, user_id: user.id, context: context)
    end

    test "does not update email if user email changed", %{
      user: user,
      d_email: _d_email,
      token: token,
      conn: conn
    } do
      key = get_key_from_user_session(conn, user)
      context = "change:#{@valid_email}"

      assert Accounts.update_user_email(
               %{user | email: "current@example.com"},
               "current@example.com",
               token,
               key
             ) == :error

      # decrypt the emails
      existing_user_email = decrypt_user_data(user.email, user, key)
      db_user = Repo.get!(User, user.id)
      db_user_email = decrypt_user_data(db_user.email, db_user, key)

      assert db_user_email == existing_user_email
      assert Repo.get_by(UserToken, user_id: user.id, context: context)
    end

    test "does not update email if token expired", %{
      user: user,
      d_email: d_email,
      token: token,
      conn: conn
    } do
      key = get_key_from_user_session(conn, user)
      context = "change:#{@valid_email}"

      {_count, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, d_email, token, key) == :error

      # decrypt the emails
      existing_user_email = decrypt_user_data(user.email, user, key)
      db_user = Repo.get!(User, user.id)
      db_user_email = decrypt_user_data(db_user.email, db_user, key)

      assert db_user_email == existing_user_email
      assert Repo.get_by(UserToken, user_id: user.id, context: context)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture(%{email: @valid_email})}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(
          user,
          valid_user_password(),
          %{
            password: "not valid",
            password_confirmation: "another"
          },
          []
        )

      assert %{
               password: [
                 "try putting an extra word, number, or dash",
                 "may be cracked in less than a second to 1 hour",
                 "should be at least 12 character(s)"
               ],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long}, [])

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()}, [])

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(
          user,
          valid_user_password(),
          %{
            password: "new valid password hello!"
          },
          []
        )

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(@valid_email, "new valid password hello!")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(
          user,
          valid_user_password(),
          %{
            password: "new valid password hello!"
          },
          []
        )

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{
        user: user_fixture(%{email: @valid_email, confirm: false}),
        conn: Phoenix.ConnTest.build_conn()
      }
    end

    test "sends token through notification", %{user: user, conn: conn} do
      key = get_key_from_user_session(conn, user)

      token =
        extract_user_token(fn _url ->
          Accounts.deliver_user_confirmation_instructions(
            user,
            @valid_email,
            &url(~p"/auth/confirm/#{&1}")
          )
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha512, token))
      assert user_token.user_id == user.id

      user_email = decrypt_user_data(user.email, user, key)
      assert user_token.sent_to == user_email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture(%{email: @valid_email, confirm: false})

      token =
        extract_user_token(fn _url ->
          Accounts.deliver_user_confirmation_instructions(
            user,
            @valid_email,
            &url(~p"/auth/confirm/#{&1}")
          )
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {_count, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture(%{email: @valid_email}), conn: Phoenix.ConnTest.build_conn()}
    end

    test "sends token through notification", %{user: user, conn: conn} do
      key = get_key_from_user_session(conn, user)

      token =
        extract_user_token(fn _url ->
          Accounts.deliver_user_reset_password_instructions(
            user,
            @valid_email,
            &url(~p"/auth/reset-password/#{&1}")
          )
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha512, token))
      assert user_token.user_id == user.id

      user_email = decrypt_user_data(user.email, user, key)
      assert user_token.sent_to == user_email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture(%{email: @valid_email})

      token =
        extract_user_token(fn _url ->
          Accounts.deliver_user_reset_password_instructions(
            user,
            @valid_email,
            &url(~p"/auth/reset-password/#{&1}")
          )
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture(%{email: @valid_email})}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: [
                 "try putting an extra word, number, or dash",
                 "may be cracked in less than a second to 1 hour",
                 "should be at least 12 character(s)"
               ],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} =
        Accounts.reset_user_password(user, %{password: "new valid password hello!"})

      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(@valid_email, "new valid password hello!")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  defp get_key_from_user_session(conn, user) do
    conn =
      conn
      |> log_in_user(user)
      |> MossletWeb.UserAuth.put_user_into_session(user, %{"password" => @valid_password})

    conn.private.plug_session["key"]
  end

  defp decrypt_user_data(payload, user, session_key) do
    Mosslet.Encrypted.Users.Utils.decrypt_user_data(
      payload,
      user,
      session_key
    )
  end
end
