defmodule MossletWeb.EditDeviceUnlockLiveTest do
  @moduledoc """
  LiveView coverage for the WebAuthn PRF device-unlock settings page (#365).

  The browser crypto (`PrfEnrollmentHook`) is out of scope here — these tests
  drive the server-side handle_event contract with the opaque blobs the hook
  would push, and assert the recovery-key gate + enroll/un-enroll flows keyed
  off DOM IDs. See `docs/WEBAUTHN_PRF_DESIGN.md`.
  """
  use MossletWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Mosslet.Accounts
  import Mosslet.AccountsFixtures

  @path "/app/users/device-unlock"

  defp onboarded_user(%{conn: conn}) do
    user = user_fixture()
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    %{conn: log_in_user(conn, user), user: user}
  end

  defp prf_params(overrides \\ %{}) do
    Map.merge(
      %{
        "wrapped_user_key" => "opaque-prf-wrap-blob",
        "wrap_salt" => "cHJmc2FsdA==",
        "credential_id" => "credential-abc",
        "prf_salt" => "cHJmZXZhbHNhbHQ=",
        "ecosystem_hint" => "apple"
      },
      overrides
    )
  end

  defp with_recovery(user) do
    {:ok, user} =
      Accounts.setup_recovery_key(user, "recovery-secret-256bit", "encrypted-recovery-priv-blob")

    user
  end

  # Path carrying a fresh recovery-confirmation token (#364) — simulates arriving
  # from the recovery-confirm step.
  defp fresh_path(user) do
    @path <> "?rc=" <> Accounts.sign_recovery_confirmation(user)
  end

  describe "recovery-key gate (three states, #364)" do
    setup :onboarded_user

    test "absent: shows the setup gate and disables enroll", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      assert has_element?(view, "#prf-recovery-gate")
      assert has_element?(view, "#prf-recovery-setup-link")
      refute has_element?(view, "#prf-recovery-confirm-gate")
      assert has_element?(view, "#prf-enroll-btn[disabled]")
    end

    test "present but not fresh: shows the confirm gate and disables enroll", %{
      conn: conn,
      user: user
    } do
      with_recovery(user)

      {:ok, view, _html} = live(conn, @path)

      refute has_element?(view, "#prf-recovery-gate")
      assert has_element?(view, "#prf-recovery-confirm-gate")
      assert has_element?(view, "#prf-recovery-confirm-link")
      assert has_element?(view, "#prf-enroll-btn[disabled]")
    end

    test "fresh: enables the enroll CTA", %{conn: conn, user: user} do
      user = with_recovery(user)

      {:ok, view, _html} = live(conn, fresh_path(user))

      refute has_element?(view, "#prf-recovery-gate")
      refute has_element?(view, "#prf-recovery-confirm-gate")
      assert has_element?(view, "#prf-recovery-fresh")
      assert has_element?(view, "#prf-enroll-btn")
      refute has_element?(view, "#prf-enroll-btn[disabled]")
    end

    test "a bad/expired token is treated as not fresh", %{conn: conn, user: user} do
      with_recovery(user)

      {:ok, view, _html} = live(conn, @path <> "?rc=garbage")

      assert has_element?(view, "#prf-recovery-confirm-gate")
      assert has_element?(view, "#prf-enroll-btn[disabled]")
    end
  end

  describe "enroll (OR → AND flip)" do
    setup :onboarded_user

    test "storing the pushed prf blob enrolls the device", %{conn: conn, user: user} do
      user = with_recovery(user)
      {:ok, view, _html} = live(conn, fresh_path(user))

      render_hook(view, "prf_enrolled", prf_params())

      assert Accounts.prf_enrolled?(user)
      assert has_element?(view, "#prf-device-list")
      assert has_element?(view, "#prf-add-device-btn")
    end

    test "refuses enrollment without a recovery key", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, @path)

      render_hook(view, "prf_enrolled", prf_params())

      refute Accounts.prf_enrolled?(user)
      assert has_element?(view, "#prf-error")
    end

    test "refuses enrollment when recovery present but not freshly confirmed", %{
      conn: conn,
      user: user
    } do
      with_recovery(user)
      {:ok, view, _html} = live(conn, @path)

      render_hook(view, "prf_enrolled", prf_params())

      refute Accounts.prf_enrolled?(user)
      assert has_element?(view, "#prf-error")
    end
  end

  describe "un-enroll (no bricking)" do
    setup :onboarded_user

    test "removing the last device restores the password door", %{conn: conn, user: user} do
      user = with_recovery(user)
      {:ok, view, _html} = live(conn, fresh_path(user))

      render_hook(view, "prf_enrolled", prf_params())
      assert Accounts.prf_enrolled?(user)

      [wrap] = Accounts.list_user_key_wraps(user)

      render_hook(view, "prf_unenrolled", %{
        "wrap_id" => wrap.id,
        "wrapped_user_key" => "opaque-password-wrap-blob",
        "wrap_salt" => "cGFzc3NhbHQ="
      })

      refute Accounts.prf_enrolled?(user)
      assert [%{kind: :password}] = Accounts.list_user_key_wraps(user)
    end

    test "removing the last device without a password wrap errors and stays enrolled", %{
      conn: conn,
      user: user
    } do
      user = with_recovery(user)
      {:ok, view, _html} = live(conn, fresh_path(user))

      render_hook(view, "prf_enrolled", prf_params())
      [wrap] = Accounts.list_user_key_wraps(user)

      render_hook(view, "prf_unenrolled", %{"wrap_id" => wrap.id})

      assert Accounts.prf_enrolled?(user)
      assert has_element?(view, "#prf-error")
    end
  end
end
