defmodule Mosslet.VoiceNotesTest do
  use Mosslet.DataCase, async: false

  import Mosslet.AccountsFixtures
  import Mosslet.UserConnectionFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Conversations
  alias Mosslet.Groups
  alias Mosslet.VoiceNotes

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp subscribe_user(user) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  defp onboarded_user(name_seed) do
    username = "#{name_seed}#{System.unique_integer([:positive])}"
    email = "#{username}@example.com"
    user = user_fixture(%{email: email, username: username, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    subscribe_user(user)
    key = get_key(user)

    {:ok, user} = Accounts.update_user_visibility(user, %{visibility: :connections}, key: key)

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: "Name #{name_seed}"},
        change_name: true,
        key: key,
        user: user
      )

    {user, key, username}
  end

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Mosslet.Orgs.Membership.insert_changeset(org, user, role) |> Mosslet.Repo.insert()
      end)

    membership
  end

  defp zk_attrs do
    %{
      encrypted_name: "encrypted-name-blob",
      encrypted_description: "encrypted-desc-blob",
      name_blind_index: "circle name #{System.unique_integer([:positive])}",
      sealed_creator_key: "sealed-creator-key-blob",
      encrypted_user_name: "encrypted-owner-name",
      encrypted_owner_moniker: "encrypted-owner-moniker",
      encrypted_owner_avatar_img: "encrypted-owner-avatar",
      require_password?: false,
      password: ""
    }
  end

  defp sealed_for(user) do
    %{
      "user_id" => user.id,
      "sealed_key" => "sealed-#{user.id}",
      "encrypted_name" => "name-#{user.id}",
      "encrypted_moniker" => "moniker-#{user.id}",
      "encrypted_avatar_img" => "avatar-#{user.id}"
    }
  end

  defp confirm_membership(group, user) do
    ug = Enum.find(Groups.get_group!(group.id).user_groups, &(&1.user_id == user.id))

    {:ok, {:ok, _}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        ug |> Mosslet.Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
      end)

    :ok
  end

  defp note_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "storage_path" => "uploads/files/#{Ecto.UUID.generate()}.bin",
        "checksum" => "sha256-checksum-blob",
        "media_type" => "audio",
        "mime_hint" => "audio/webm;codecs=opus",
        "duration_ms" => 4200,
        "size_bytes" => 8192
      },
      overrides
    )
  end

  defp sealed_key(user), do: %{"user_id" => user.id, "sealed_key" => "sealed-#{user.id}"}

  setup do
    {admin, admin_key, _au} = onboarded_user("vnadmin")
    {:ok, org} = Mosslet.Orgs.create_org(admin, %{"name" => "Voicecorp", "type" => "business"})

    {member, member_key, member_username} = onboarded_user("vnmember")
    add_member(org, member, :member)

    {outsider, _ok, _ou} = onboarded_user("vnoutsider")

    {:ok, group} =
      Groups.create_business_circle_zk(org, admin, zk_attrs(), [member], [sealed_for(member)])

    confirm_membership(group, member)

    %{
      org: org,
      group: group,
      admin: admin,
      admin_key: admin_key,
      member: member,
      member_key: member_key,
      member_username: member_username,
      outsider: outsider
    }
  end

  describe "create_voice_note_zk/3 (group cohort)" do
    test "creates a voice note for a member and stamps FKs", ctx do
      assert {:ok, voice_note} =
               VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())

      assert voice_note.group_id == ctx.group.id
      assert is_nil(voice_note.conversation_id)
      assert voice_note.sender_id == ctx.admin.id
      assert voice_note.media_type == "audio"
      assert voice_note.duration_ms == 4200
    end

    test "rejects a sender who is not a circle member", ctx do
      assert {:error, :not_a_member} =
               VoiceNotes.create_voice_note_zk(ctx.group, ctx.outsider, note_attrs())
    end

    test "rejects a note over the byte cap", ctx do
      oversized = note_attrs(%{"size_bytes" => VoiceNotes.max_size_bytes() + 1})

      assert {:error, :too_large} =
               VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, oversized)
    end

    test "rejects a note over the 5-minute duration cap", ctx do
      too_long = note_attrs(%{"duration_ms" => VoiceNotes.max_duration_ms() + 1})
      assert {:error, :too_long} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, too_long)
    end
  end

  describe "finalize_voice_note_zk/2 (I1 eligibility)" do
    test "seals only for confirmed members, dropping an outsider", ctx do
      {:ok, voice_note} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())

      sealed = [
        sealed_key(ctx.admin),
        sealed_key(ctx.member),
        sealed_key(ctx.outsider)
      ]

      assert {:ok, 2} = VoiceNotes.finalize_voice_note_zk(voice_note, sealed)

      reader_ids = voice_note |> VoiceNotes.list_readers() |> Enum.map(& &1.id)
      assert ctx.admin.id in reader_ids
      assert ctx.member.id in reader_ids
      refute ctx.outsider.id in reader_ids
    end

    test "drops entries without a sealed_key", ctx do
      {:ok, voice_note} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())

      sealed = [
        sealed_key(ctx.admin),
        %{"user_id" => ctx.member.id, "sealed_key" => nil}
      ]

      assert {:ok, 1} = VoiceNotes.finalize_voice_note_zk(voice_note, sealed)
      assert [%{id: id}] = VoiceNotes.list_readers(voice_note)
      assert id == ctx.admin.id
    end
  end

  describe "get_user_voice_note/2 (read auth)" do
    test "returns the requester's sealed key row only when they're a reader", ctx do
      {:ok, voice_note} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())
      {:ok, _} = VoiceNotes.finalize_voice_note_zk(voice_note, [sealed_key(ctx.admin)])

      uvn = VoiceNotes.get_user_voice_note(voice_note, ctx.admin)
      assert uvn.key == "sealed-#{ctx.admin.id}"

      assert is_nil(VoiceNotes.get_user_voice_note(voice_note, ctx.outsider))
    end
  end

  describe "delete_voice_note/2 (I5)" do
    test "sender can delete; removes record + all sealed keys", ctx do
      {:ok, voice_note} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())

      {:ok, _} =
        VoiceNotes.finalize_voice_note_zk(voice_note, [
          sealed_key(ctx.admin),
          sealed_key(ctx.member)
        ])

      assert {:ok, :deleted} = VoiceNotes.delete_voice_note(voice_note, ctx.admin)
      assert is_nil(VoiceNotes.get_voice_note(voice_note.id))
      assert VoiceNotes.list_readers(voice_note) == []
    end

    test "a circle admin/owner can delete another member's note", ctx do
      {:ok, voice_note} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.member, note_attrs())
      {:ok, _} = VoiceNotes.finalize_voice_note_zk(voice_note, [sealed_key(ctx.member)])

      assert {:ok, :deleted} = VoiceNotes.delete_voice_note(voice_note, ctx.admin)
      assert is_nil(VoiceNotes.get_voice_note(voice_note.id))
    end

    test "a non-sender non-admin member cannot delete", ctx do
      {:ok, voice_note} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())
      {:ok, _} = VoiceNotes.finalize_voice_note_zk(voice_note, [sealed_key(ctx.member)])

      assert {:error, :unauthorized} = VoiceNotes.delete_voice_note(voice_note, ctx.member)
      refute is_nil(VoiceNotes.get_voice_note(voice_note.id))
    end
  end

  describe "delete_all_for_group/1 (teardown)" do
    test "removes every voice note + reader row for the circle", ctx do
      {:ok, note1} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())
      {:ok, _} = VoiceNotes.finalize_voice_note_zk(note1, [sealed_key(ctx.admin)])
      {:ok, note2} = VoiceNotes.create_voice_note_zk(ctx.group, ctx.admin, note_attrs())
      {:ok, _} = VoiceNotes.finalize_voice_note_zk(note2, [sealed_key(ctx.admin)])

      assert {:ok, 2} = VoiceNotes.delete_all_for_group(ctx.group)
      assert is_nil(VoiceNotes.get_voice_note(note1.id))
      assert is_nil(VoiceNotes.get_voice_note(note2.id))
    end
  end

  describe "conversation cohort" do
    setup ctx do
      uconn =
        user_connection_fixture(
          %{
            "color" => "emerald",
            "temp_label" => "friend",
            "connection_id" => ctx.member.connection.id,
            "reverse_user_id" => ctx.member.id,
            "selector" => "username",
            "username" => ctx.member_username
          },
          user: ctx.admin,
          reverse_user: ctx.member,
          key: ctx.admin_key,
          r_key: ctx.member_key,
          confirm?: true
        )

      {:ok, conversation} =
        Conversations.get_or_create_conversation(uconn.id, [
          %{user_id: ctx.admin.id, key: "sealed-conv-admin"},
          %{user_id: ctx.member.id, key: "sealed-conv-member"}
        ])

      Map.put(ctx, :conversation, conversation)
    end

    test "member can create; recipients resolve to both participants (I1)", ctx do
      assert {:ok, voice_note} =
               VoiceNotes.create_voice_note_zk(ctx.conversation, ctx.admin, note_attrs())

      assert voice_note.conversation_id == ctx.conversation.id
      assert is_nil(voice_note.group_id)

      recipient_ids =
        ctx.conversation |> VoiceNotes.recipients_for_conversation() |> Enum.map(& &1.user_id)

      assert Enum.sort(recipient_ids) == Enum.sort([ctx.admin.id, ctx.member.id])
    end

    test "an outsider cannot create a note in the conversation", ctx do
      assert {:error, :not_a_member} =
               VoiceNotes.create_voice_note_zk(ctx.conversation, ctx.outsider, note_attrs())
    end

    test "finalize drops a non-participant (I1)", ctx do
      {:ok, voice_note} =
        VoiceNotes.create_voice_note_zk(ctx.conversation, ctx.admin, note_attrs())

      sealed = [sealed_key(ctx.admin), sealed_key(ctx.member), sealed_key(ctx.outsider)]
      assert {:ok, 2} = VoiceNotes.finalize_voice_note_zk(voice_note, sealed)

      reader_ids = voice_note |> VoiceNotes.list_readers() |> Enum.map(& &1.id)
      refute ctx.outsider.id in reader_ids
    end
  end

  describe "exactly-one-cohort invariant" do
    test "changeset rejects a note with neither cohort", ctx do
      changeset =
        Mosslet.VoiceNotes.VoiceNote.insert_changeset(
          %Mosslet.Conversations.Conversation{id: nil},
          ctx.admin,
          note_attrs()
        )

      refute changeset.valid?
    end
  end
end
