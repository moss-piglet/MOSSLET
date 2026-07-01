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

  describe "recovery-key gate" do
    setup :onboarded_user

    test "hides/disables enroll and shows the gate notice without a recovery key", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      assert has_element?(view, "#prf-recovery-gate")
      assert has_element?(view, "#prf-enroll-btn[disabled]")
    end

    test "enables the enroll CTA once a recovery key exists", %{conn: conn, user: user} do
      with_recovery(user)

      {:ok, view, _html} = live(conn, @path)

      refute has_element?(view, "#prf-recovery-gate")
      refute has_element?(view, "#prf-enroll-btn[disabled]")
      assert has_element?(view, "#prf-enroll-btn")
    end
  end

  describe "enroll (OR → AND flip)" do
    setup :onboarded_user

    test "storing the pushed prf blob enrolls the device", %{conn: conn, user: user} do
      with_recovery(user)
      {:ok, view, _html} = live(conn, @path)

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
  end

  describe "un-enroll (no bricking)" do
    setup :onboarded_user

    test "removing the last device restores the password door", %{conn: conn, user: user} do
      with_recovery(user)
      {:ok, view, _html} = live(conn, @path)

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
      with_recovery(user)
      {:ok, view, _html} = live(conn, @path)

      render_hook(view, "prf_enrolled", prf_params())
      [wrap] = Accounts.list_user_key_wraps(user)

      render_hook(view, "prf_unenrolled", %{"wrap_id" => wrap.id})

      assert Accounts.prf_enrolled?(user)
      assert has_element?(view, "#prf-error")
    end
  end
end
