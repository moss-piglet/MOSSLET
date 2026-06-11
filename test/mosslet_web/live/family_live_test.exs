defmodule MossletWeb.FamilyLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Orgs

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp to_letters(digits) do
    digits
    |> String.graphemes()
    |> Enum.map_join(fn d -> <<?a + String.to_integer(d)>> end)
  end

  defp log_in(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    key = get_key(user)

    name =
      "Person " <> (System.unique_integer([:positive]) |> Integer.to_string() |> to_letters())

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: name},
        change_name: true,
        key: key,
        user: user
      )

    {user, key}
  end

  describe "FamilyLive.Index" do
    test "lists families and creates a new one", %{conn: conn} do
      {user, key} = onboarded_user("familyadmin")

      conn = log_in(conn, user, key)
      {:ok, _lv, html} = live(conn, ~p"/app/family")
      assert html =~ "Family"
      assert html =~ "Start your family space"

      {:ok, new_lv, _html} = live(conn, ~p"/app/family/new")

      {:ok, show_lv, html} =
        new_lv
        |> form("#new-family-form", family: %{name: "The Testers"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "The Testers"
      assert has_element?(show_lv, "#establish-form, #invite-form")
    end
  end

  describe "FamilyLive.Show guardianship management" do
    setup do
      {admin, admin_key} = onboarded_user("orgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Smiths", "type" => "family"})

      {guardian, _gk} = onboarded_user("guard")
      {managed, managed_key} = onboarded_user("ward")

      {:ok, {:ok, _g_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, guardian, :guardian) |> Mosslet.Repo.insert()
        end)

      {:ok, {:ok, _m_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, managed, :managed_member) |> Mosslet.Repo.insert()
        end)

      %{
        admin: admin,
        admin_key: admin_key,
        org: org,
        guardian: guardian,
        managed: managed,
        managed_key: managed_key
      }
    end

    test "admin can establish a guardianship", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#establish-form")

      g_ms = Orgs.get_membership!(ctx.guardian, ctx.org.slug)
      m_ms = Orgs.get_membership!(ctx.managed, ctx.org.slug)

      lv
      |> element("#establish-form")
      |> render_submit(%{
        "guardian_membership_id" => g_ms.id,
        "managed_membership_id" => m_ms.id
      })

      assert [gship] = Orgs.list_guardianships_by_org(ctx.org)
      assert gship.status == :pending
      # Consent gate: pending => not co-sealed
      assert Orgs.list_active_guardian_users_for_user(ctx.managed.id) == []
    end

    test "managed member sees pending consent request and can accept", ctx do
      g_ms = Orgs.get_membership!(ctx.guardian, ctx.org.slug)
      m_ms = Orgs.get_membership!(ctx.managed, ctx.org.slug)
      {:ok, gship} = Orgs.establish_guardianship(g_ms, m_ms)

      {:ok, lv, html} =
        ctx.conn |> log_in(ctx.managed, ctx.managed_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert html =~ "Guardianship requests"
      assert has_element?(lv, "#accept-#{gship.id}")

      lv |> element("#accept-#{gship.id}") |> render_click()

      assert [updated] = Orgs.list_guardianships_by_org(ctx.org)
      assert updated.status == :active
      # Now the consent gate opens.
      assert [guardian_user] = Orgs.list_active_guardian_users_for_user(ctx.managed.id)
      assert guardian_user.id == ctx.guardian.id
    end

    test "managed member sees transparency panel once active", ctx do
      g_ms = Orgs.get_membership!(ctx.guardian, ctx.org.slug)
      m_ms = Orgs.get_membership!(ctx.managed, ctx.org.slug)
      {:ok, gship} = Orgs.establish_guardianship(g_ms, m_ms)
      {:ok, _} = Orgs.accept_guardianship(gship)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.managed, ctx.managed_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#guardian-transparency-panel")
    end
  end
end
