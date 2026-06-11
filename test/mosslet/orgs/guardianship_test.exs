defmodule Mosslet.Orgs.GuardianshipTest do
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs

  describe "guardianship lifecycle + consent gate" do
    setup do
      admin = user_fixture()
      guardian_user = user_fixture()
      managed_user = user_fixture()

      org = org_fixture(admin, %{"type" => "family"})

      # Build guardian + managed memberships directly (admin membership created by org_fixture).
      {:ok, {:ok, guardian_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, guardian_user, :guardian)
          |> Mosslet.Repo.insert()
        end)

      {:ok, {:ok, managed_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, managed_user, :managed_member)
          |> Mosslet.Repo.insert()
        end)

      %{
        org: org,
        guardian_user: guardian_user,
        managed_user: managed_user,
        guardian_ms: guardian_ms,
        managed_ms: managed_ms
      }
    end

    test "of-age member starts :pending and is NOT co-sealed until accepted", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      assert g.status == :pending
      assert g.requires_consent == true

      # Consent gate: pending => no guardians returned for the write path
      assert Orgs.list_active_guardian_users_for_user(ctx.managed_user.id) == []

      {:ok, g} = Orgs.accept_guardianship(g)
      assert g.status == :active
      assert g.consented_at

      guardians = Orgs.list_active_guardian_users_for_user(ctx.managed_user.id)
      assert [guardian] = guardians
      assert guardian.id == ctx.guardian_user.id
      assert guardian.key_pair["public"]
    end

    test "declined guardianship is never co-sealed", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, g} = Orgs.decline_guardianship(g)
      assert g.status == :declined
      assert Orgs.list_active_guardian_users_for_user(ctx.managed_user.id) == []
    end

    test "minor account (requires_consent: false) may start :active", ctx do
      {:ok, g} =
        Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms, requires_consent: false)

      assert g.status == :active
      assert g.requires_consent == false
      assert [_guardian] = Orgs.list_active_guardian_users_for_user(ctx.managed_user.id)
    end

    test "pause stops future co-seals; resume re-enables", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, g} = Orgs.accept_guardianship(g)
      assert [_] = Orgs.list_active_guardian_users_for_user(ctx.managed_user.id)

      {:ok, g} = Orgs.pause_guardianship(g)
      assert g.status == :paused
      assert g.paused_at
      assert Orgs.list_active_guardian_users_for_user(ctx.managed_user.id) == []

      {:ok, g} = Orgs.resume_guardianship(g)
      assert g.status == :active
      assert [_] = Orgs.list_active_guardian_users_for_user(ctx.managed_user.id)
    end

    test "revoke stops future co-seals", ctx do
      {:ok, g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
      {:ok, g} = Orgs.accept_guardianship(g)
      assert [_] = Orgs.list_active_guardian_users_for_user(ctx.managed_user.id)

      {:ok, _} = Orgs.revoke_guardianship(g)
      assert Orgs.list_active_guardian_users_for_user(ctx.managed_user.id) == []
    end

    test "establish rejects cross-org or wrong-role memberships", ctx do
      other_admin = user_fixture()
      other_org = org_fixture(other_admin, %{"type" => "family"})

      {:ok, {:ok, other_managed_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(other_org, user_fixture(), :managed_member)
          |> Mosslet.Repo.insert()
        end)

      assert {:error, :different_orgs} =
               Orgs.establish_guardianship(ctx.guardian_ms, other_managed_ms)
    end

    test "duplicate guardianship is rejected", ctx do
      {:ok, _g} = Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)

      assert {:error, :already_exists} =
               Orgs.establish_guardianship(ctx.guardian_ms, ctx.managed_ms)
    end
  end
end
