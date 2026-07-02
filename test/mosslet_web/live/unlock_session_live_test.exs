defmodule MossletWeb.UnlockSessionLiveTest do
  @moduledoc """
  New-device bootstrap unlock via recovery key (board #366, design §8).

  An enrolled account on a device with no local passkey has no password-only
  door, so the unlock page offers a recovery-key unlock. The browser crypto
  (`RecoveryUnlockHook`) is out of scope here — these tests drive the
  server-side handle_event contract: the recovery secret is verified and, on
  success, a fresh recovery-confirmation token is minted so the user can enroll
  this device afterwards.
  """
  use MossletWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  @password "hello world hello world!"
  @recovery_secret "recovery-secret-256bit"

  defp enroll(user) do
    {:ok, user} = Accounts.setup_recovery_key(user, @recovery_secret, "enc-recovery-blob")

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

  describe "recovery-unlock section" do
    test "enrolled account sees the recovery-key unlock affordance", %{conn: conn} do
      user = user_fixture(%{password: @password}) |> enroll()

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/auth/unlock")

      assert has_element?(view, "#recovery-unlock-details")
      assert has_element?(view, "#recovery-unlock-btn")
    end

    test "non-enrolled account does not see the recovery-key unlock affordance", %{conn: conn} do
      user = user_fixture(%{password: @password})

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/auth/unlock")

      refute has_element?(view, "#recovery-unlock-details")
    end

    test "a valid recovery secret verifies (reply ok) — enabling the device-enroll follow-up", %{
      conn: conn
    } do
      user = user_fixture(%{password: @password}) |> enroll()

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/auth/unlock")

      assert render_hook(view, "recovery_unlock_verify", %{"recovery_secret" => @recovery_secret})
      refute has_element?(view, "#recovery-unlock-error")
    end

    test "a wrong recovery secret surfaces an error and mints no token", %{conn: conn} do
      user = user_fixture(%{password: @password}) |> enroll()

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/auth/unlock")

      render_hook(view, "recovery_unlock_verify", %{"recovery_secret" => "wrong-secret"})

      assert has_element?(view, "#recovery-unlock-error")
    end
  end
end
