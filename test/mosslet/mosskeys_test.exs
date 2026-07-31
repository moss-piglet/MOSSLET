defmodule Mosslet.MosskeysTest do
  use ExUnit.Case, async: false

  import Plug.Conn

  alias Mosslet.Mosskeys

  setup do
    previous = Application.get_env(:mosslet, :mosskeys_req_options, [])

    on_exit(fn ->
      Application.put_env(:mosslet, :mosskeys_req_options, previous)
      System.delete_env("MOSSKEYS_NAMESPACE_TOKEN")
    end)

    :ok
  end

  defp with_stub(fun) do
    Application.put_env(:mosslet, :mosskeys_req_options, plug: fun)
  end

  describe "api_url/1" do
    test "builds the namespace-scoped URL" do
      assert Mosskeys.api_url("/log/entries") ==
               "https://mosskeys.com/api/mosslet/log/entries"
    end
  end

  describe "publish_key/3" do
    test "posts the public key material to the slug-scoped entries endpoint" do
      test_pid = self()

      with_stub(fn conn ->
        {:ok, body, conn} = read_body(conn)
        send(test_pid, {:request, conn, Jason.decode!(body)})

        assert conn.request_path == "/api/mosslet/log/entries"
        assert get_req_header(conn, "authorization") == ["Bearer msk_test_token"]

        send_resp(
          put_resp_content_type(conn, "application/json"),
          200,
          Jason.encode!(%{index: 42, size: 43, root: "cm9vdA=="})
        )
      end)

      System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

      entry =
        Jason.encode!(%{
          "enc_x25519" => "x-pub",
          "enc_pq" => "pq-pub",
          "sign_pub" => "sign-pub"
        })

      assert {:ok, 42} = Mosskeys.publish_key("user-123", entry)

      assert_received {:request, _conn, body}

      assert body == %{
               "label" => "user-123",
               "enc_x25519" => "x-pub",
               "enc_pq" => "pq-pub",
               "signing_pub" => "sign-pub"
             }
    end

    test "prefers the explicit signing_public_key fallback" do
      with_stub(fn conn ->
        {:ok, _body, conn} = read_body(conn)

        send_resp(
          put_resp_content_type(conn, "application/json"),
          200,
          Jason.encode!(%{index: 1})
        )
      end)

      System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

      assert {:ok, 1} = Mosskeys.publish_key("user-123", nil, "explicit-sign-pub")
    end

    test "returns the upstream status on failure" do
      with_stub(fn conn ->
        send_resp(
          put_resp_content_type(conn, "application/json"),
          403,
          Jason.encode!(%{error: "forbidden"})
        )
      end)

      System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

      assert {:error, 403} = Mosskeys.publish_key("user-123", nil)
    end

    test "returns :missing_token without a configured token" do
      System.delete_env("MOSSKEYS_NAMESPACE_TOKEN")

      assert {:error, :missing_token} = Mosskeys.publish_key("user-123", nil)
    end
  end

  describe "fetch_latest_checkpoint/0" do
    test "parses the checkpoint payload" do
      with_stub(fn conn ->
        assert conn.request_path == "/api/mosslet/checkpoint"
        assert conn.method == "GET"

        send_resp(
          put_resp_content_type(conn, "application/json"),
          200,
          Jason.encode!(%{
            origin: "mosskeys.com/mosslet",
            size: 7,
            root: "cm9vdA==",
            note: "note text",
            cosigners: ["witness-a"]
          })
        )
      end)

      assert {:ok, checkpoint} = Mosskeys.fetch_latest_checkpoint()
      assert checkpoint.origin == "mosskeys.com/mosslet"
      assert checkpoint.size == 7
      assert checkpoint.root == "cm9vdA=="
      assert checkpoint.note == "note text"
      assert checkpoint.cosigners == ["witness-a"]
    end

    test "maps 404 to :not_found (no checkpoint yet)" do
      with_stub(fn conn ->
        send_resp(
          put_resp_content_type(conn, "application/json"),
          404,
          Jason.encode!(%{error: "not found"})
        )
      end)

      assert {:error, :not_found} = Mosskeys.fetch_latest_checkpoint()
    end
  end

  describe "checkpoint handshake" do
    test "request_checkpoint_head/0 parses phase-1 material" do
      with_stub(fn conn ->
        assert conn.request_path == "/api/mosslet/log/checkpoints"
        assert conn.method == "POST"

        send_resp(
          put_resp_content_type(conn, "application/json"),
          200,
          Jason.encode!(%{
            origin: "mosskeys.com/mosslet",
            name: "mosskeys.com/mosslet",
            size: 3,
            root: "cm9vdA=="
          })
        )
      end)

      System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

      assert {:ok, head} = Mosskeys.request_checkpoint_head()
      assert head.origin == "mosskeys.com/mosslet"
      assert head.name == "mosskeys.com/mosslet"
      assert head.size == 3
      assert head.root == "cm9vdA=="
    end

    test "publish_checkpoint/1 posts the note and maps 201 to :ok" do
      test_pid = self()

      with_stub(fn conn ->
        {:ok, body, conn} = read_body(conn)
        send(test_pid, {:checkpoint_body, Jason.decode!(body)})

        send_resp(
          put_resp_content_type(conn, "application/json"),
          201,
          Jason.encode!(%{origin: "o", size: 3, root: "cm9vdA=="})
        )
      end)

      System.put_env("MOSSKEYS_NAMESPACE_TOKEN", "msk_test_token")

      assert :ok = Mosskeys.publish_checkpoint("the-note")
      assert_received {:checkpoint_body, %{"note_text" => "the-note"}}
    end
  end
end
