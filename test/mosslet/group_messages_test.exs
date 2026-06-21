defmodule Mosslet.GroupMessagesTest do
  @moduledoc """
  Context tests for circle-chat @mentions (Task #279).

  These cover the shared, ZK-safe mention CORE used identically by Family (#271)
  and Business (#221) circles: token parsing, record creation (with self-mention
  exclusion), and the server-authoritative "does this message mention me?" lookup
  that drives the unread highlight even for non-public (browser-encrypted) circles
  where the @[id] token is sealed inside ciphertext the server cannot read.
  """
  use Mosslet.DataCase

  import Mosslet.GroupsFixtures

  alias Mosslet.GroupMessages
  alias Mosslet.Groups

  @valid_password "hello world hello world"

  setup do
    user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "mention_owner",
        password: @valid_password,
        email: "mention_owner@example.com"
      })

    key = get_session_key(user, @valid_password)

    {:ok, user} =
      Mosslet.Accounts.update_user_onboarding_profile(user, %{name: "Owner One"},
        change_name: true,
        key: key,
        user: user
      )

    reverse_user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "mention_member",
        email: "mention_member@example.com",
        password: @valid_password
      })

    group =
      group_fixture(%{name: "Mention Circle", user_id: user.id},
        user: user,
        key: key
      )

    owner_ug = Enum.find(Groups.list_user_groups(group), &(&1.user_id == user.id))

    # The mention CORE only needs valid FK ids (group + user_group), so we insert
    # the mentioned member's user_group directly rather than wiring the full
    # connection-gated add flow, which is out of scope for these context tests.
    member_ug =
      Mosslet.Repo.insert!(%Groups.UserGroup{
        role: :member,
        group_id: group.id,
        user_id: reverse_user.id,
        confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })

    {:ok, message} =
      GroupMessages.create_message(
        %{content: "ciphertext", group_id: group.id, sender_id: owner_ug.id},
        encrypted_content: "ciphertext"
      )

    %{group: group, owner_ug: owner_ug, member_ug: member_ug, message: message}
  end

  describe "parse_mentions/1" do
    test "extracts unique user_group_id tokens" do
      a = "11111111-1111-1111-1111-111111111111"
      b = "22222222-2222-2222-2222-222222222222"

      assert GroupMessages.parse_mentions("hi @[#{a}] and @[#{b}] and @[#{a}] again") == [a, b]
    end

    test "ignores plain text and malformed tokens" do
      assert GroupMessages.parse_mentions("just @someone, not a token") == []
      assert GroupMessages.parse_mentions("@[not-a-uuid]") == []
      assert GroupMessages.parse_mentions(nil) == []
    end
  end

  describe "create_mentions_for_message/2" do
    test "creates a mention record for a mentioned member", %{
      message: message,
      member_ug: member_ug
    } do
      assert {:ok, _} = GroupMessages.create_mentions_for_message(message, [member_ug.id])
      assert GroupMessages.message_mentions_user_group?(message.id, member_ug.id)
    end

    test "excludes self-mentions (sender mentioning themselves)", %{
      message: message,
      owner_ug: owner_ug
    } do
      assert {:ok, []} = GroupMessages.create_mentions_for_message(message, [owner_ug.id])
      refute GroupMessages.message_mentions_user_group?(message.id, owner_ug.id)
    end

    test "is idempotent on the (message, member) pair", %{
      message: message,
      member_ug: member_ug
    } do
      GroupMessages.create_mentions_for_message(message, [member_ug.id])
      GroupMessages.create_mentions_for_message(message, [member_ug.id])

      assert GroupMessages.get_unread_mention_count(member_ug.id, message.group_id) == 1
    end
  end

  describe "message_mentions_user_group?/2 (server-authoritative, ZK-safe)" do
    test "reflects only persisted records, never message content", %{
      message: message,
      member_ug: member_ug,
      owner_ug: owner_ug
    } do
      refute GroupMessages.message_mentions_user_group?(message.id, member_ug.id)
      GroupMessages.create_mentions_for_message(message, [member_ug.id])
      assert GroupMessages.message_mentions_user_group?(message.id, member_ug.id)
      refute GroupMessages.message_mentions_user_group?(message.id, owner_ug.id)
    end
  end

  describe "unread mention lifecycle" do
    test "unread set then single mark-read", %{
      group: group,
      message: message,
      member_ug: member_ug
    } do
      GroupMessages.create_mentions_for_message(message, [member_ug.id])

      unread = GroupMessages.get_unread_mention_message_ids(member_ug.id, group.id)
      assert MapSet.member?(unread, message.id)

      :ok = GroupMessages.mark_single_mention_as_read(message.id, member_ug.id)

      assert GroupMessages.get_unread_mention_message_ids(member_ug.id, group.id)
             |> MapSet.size() == 0
    end

    test "mark_mentions_as_read clears all for the group", %{
      group: group,
      message: message,
      member_ug: member_ug
    } do
      GroupMessages.create_mentions_for_message(message, [member_ug.id])
      :ok = GroupMessages.mark_mentions_as_read(member_ug.id, group.id)
      assert GroupMessages.get_unread_mention_count(member_ug.id, group.id) == 0
    end
  end

  describe "ChatSupport.mention_variant/1 (tailored UI mapping)" do
    test "maps current_page to the surface variant" do
      assert MossletWeb.GroupLive.ChatSupport.mention_variant(:family) == "family"
      assert MossletWeb.GroupLive.ChatSupport.mention_variant(:business) == "business"
      assert MossletWeb.GroupLive.ChatSupport.mention_variant(:circles) == "personal"
      assert MossletWeb.GroupLive.ChatSupport.mention_variant(nil) == "personal"
    end
  end

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end
end
