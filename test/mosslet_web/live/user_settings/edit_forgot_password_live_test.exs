defmodule MossletWeb.EditForgotPasswordLiveTest do
  @moduledoc """
  LiveView coverage for the recovery-confirm step that gates PRF enrollment
  (board #364). The browser crypto (`RecoveryKeyConfirmHook` /
  `RecoveryKeySetupHook`) is out of scope — these tests drive the server-side
  handle_event contract with the secret the hook would push.
  """
  use MossletWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  @confirm_path "/app/users/change-forgot-password?confirm_for=device-unlock"

  defp onboarded_user(%{conn: conn}) do
    user = user_fixture()
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    %{conn: log_in_user(conn, user), user: user}
  end

  defp with_recovery(user) do
    {:ok, user} =
      Accounts.setup_recovery_key(user, "recovery-secret-256bit", "encrypted-recovery-priv-blob")

    user
  end

  describe "confirm existing recovery key (routed from device-unlock)" do
    setup :onboarded_user

    test "shows the confirm form when routed with a recovery key present", %{
      conn: conn,
      user: user
    } do
      with_recovery(user)

      {:ok, view, _html} = live(conn, @confirm_path)

      assert has_element?(view, "#recovery-key-confirm-form")
    end

    test "a correct recovery secret redirects to device-unlock with a fresh token", %{
      conn: conn,
      user: user
    } do
      with_recovery(user)
      {:ok, view, _html} = live(conn, @confirm_path)

      assert {:error, {:live_redirect, %{to: to}}} =
               render_hook(view, "verify_recovery_secret", %{
                 "recovery_secret" => "recovery-secret-256bit"
               })

      assert to =~ "/app/users/device-unlock?rc="

      # the minted token is genuinely fresh for this user
      "/app/users/device-unlock?rc=" <> token = to
      assert Accounts.recovery_confirmation_fresh?(user, token)
    end

    test "a wrong recovery secret shows an error and does not redirect", %{
      conn: conn,
      user: user
    } do
      with_recovery(user)
      {:ok, view, _html} = live(conn, @confirm_path)

      html =
        render_hook(view, "verify_recovery_secret", %{"recovery_secret" => "wrong-secret"})

      assert html =~ "didn&#39;t match" or html =~ "didn't match"
    end
  end
end
