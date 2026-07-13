defmodule MossletWeb.RssFeedVisibilityTest do
  @moduledoc """
  Discoverability of the "Follow via RSS" affordance (task #385).

  The feed itself is always public-content-only. `rss_feed_visibility` only
  governs WHO sees the copy-link button on the author's public posts. This test
  covers `MossletWeb.Helpers.rss_feed_url_for_viewer/2`.
  """
  use Mosslet.DataCase

  alias Mosslet.Accounts
  alias MossletWeb.Helpers

  @password "hello world hello world"

  defp feed_author(visibility) do
    user =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "author#{System.unique_integer([:positive])}",
        email: "author#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    {:ok, user} = Accounts.update_rss_feed_enabled(user, true)
    {:ok, user} = Accounts.update_rss_feed_visibility(user, visibility)
    user
  end

  test "returns nil when the feed is disabled" do
    author = feed_author(:public)
    {:ok, author} = Accounts.update_rss_feed_enabled(author, false)

    assert Helpers.rss_feed_url_for_viewer(author, nil) == nil
  end

  test "public visibility shows the URL to anonymous viewers" do
    author = feed_author(:public)
    url = Helpers.rss_feed_url_for_viewer(author, nil)

    assert is_binary(url)
    assert url =~ "/feeds/#{author.rss_feed_token}.xml"
  end

  test "private visibility never shows the URL, even to the author" do
    author = feed_author(:private)

    assert Helpers.rss_feed_url_for_viewer(author, nil) == nil
    assert Helpers.rss_feed_url_for_viewer(author, author) == nil
  end

  test "connections visibility hides the URL from anonymous and non-connections" do
    author = feed_author(:connections)

    stranger =
      Mosslet.AccountsFixtures.user_fixture(%{
        username: "stranger#{System.unique_integer([:positive])}",
        email: "stranger#{System.unique_integer([:positive])}@example.com",
        password: @password
      })

    assert Helpers.rss_feed_url_for_viewer(author, nil) == nil
    assert Helpers.rss_feed_url_for_viewer(author, stranger) == nil
  end

  test "connections visibility shows the URL to the author themselves" do
    author = feed_author(:connections)

    url = Helpers.rss_feed_url_for_viewer(author, author)
    assert is_binary(url)
  end
end
