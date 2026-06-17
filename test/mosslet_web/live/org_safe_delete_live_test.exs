defmodule MossletWeb.OrgSafeDeleteLiveTest do
  @moduledoc """
  LiveView flow for owner-facing safe org deletion (Task #227) on the Business
  dashboard danger zone: the affordance is owner-only, the typed-name + password
  confirmation is enforced, and a successful delete navigates the ex-owner away.
  """
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Jobs.OrgTeardownJob

  use Oban.Testing, repo: Mosslet.Repo

  @password "hello world hello world!"
  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp log_in(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end

  defp onboarded_user(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    {user, get_key(user)}
  end

  defp add_member(org, user) do
    {:ok, {:ok, _ms}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, user, :member) |> Mosslet.Repo.insert()
      end)

    :ok
  end

  # The Business dashboard redirects to /subscribe unless the org has an active
  # plan, so activate one before mounting.
  defp activate_org(org) do
    Mosslet.OrgsFixtures.ensure_org_subscription(org)
    :ok
  end

  describe "manage-organization menu visibility" do
    test "owner sees the manage menu with transfer + delete affordances", %{conn: conn} do
      {owner, key} = onboarded_user("owner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
      activate_org(org)

      {:ok, lv, _html} = conn |> log_in(owner, key) |> live(~p"/app/business/#{org.slug}")

      assert has_element?(lv, "#org-ownership-section")
      # The rare transfer/delete actions live in a calm dropdown, not always-on.
      assert has_element?(lv, "#org-manage-menu")

      menu_html = lv |> element("#org-manage-menu-menu") |> render()
      assert menu_html =~ "Delete organization"
    end

    test "non-owner member does NOT see the manage menu", %{conn: conn} do
      {owner, _ok} = onboarded_user("owner")
      {member, member_key} = onboarded_user("member")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
      add_member(org, member)
      activate_org(org)

      {:ok, lv, _html} = conn |> log_in(member, member_key) |> live(~p"/app/business/#{org.slug}")

      refute has_element?(lv, "#org-manage-menu")
      refute has_element?(lv, "#org-ownership-section")
    end
  end

  describe "delete confirmation flow" do
    test "opening the modal reveals the typed-name + password form", %{conn: conn} do
      {owner, key} = onboarded_user("owner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
      activate_org(org)

      {:ok, lv, _html} = conn |> log_in(owner, key) |> live(~p"/app/business/#{org.slug}")

      render_hook(lv, "open_delete_org_modal", %{})

      # The modal is teleported to <body> via a portal, so query its rendered HTML.
      modal_html = lv |> element("#delete-org-modal-portal") |> render()
      assert modal_html =~ "delete-org-form"
      assert modal_html =~ "delete-org-confirm-name"
      assert modal_html =~ "delete-org-submit"
    end

    test "a mismatched org name is refused and the org survives", %{conn: conn} do
      {owner, key} = onboarded_user("owner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
      activate_org(org)

      {:ok, lv, _html} = conn |> log_in(owner, key) |> live(~p"/app/business/#{org.slug}")

      render_hook(lv, "open_delete_org_modal", %{})

      # The form lives inside the body-portaled modal, so emit its submit event.
      html =
        render_hook(lv, "delete_org", %{
          "confirm_name" => "Wrong Name",
          "delete_org" => %{"password" => @password}
        })

      assert html =~ "didn&#39;t match"
      refute is_nil(Orgs.get_org_by_id(org.id))
      refute_enqueued(worker: OrgTeardownJob)
    end

    test "an incorrect password is refused and the org survives", %{conn: conn} do
      {owner, key} = onboarded_user("owner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
      activate_org(org)

      {:ok, lv, _html} = conn |> log_in(owner, key) |> live(~p"/app/business/#{org.slug}")

      render_hook(lv, "open_delete_org_modal", %{})

      html =
        render_hook(lv, "delete_org", %{
          "confirm_name" => "Acme Inc",
          "delete_org" => %{"password" => "wrong-password"}
        })

      assert html =~ "password is incorrect"
      refute is_nil(Orgs.get_org_by_id(org.id))
    end

    test "correct name + password deletes the org and navigates away", %{conn: conn} do
      {owner, key} = onboarded_user("owner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
      activate_org(org)

      {:ok, lv, _html} = conn |> log_in(owner, key) |> live(~p"/app/business/#{org.slug}")

      render_hook(lv, "open_delete_org_modal", %{})

      result =
        render_hook(lv, "delete_org", %{
          "confirm_name" => "Acme Inc",
          "delete_org" => %{"password" => @password}
        })

      assert {:error, {:live_redirect, %{to: "/app/business"}}} = result
      assert is_nil(Orgs.get_org_by_id(org.id))
      assert_enqueued(worker: OrgTeardownJob, args: %{"org_id" => org.id})
    end
  end
end
