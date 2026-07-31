defmodule Mosslet.Workers.MosskeysPublishWorkerTest do
  use Mosslet.DataCase, async: false

  import Plug.Conn
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Workers.MosskeysPublishWorker

  setup do
    previous = Application.get_env(:mosslet, :mosskeys_req_options, [])

    on_exit(fn ->
      Application.put_env(:mosslet, :mosskeys_req_options, previous)
      System.delete_env("MOSSKEYS_NAMESPACE_TOKEN")
    end)

    :ok
  end

  defp entry_fixture(user) do
    entry =
      Jason.encode!(%{
        "v" => 1,
        "seq" => 0,
        "ts" => 1_753_900_000_000,
        "enc_x25519" => "x-pub",
        "enc_pq" => "pq-pub",
        "sign_pub" => "sign-pub",
        "prev_hash" => "",
        "entry_hash" => "hash",
        "sig" => "sig"
      })

    {:ok, appended} = Accounts.append_key_history_entry(user.id, 0, entry, "sign-pub")
    appended
  end

  defp perform(worker, args) do
    Oban.Testing.perform_job(worker, args, repo: Mosslet.Repo)
  end

  test "publishes the entry and records the anchored index" do
    user = user_fixture()
    entry = entry_fixture(user)

    Application.put_env(:mosslet, :mosskeys_req_options,
      plug: fn conn ->
        {:ok, _body, conn} = read_body(conn)

        send_resp(
          put_resp_content_type(conn, "application/json"),
          200,
          Jason.encode!(%{index: 7, size: 8, root: "cm9vdA=="})
        )
      end
    )

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

    assert :ok = perform(MosskeysPublishWorker, %{"user_id" => user.id, "seq" => 0})

    anchored = Accounts.get_key_history_entry(user.id, 0)
    assert anchored.mosskeys_index == 7
  end

  test "discards when the entry no longer exists" do
    user = user_fixture()

    assert {:discard, :not_found} =
             perform(MosskeysPublishWorker, %{"user_id" => user.id, "seq" => 99})
  end

  test "discards quietly when the namespace token is not configured" do
    user = user_fixture()
    _entry = entry_fixture(user)
    System.delete_env("MOSSKEYS_NAMESPACE_TOKEN")

    assert {:discard, :missing_token} =
             perform(MosskeysPublishWorker, %{"user_id" => user.id, "seq" => 0})

    # Nothing anchored — the backfill sweep will pick it up once configured.
    assert Accounts.get_key_history_entry(user.id, 0).mosskeys_index == nil
  end

  test "returns an error tuple for transient upstream failures (retryable)" do
    user = user_fixture()
    _entry = entry_fixture(user)

    Application.put_env(:mosslet, :mosskeys_req_options,
      plug: fn conn ->
        send_resp(
          put_resp_content_type(conn, "application/json"),
          500,
          Jason.encode!(%{error: "boom"})
        )
      end
    )

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

    assert {:error, 500} = perform(MosskeysPublishWorker, %{"user_id" => user.id, "seq" => 0})
  end
end
