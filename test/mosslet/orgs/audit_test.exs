defmodule Mosslet.Orgs.AuditTest do
  @moduledoc """
  Tests for the zero-knowledge admin audit log (Task #212, §12 of
  docs/BUSINESS_CIRCLES_DESIGN.md): `Mosslet.Orgs.Audit`.

  Option B — metadata-only, server-authoritative, APPEND-ONLY. These tests pin
  the ZK + tamper-resistance invariants: only opaque ids + a non-sensitive
  category are stored, the actor is server-authoritative, the recipient/view
  cohort is admins only, there is no update/delete API, and deleting the org
  cascade-wipes the whole log (no orphans).
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs
  alias Mosslet.Orgs.Audit
  alias Mosslet.Orgs.AuditEvent
  alias Mosslet.Orgs.Membership

  @password valid_user_password()

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Repo.transaction_on_primary(fn ->
        Membership.insert_changeset(org, user, role) |> Repo.insert()
      end)

    membership
  end

  defp setup_org(type \\ "business") do
    owner = user_fixture()
    admin = user_fixture()
    member = user_fixture()
    org = org_fixture(owner, %{"type" => type})
    add_member(org, admin, :admin)
    add_member(org, member, :member)
    %{owner: owner, admin: admin, member: member, org: org}
  end

  describe "record_audit_event/4" do
    test "records a business-org event with the server-authoritative actor + target" do
      %{owner: owner, org: org} = setup_org()
      target_id = Ecto.UUID.generate()

      assert {:ok, %AuditEvent{} = event} =
               Audit.record_audit_event(org, owner, "circle_created",
                 target_id: target_id,
                 target_type: "group"
               )

      assert event.org_id == org.id
      assert event.actor_id == owner.id
      assert event.action == "circle_created"
      assert event.target_id == target_id
      assert event.target_type == "group"
      assert event.inserted_at
    end

    test "records the display-name change action (#264, self and admin renames)" do
      %{admin: admin, member: member, org: org} = setup_org()

      # Self-rename: actor == target.
      assert {:ok, %AuditEvent{} = self_event} =
               Audit.record_audit_event(org, member, "display_name_changed",
                 target_id: member.id,
                 target_type: "user"
               )

      assert self_event.action == "display_name_changed"
      assert self_event.actor_id == member.id
      assert self_event.target_id == member.id
      assert self_event.target_type == "user"

      # Admin renames someone else: actor != target.
      assert {:ok, %AuditEvent{} = other_event} =
               Audit.record_audit_event(org, admin, "display_name_changed",
                 target_id: member.id,
                 target_type: "user"
               )

      assert other_event.actor_id == admin.id
      assert other_event.target_id == member.id

      actions = org |> Audit.list_audit_events() |> Enum.map(& &1.action)
      assert Enum.count(actions, &(&1 == "display_name_changed")) == 2
    end

    test "rejects an action that is not in the whitelist" do
      %{owner: owner, org: org} = setup_org()

      assert {:error, %Ecto.Changeset{} = cs} =
               Audit.record_audit_event(org, owner, "exfiltrate_everything")

      assert "is invalid" in errors_on(cs).action
      assert Audit.list_audit_events(org) == []
    end

    test "rejects an unknown target_type" do
      %{owner: owner, org: org} = setup_org()

      assert {:error, %Ecto.Changeset{}} =
               Audit.record_audit_event(org, owner, "circle_created",
                 target_id: Ecto.UUID.generate(),
                 target_type: "nonsense"
               )
    end

    test "is a no-op for non-business orgs (no audit log for family)" do
      %{owner: owner, org: org} = setup_org("family")

      assert {:ok, :skipped} = Audit.record_audit_event(org, owner, "member_added")
      assert Audit.list_audit_events(org) == []
    end

    test "stores NO readable content — only opaque ids + category (ZK invariant)" do
      %{owner: owner, member: member, org: org} = setup_org()

      {:ok, event} =
        Audit.record_audit_event(org, owner, "role_changed",
          target_id: member.id,
          target_type: "user"
        )

      # The persisted columns are exactly: ids + a non-sensitive category +
      # timestamp + an OPAQUE org_key-encrypted label (browser-supplied
      # ciphertext the server can never read — invariant I6; here nil since no
      # label was supplied). There is no readable name/content field.
      stored = Repo.get!(AuditEvent, event.id)

      assert Map.keys(Map.from_struct(stored)) |> Enum.sort() ==
               ~w(__meta__ action actor actor_id encrypted_label id inserted_at org org_id target_id target_type)a

      assert is_nil(stored.encrypted_label)
    end
  end

  describe "list_audit_events/2" do
    test "is org-scoped and most-recent-first" do
      %{owner: owner, org: org} = setup_org()
      other = setup_org()

      {:ok, _} = Audit.record_audit_event(org, owner, "member_added", target_id: owner.id)
      {:ok, _} = Audit.record_audit_event(org, owner, "circle_created")
      {:ok, _} = Audit.record_audit_event(other.org, other.owner, "circle_created")

      events = Audit.list_audit_events(org)

      assert length(events) == 2
      # Only this org's events.
      assert Enum.all?(events, &(&1.org_id == org.id))
      # Sorted descending by inserted_at (most recent first).
      assert events == Enum.sort_by(events, & &1.inserted_at, {:desc, NaiveDateTime})
    end

    test "respects the :limit option" do
      %{owner: owner, org: org} = setup_org()

      for _ <- 1..5, do: Audit.record_audit_event(org, owner, "file_shared")

      assert length(Audit.list_audit_events(org, limit: 3)) == 3
    end
  end

  describe "authority" do
    test "can_view_audit_log? is true for the owner and admins, false for members" do
      %{owner: owner, admin: admin, member: member, org: org} = setup_org()
      stranger = user_fixture()

      assert Audit.can_view_audit_log?(org, owner.id)
      assert Audit.can_view_audit_log?(org, admin.id)
      refute Audit.can_view_audit_log?(org, member.id)
      refute Audit.can_view_audit_log?(org, stranger.id)
    end

    test "list_org_admins returns the owner + admin-role members only" do
      %{owner: owner, admin: admin, member: member, org: org} = setup_org()

      admin_ids = org |> Audit.list_org_admins() |> Enum.map(& &1.user_id) |> Enum.sort()

      assert owner.id in admin_ids
      assert admin.id in admin_ids
      refute member.id in admin_ids
    end
  end

  describe "append-only / tamper-resistance" do
    test "the context exposes no update or delete API" do
      exports = Audit.__info__(:functions)

      refute Enum.any?(exports, fn {name, _arity} ->
               name in [:update_audit_event, :delete_audit_event, :delete_audit_events]
             end)
    end

    test "the schema is immutable (inserted_at only, no updated_at)" do
      refute :updated_at in AuditEvent.__schema__(:fields)
      assert :inserted_at in AuditEvent.__schema__(:fields)
    end
  end

  describe "org deletion cascade (no orphaned logs)" do
    test "deleting the org wipes its entire audit log" do
      %{owner: owner, org: org} = setup_org()

      {:ok, _} = Audit.record_audit_event(org, owner, "member_added", target_id: owner.id)
      {:ok, _} = Audit.record_audit_event(org, owner, "circle_created")
      assert length(Audit.list_audit_events(org)) == 2

      assert {:ok, _summary} = Orgs.delete_org_safely(org, owner, @password)

      # Cascade (on_delete: :delete_all) leaves zero orphaned audit rows.
      refute Repo.exists?(from e in AuditEvent, where: e.org_id == ^org.id)
    end
  end
end
