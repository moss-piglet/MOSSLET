defmodule Mosslet.NudgesTest do
  @moduledoc """
  Context tests for the content-free "thinking of you" nudge system (EPIC #377,
  task #399).

  Locks in the metadata-only behaviour: sending is gated on a confirmed
  connection + recipient opt-in + a rate limit; the persisted row carries only
  `from_user_id`, `to_user_id`, and timestamps (never a name, never content);
  delivery is a per-user PubSub signal; and seen-state is recipient-scoped.
  """
  use Mosslet.DataCase, async: true

  alias Mosslet.Nudges
  alias Mosslet.Nudges.Nudge

  import Mosslet.UserConnectionFixtures

  @valid_password "hello world hello world"

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end

  setup do
    user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "nudge_sender",
        email: "nudge_sender@example.com",
        password: @valid_password
      })

    key = get_session_key(user, @valid_password)

    {:ok, user} =
      Mosslet.Accounts.update_user_onboarding_profile(user, %{name: "Sender One"},
        change_name: true,
        key: key,
        user: user
      )

    reverse_user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "nudge_recipient",
        email: "nudge_recipient@example.com",
        password: @valid_password
      })

    r_key = get_session_key(reverse_user, @valid_password)

    {:ok, reverse_user} =
      Mosslet.Accounts.update_user_visibility(reverse_user, %{visibility: :connections},
        key: r_key
      )

    {:ok, reverse_user} =
      Mosslet.Accounts.update_user_onboarding_profile(reverse_user, %{name: "Recipient Two"},
        change_name: true,
        key: r_key,
        user: reverse_user
      )

    user_connection_fixture(
      %{
        "color" => "rose",
        "temp_label" => "friend",
        "connection_id" => user.connection.id,
        "reverse_user_id" => user.id,
        "selector" => "username",
        "username" => "nudge_recipient"
      },
      user: user,
      reverse_user: reverse_user,
      key: key,
      r_key: r_key,
      confirm?: true
    )

    %{user: user, reverse_user: reverse_user}
  end

  describe "send_nudge/2" do
    test "sends a metadata-only nudge to a confirmed connection + broadcasts", %{
      user: user,
      reverse_user: reverse_user
    } do
      :ok = Nudges.subscribe(reverse_user.id)

      assert {:ok, %Nudge{} = nudge} = Nudges.send_nudge(user, reverse_user.id)

      # Pure metadata — no name, no content anywhere on the row.
      assert nudge.from_user_id == user.id
      assert nudge.to_user_id == reverse_user.id
      assert is_nil(nudge.seen_at)
      refute Map.has_key?(nudge, :body)
      assert Repo.get(Nudge, nudge.id)

      # Realtime delivery to the recipient's per-user topic.
      assert_receive {:nudge_received, %Nudge{} = received}
      assert received.id == nudge.id
    end

    test "refuses to nudge yourself", %{user: user} do
      assert {:error, :self} = Nudges.send_nudge(user, user.id)
    end

    test "refuses to nudge a non-connection", %{user: user} do
      stranger =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "a_stranger",
          email: "a_stranger@example.com",
          password: @valid_password
        })

      assert {:error, :not_connected} = Nudges.send_nudge(user, stranger.id)
      refute Nudges.recently_nudged?(user.id, stranger.id)
    end

    test "respects recipient opt-out", %{user: user, reverse_user: reverse_user} do
      {:ok, _} = Mosslet.Accounts.update_nudges_enabled(reverse_user, false)
      assert {:error, :opted_out} = Nudges.send_nudge(user, reverse_user.id)
    end

    test "rate-limits repeat nudges to the same connection", %{
      user: user,
      reverse_user: reverse_user
    } do
      assert {:ok, _} = Nudges.send_nudge(user, reverse_user.id)
      assert Nudges.recently_nudged?(user.id, reverse_user.id)
      assert {:error, :rate_limited} = Nudges.send_nudge(user, reverse_user.id)
    end
  end

  describe "list_unseen_nudges/2 + mark_seen/2" do
    test "lists unseen nudges and marks them seen (recipient-scoped)", %{
      user: user,
      reverse_user: reverse_user
    } do
      {:ok, nudge} = Nudges.send_nudge(user, reverse_user.id)

      assert [listed] = Nudges.list_unseen_nudges(reverse_user.id)
      assert listed.id == nudge.id

      # The sender sees none of their own outbound nudges in their inbox.
      assert Nudges.list_unseen_nudges(user.id) == []

      # A non-recipient can't ack someone else's nudge.
      assert {:error, :not_found} = Nudges.mark_seen(nudge.id, user)
      assert [_] = Nudges.list_unseen_nudges(reverse_user.id)

      # The recipient can.
      assert {:ok, seen} = Nudges.mark_seen(nudge.id, reverse_user)
      refute is_nil(seen.seen_at)
      assert Nudges.list_unseen_nudges(reverse_user.id) == []
    end

    test "mark_all_seen/1 clears the recipient's inbox", %{
      user: user,
      reverse_user: reverse_user
    } do
      {:ok, _} = Nudges.send_nudge(user, reverse_user.id)

      assert Nudges.mark_all_seen(reverse_user) == 1
      assert Nudges.list_unseen_nudges(reverse_user.id) == []
    end
  end

  describe "get_nudge/1" do
    test "returns nil for nil, unknown, and malformed ids" do
      assert Nudges.get_nudge(nil) == nil
      assert Nudges.get_nudge(Ecto.UUID.generate()) == nil
      assert Nudges.get_nudge("not-a-uuid") == nil
    end
  end
end
