defmodule Mosslet.RitualsTest do
  @moduledoc """
  Context tests for the shared ritual prompt system (EPIC #377, tasks #378/#384).

  Locks in the non-secret metadata behaviour: selecting/broadcasting a prompt,
  resolving the active one, the per-process prompt-text cache used by the
  timeline/profile/post cards (N+1 guard), and the metadata-only "answered?"
  check. No answer is ever read here — that stays on the zero-knowledge path.
  """
  use Mosslet.DataCase, async: true

  alias Mosslet.Rituals
  alias Mosslet.Rituals.PromptBroadcast

  import Mosslet.TimelineFixtures

  @valid_password "hello world hello world"

  defp broadcast_fixture(attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      Enum.into(attrs, %{
        prompt: "What are you looking forward to?",
        theme: "looking forward",
        broadcast_at: now,
        expires_at: DateTime.add(now, 4, :day)
      })

    {:ok, broadcast} =
      %PromptBroadcast{}
      |> PromptBroadcast.changeset(attrs)
      |> Repo.insert()

    broadcast
  end

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end

  describe "active_prompt/1" do
    test "returns the most recent broadcast whose window is still open" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      _older =
        broadcast_fixture(%{
          prompt: "Older prompt",
          broadcast_at: DateTime.add(now, -2, :day),
          expires_at: DateTime.add(now, 2, :day)
        })

      newer =
        broadcast_fixture(%{
          prompt: "Newer prompt",
          broadcast_at: DateTime.add(now, -1, :hour),
          expires_at: DateTime.add(now, 3, :day)
        })

      assert Rituals.active_prompt(now).id == newer.id
    end

    test "returns nil when every broadcast has expired" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      broadcast_fixture(%{
        broadcast_at: DateTime.add(now, -10, :day),
        expires_at: DateTime.add(now, -1, :day)
      })

      assert Rituals.active_prompt(now) == nil
    end

    test "ignores broadcasts scheduled in the future" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      broadcast_fixture(%{
        prompt: "Not yet live",
        broadcast_at: DateTime.add(now, 1, :day),
        expires_at: DateTime.add(now, 5, :day)
      })

      assert Rituals.active_prompt(now) == nil
    end
  end

  describe "broadcast_next_prompt/1" do
    test "records a broadcast and notifies subscribers over PubSub" do
      :ok = Rituals.subscribe()

      assert {:ok, %PromptBroadcast{} = broadcast} = Rituals.broadcast_next_prompt()

      # Persisted with a real prompt string + broadcast time.
      assert is_binary(broadcast.prompt) and broadcast.prompt != ""
      assert broadcast.broadcast_at != nil
      assert Repo.get(PromptBroadcast, broadcast.id)

      # Calm delivery: a single batched PubSub signal, not a per-user ping.
      assert_receive {:ritual_prompt, %PromptBroadcast{} = received}
      assert received.id == broadcast.id
    end

    test "the freshly broadcast prompt becomes the active one" do
      {:ok, broadcast} = Rituals.broadcast_next_prompt()
      assert Rituals.active_prompt().id == broadcast.id
    end
  end

  describe "get_prompt_broadcast/1" do
    test "returns the broadcast for a known id" do
      broadcast = broadcast_fixture()
      assert Rituals.get_prompt_broadcast(broadcast.id).id == broadcast.id
    end

    test "returns nil for nil, unknown, and malformed ids" do
      assert Rituals.get_prompt_broadcast(nil) == nil
      assert Rituals.get_prompt_broadcast(Ecto.UUID.generate()) == nil
      assert Rituals.get_prompt_broadcast("not-a-uuid") == nil
    end
  end

  describe "cached_prompt_text/1" do
    test "resolves the non-secret prompt text for a known id" do
      broadcast = broadcast_fixture(%{prompt: "A small plan you're excited about?"})
      assert Rituals.cached_prompt_text(broadcast.id) == "A small plan you're excited about?"
    end

    test "returns nil for nil and unknown ids" do
      assert Rituals.cached_prompt_text(nil) == nil
      assert Rituals.cached_prompt_text(Ecto.UUID.generate()) == nil
    end

    test "memoizes per-process so repeated card renders never re-query (N+1 guard)" do
      broadcast = broadcast_fixture(%{prompt: "Cached prompt text"})

      # Prime the per-process cache.
      assert Rituals.cached_prompt_text(broadcast.id) == "Cached prompt text"

      # Delete the underlying row: a fresh DB read would now return nil, but the
      # memoized value proves the timeline render reused the cached text instead
      # of issuing another query for the same prompt id.
      Repo.delete!(broadcast)

      assert Rituals.cached_prompt_text(broadcast.id) == "Cached prompt text"
    end
  end

  describe "answered?/2" do
    setup do
      user =
        Mosslet.AccountsFixtures.user_fixture(%{
          username: "ritual_answerer",
          email: "ritual_answerer@example.com",
          password: @valid_password
        })

      key = get_session_key(user, @valid_password)
      %{user: user, key: key}
    end

    test "is true once the user has a post stamped with the broadcast id", %{
      user: user,
      key: key
    } do
      broadcast = broadcast_fixture()
      refute Rituals.answered?(user.id, broadcast.id)

      # Public post: metadata-only check, and avoids the "make connections first"
      # guard on connections-scoped posts (irrelevant to answered?/2).
      post_fixture(
        %{ritual_prompt_id: broadcast.id, user_id: user.id, visibility: "public"},
        user: user,
        key: key
      )

      assert Rituals.answered?(user.id, broadcast.id)
    end

    test "is false for a different prompt, a different user, or non-binary args", %{
      user: user,
      key: key
    } do
      broadcast = broadcast_fixture()
      other_broadcast = broadcast_fixture(%{prompt: "A different question?"})

      post_fixture(
        %{ritual_prompt_id: broadcast.id, user_id: user.id, visibility: "public"},
        user: user,
        key: key
      )

      # Different prompt → not answered.
      refute Rituals.answered?(user.id, other_broadcast.id)

      # Different user → not answered.
      refute Rituals.answered?(Ecto.UUID.generate(), broadcast.id)

      # Defensive clause for missing ids.
      refute Rituals.answered?(nil, broadcast.id)
      refute Rituals.answered?(user.id, nil)
    end
  end
end
