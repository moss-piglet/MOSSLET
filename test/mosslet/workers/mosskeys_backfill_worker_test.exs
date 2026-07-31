defmodule Mosslet.Workers.MosskeysBackfillWorkerTest do
  use Mosslet.DataCase, async: false

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Repo
  alias Mosslet.Workers.MosskeysBackfillWorker

  setup do
    on_exit(fn -> System.delete_env("MOSSKEYS_NAMESPACE_TOKEN") end)
    :ok
  end

  defp entry_fixture(user, seq) do
    entry = Jason.encode!(%{"seq" => seq, "enc_x25519" => "x", "enc_pq" => "pq"})
    {:ok, appended} = Accounts.append_key_history_entry(user.id, seq, entry, "sign-pub")
    appended
  end

  test "enqueues a publish job for every unanchored entry, skipping anchored ones" do
    user = user_fixture()
    _unanchored = entry_fixture(user, 0)
    anchored = entry_fixture(user, 1)
    {:ok, _} = Accounts.mark_key_history_entry_anchored(anchored, 12)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

    assert :ok = Oban.Testing.perform_job(MosskeysBackfillWorker, %{}, repo: Repo)

    jobs =
      Repo.all(
        from j in Oban.Job,
          where: j.worker == "Mosslet.Workers.MosskeysPublishWorker",
          select: {j.args, j.state}
      )

    assert length(jobs) == 1
    assert {%{"user_id" => user_id, "seq" => 0}, _state} = hd(jobs)
    assert user_id == user.id
  end

  test "enqueues nothing when everything is anchored" do
    user = user_fixture()
    anchored = entry_fixture(user, 0)
    {:ok, _} = Accounts.mark_key_history_entry_anchored(anchored, 3)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

    assert :ok = Oban.Testing.perform_job(MosskeysBackfillWorker, %{}, repo: Repo)

    assert Repo.aggregate(
             from(j in Oban.Job, where: j.worker == "Mosslet.Workers.MosskeysPublishWorker"),
             :count
           ) == 0
  end

  test "skips quietly without a configured token" do
    user = user_fixture()
    _unanchored = entry_fixture(user, 0)
    System.delete_env("MOSSKEYS_NAMESPACE_TOKEN")

    assert :ok = Oban.Testing.perform_job(MosskeysBackfillWorker, %{}, repo: Repo)

    assert Repo.aggregate(
             from(j in Oban.Job, where: j.worker == "Mosslet.Workers.MosskeysPublishWorker"),
             :count
           ) == 0
  end
end
