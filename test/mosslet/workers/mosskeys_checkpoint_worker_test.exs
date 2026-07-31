defmodule Mosslet.Workers.MosskeysCheckpointWorkerTest do
  use Mosslet.DataCase, async: false

  import Plug.Conn

  alias Mosslet.Workers.MosskeysCheckpointWorker

  @origin "mosskeys.com/mosslet"

  setup do
    previous = Application.get_env(:mosslet, :mosskeys_req_options, [])

    on_exit(fn ->
      Application.put_env(:mosslet, :mosskeys_req_options, previous)
      System.delete_env("MOSSKEYS_NAMESPACE_TOKEN")
      System.delete_env("MOSSKEYS_CHECKPOINT_SK")
    end)

    :ok
  end

  defp perform do
    Oban.Testing.perform_job(MosskeysCheckpointWorker, %{}, repo: Mosslet.Repo)
  end

  # A stubbed mosskeys API with a tree head at `head_size` and (optionally) a
  # latest signed checkpoint at `checkpoint_size`. Captures the published note.
  defp stub_log(test_pid, head_size, checkpoint_size) do
    root = Base.encode64(:crypto.strong_rand_bytes(32))

    Application.put_env(:mosslet, :mosskeys_req_options,
      plug: fn conn ->
        conn = put_resp_content_type(conn, "application/json")

        case {conn.method, conn.request_path, conn.body_params} do
          # Phase 1: checkpoint material
          {"POST", "/api/mosslet/log/checkpoints", %{"note_text" => note}} ->
            send(test_pid, {:note_published, note})
            send_resp(conn, 201, Jason.encode!(%{origin: @origin, size: head_size, root: root}))

          {"POST", "/api/mosslet/log/checkpoints", _} ->
            if head_size == 0 do
              # Empty log: phase 1 conflicts, nothing to checkpoint yet.
              send_resp(
                conn,
                409,
                Jason.encode!(%{error: "head_mismatch", message: "empty log"})
              )
            else
              send_resp(
                conn,
                200,
                Jason.encode!(%{origin: @origin, name: @origin, size: head_size, root: root})
              )
            end

          # Public read: latest signed checkpoint
          {"GET", "/api/mosslet/checkpoint", _} ->
            if checkpoint_size == nil do
              send_resp(conn, 404, Jason.encode!(%{error: "not found"}))
            else
              send_resp(
                conn,
                200,
                Jason.encode!(%{
                  origin: @origin,
                  size: checkpoint_size,
                  root: root,
                  note: "old note",
                  cosigners: []
                })
              )
            end
        end
      end
    )

    root
  end

  test "skips quietly without configured secrets" do
    assert :ok = perform()

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")
    System.delete_env("MOSSKEYS_CHECKPOINT_SK")
    assert :ok = perform()
  end

  test "skips when the log is still empty (phase-1 conflict)" do
    stub_log(self(), 0, nil)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")
    System.put_env("MOSSKEYS_CHECKPOINT_SK", checkpoint_sk())

    assert :ok = perform()
    refute_received {:note_published, _}
  end

  test "skips when the latest checkpoint already covers the head" do
    stub_log(self(), 7, 7)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")
    System.put_env("MOSSKEYS_CHECKPOINT_SK", checkpoint_sk())

    assert :ok = perform()
    refute_received {:note_published, _}
  end

  test "signs and publishes when the tree has advanced past the checkpoint" do
    stub_log(self(), 8, 3)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")
    {sk, vkey} = checkpoint_sk_with_vkey()
    System.put_env("MOSSKEYS_CHECKPOINT_SK", sk)

    assert :ok = perform()

    # The published note must verify against the namespace vkey and commit to
    # the stubbed head (origin + size) — the full-circle check.
    assert_received {:note_published, note}
    assert {:ok, checkpoint} = MetamorphicLog.Checkpoint.verify(note, [vkey])
    assert checkpoint.origin == @origin
    assert checkpoint.size == 8
  end

  test "signs the first checkpoint when none exists yet" do
    stub_log(self(), 2, nil)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")
    {sk, vkey} = checkpoint_sk_with_vkey()
    System.put_env("MOSSKEYS_CHECKPOINT_SK", sk)

    assert :ok = perform()

    assert_received {:note_published, note}
    assert {:ok, checkpoint} = MetamorphicLog.Checkpoint.verify(note, [vkey])
    assert checkpoint.size == 2
  end

  test "discards loudly when the configured signing key is malformed" do
    stub_log(self(), 8, nil)

    System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")
    System.put_env("MOSSKEYS_CHECKPOINT_SK", Base.encode64("not-a-valid-key"))

    assert {:discard, _reason} = perform()
  end

  defp checkpoint_sk do
    {sk, _vkey} = checkpoint_sk_with_vkey()
    sk
  end

  defp checkpoint_sk_with_vkey do
    {:ok, %{public_key: pub, secret_key: sk}} =
      MetamorphicCrypto.Sign.generate_signing_keypair_suite(:hybrid, :cat5)

    {:ok, vkey} = MetamorphicLog.VerifierKey.encode_hybrid(@origin, pub)
    {sk, vkey}
  end
end
