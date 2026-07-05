defmodule MossletWeb.UnlockSessionControllerTest do
  @moduledoc """
  Board #370: PRF-enrolled accounts have NO `key_hash` password-only door, so
  the unlock endpoint accepts a browser-derived `user_key` (from
  KDF(password‖prf)) and trusts it ONLY for enrolled accounts. Non-enrolled
  accounts keep the legacy password path.
  """
  use MossletWeb.ConnCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  @password "hello world hello world!"

  defp enroll(user) do
    {:ok, user} = Accounts.setup_recovery_key(user, "recovery-secret-256bit", "enc-recovery-blob")

    {:ok, _} =
      Accounts.backfill_password_wrap(user, %{
        wrapped_user_key: "opaque-pw-blob",
        wrap_salt: "cGFzc3NhbHQ="
      })

    {:ok, _} =
      Accounts.enroll_prf_wrap(
        user,
        %{
          wrapped_user_key: "opaque-prf-blob",
          wrap_salt: "cHJmc2FsdA==",
          credential_id: "cred-abc",
          prf_salt: "cHJmZXZhbA=="
        },
        Accounts.sign_recovery_confirmation(user)
      )

    Accounts.get_user!(user.id)
  end

  describe "POST /auth/unlock with a client user_key" do
    test "enrolled account: puts the client key in the session and unlocks", %{conn: conn} do
      user = user_fixture(%{password: @password})
      {:ok, real_user_key} = Accounts.User.valid_key_hash?(user, @password)
      user = enroll(user)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/auth/unlock", %{"unlock" => %{"user_key" => real_user_key}})

      assert redirected_to(conn) == ~p"/app"
      assert get_session(conn, :key) == real_user_key
    end

    test "non-enrolled account: refuses a client user_key (no password door bypass)", %{
      conn: conn
    } do
      user = user_fixture(%{password: @password})

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/auth/unlock", %{"unlock" => %{"user_key" => "attacker-key"}})

      assert redirected_to(conn) == ~p"/auth/unlock"
      refute get_session(conn, :key) == "attacker-key"
    end
  end

  describe "POST /auth/unlock non-enrolled password path (board #375)" do
    # The unlock form now always renders empty hidden `unlock[user_key]`/
    # `unlock[wrap_id]` fields, so a normal password submit posts them empty.
    # The controller's user_key clause is guarded by `user_key != ""`, so this
    # must fall through to the legacy key_hash password path unchanged.
    test "correct password unlocks via key_hash despite empty user_key field", %{conn: conn} do
      user = user_fixture(%{password: @password})
      {:ok, real_key} = Accounts.User.valid_key_hash?(user, @password)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/auth/unlock", %{
          "unlock" => %{"password" => @password, "user_key" => "", "wrap_id" => ""}
        })

      assert redirected_to(conn) == ~p"/app"
      assert get_session(conn, :key) == real_key
    end

    test "wrong password is rejected", %{conn: conn} do
      user = user_fixture(%{password: @password})

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/auth/unlock", %{
          "unlock" => %{"password" => "nope nope nope nope!", "user_key" => ""}
        })

      assert redirected_to(conn) == ~p"/auth/unlock"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid password"
    end
  end

  describe "POST /auth/unlock new-device recovery bootstrap (board #366)" do
    test "with a fresh rc token: unlocks and routes to device-unlock to enroll", %{conn: conn} do
      user = user_fixture(%{password: @password})
      {:ok, real_user_key} = Accounts.User.valid_key_hash?(user, @password)
      user = enroll(user)
      rc = Accounts.sign_recovery_confirmation(user)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/auth/unlock", %{
          "unlock" => %{"user_key" => real_user_key, "rc" => rc}
        })

      assert redirected_to(conn) == ~p"/app/users/device-unlock?#{[rc: rc]}"
      assert get_session(conn, :key) == real_user_key
    end

    test "with a bogus rc token: still unlocks but routes to the app", %{conn: conn} do
      user = user_fixture(%{password: @password})
      {:ok, real_user_key} = Accounts.User.valid_key_hash?(user, @password)
      user = enroll(user)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/auth/unlock", %{
          "unlock" => %{"user_key" => real_user_key, "rc" => "not-a-token"}
        })

      assert redirected_to(conn) == ~p"/app"
      assert get_session(conn, :key) == real_user_key
    end

    test "reported wrap_id updates the device roster last_used_at", %{conn: conn} do
      user = user_fixture(%{password: @password})
      {:ok, real_user_key} = Accounts.User.valid_key_hash?(user, @password)
      user = enroll(user)

      [wrap] = Accounts.list_user_key_wraps(user)
      assert is_nil(wrap.last_used_at)

      conn
      |> log_in_user(user)
      |> post(~p"/auth/unlock", %{
        "unlock" => %{"user_key" => real_user_key, "wrap_id" => wrap.id}
      })

      [reloaded] = Accounts.list_user_key_wraps(user)
      assert %DateTime{} = reloaded.last_used_at
    end
  end
end
