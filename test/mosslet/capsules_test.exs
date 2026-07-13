defmodule Mosslet.CapsulesTest do
  @moduledoc """
  Context tests for the Time Capsule feature (EPIC #377, task #382).

  Locks in the zero-knowledge boundary (content is browser-encrypted; the
  server only ever stores opaque ciphertext + the plaintext `deliver_on`
  metadata) and the metadata-only lifecycle: sealing, the sealed/delivered
  query split, the "opening today" notification gate, idempotent opening,
  owner-only mutation, and the delivery-worker support functions.
  """
  use Mosslet.DataCase, async: true

  alias Mosslet.Capsules
  alias Mosslet.Capsules.Capsule
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils

  @valid_password "hello world hello world"

  defp get_session_key(user, password) do
    case Mosslet.Accounts.User.valid_key_hash?(user, password) do
      {:ok, key} -> key
      {:error, _} -> nil
    end
  end

  defp user_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        username: "capsule_#{System.unique_integer([:positive])}",
        email: "capsule_#{System.unique_integer([:positive])}@example.com",
        password: @valid_password
      })

    Mosslet.AccountsFixtures.user_fixture(attrs)
  end

  # Inserts a capsule directly, bypassing changeset_zk validation, so we can
  # place `deliver_on` in the past (for delivered/due cases) and stamp lifecycle
  # metadata. Title/body are encrypted with the user_key, mirroring the browser.
  defp insert_capsule(user, key, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    title = Map.get(attrs, :title, "My secret title")
    body = Map.get(attrs, :body, "Dear future self, remember this moment.")

    %Capsule{}
    |> Ecto.Changeset.change(%{
      user_id: user.id,
      title: EncryptedUtils.encrypt_user_data(title, user, key),
      body: EncryptedUtils.encrypt_user_data(body, user, key),
      deliver_on: Map.fetch!(attrs, :deliver_on),
      sealed_at: Map.get(attrs, :sealed_at, now),
      notified_at: Map.get(attrs, :notified_at),
      opened_at: Map.get(attrs, :opened_at),
      stationery: Map.get(attrs, :stationery, "classic"),
      word_count: Map.get(attrs, :word_count, 6)
    })
    |> Repo.insert!()
  end

  setup do
    user = user_fixture()
    key = get_session_key(user, @valid_password)
    %{user: user, key: key}
  end

  describe "Capsule.changeset_zk/2" do
    test "stores encrypted_title/encrypted_body into title/body", %{user: user, key: key} do
      enc_title = EncryptedUtils.encrypt_user_data("Title", user, key)
      enc_body = EncryptedUtils.encrypt_user_data("Body", user, key)

      changeset =
        Capsule.changeset_zk(%Capsule{}, %{
          "encrypted_title" => enc_title,
          "encrypted_body" => enc_body,
          "deliver_on" => Date.add(Date.utc_today(), 30),
          "user_id" => user.id
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :title) == enc_title
      assert Ecto.Changeset.get_field(changeset, :body) == enc_body
    end

    test "requires deliver_on", %{user: user, key: key} do
      enc_body = EncryptedUtils.encrypt_user_data("Body", user, key)

      changeset =
        Capsule.changeset_zk(%Capsule{}, %{
          "encrypted_body" => enc_body,
          "user_id" => user.id
        })

      refute changeset.valid?
      assert %{deliver_on: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires an encrypted body", %{user: user} do
      changeset =
        Capsule.changeset_zk(%Capsule{}, %{
          "deliver_on" => Date.add(Date.utc_today(), 30),
          "user_id" => user.id
        })

      refute changeset.valid?
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a deliver_on in the past or today", %{user: user, key: key} do
      enc_body = EncryptedUtils.encrypt_user_data("Body", user, key)

      for date <- [Date.utc_today(), Date.add(Date.utc_today(), -1)] do
        changeset =
          Capsule.changeset_zk(%Capsule{}, %{
            "encrypted_body" => enc_body,
            "deliver_on" => date,
            "user_id" => user.id
          })

        refute changeset.valid?
        assert %{deliver_on: ["must be a future date"]} = errors_on(changeset)
      end
    end

    test "accepts a future deliver_on", %{user: user, key: key} do
      enc_body = EncryptedUtils.encrypt_user_data("Body", user, key)

      changeset =
        Capsule.changeset_zk(%Capsule{}, %{
          "encrypted_body" => enc_body,
          "deliver_on" => Date.add(Date.utc_today(), 1),
          "user_id" => user.id
        })

      assert changeset.valid?
    end

    test "validates stationery, defaulting nil to classic", %{user: user, key: key} do
      enc_body = EncryptedUtils.encrypt_user_data("Body", user, key)

      base = %{
        "encrypted_body" => enc_body,
        "deliver_on" => Date.add(Date.utc_today(), 30),
        "user_id" => user.id
      }

      # A valid stationery passes through.
      valid = Capsule.changeset_zk(%Capsule{}, Map.put(base, "stationery", "lavender"))
      assert valid.valid?
      assert Ecto.Changeset.get_field(valid, :stationery) == "lavender"

      # An unknown stationery is rejected.
      invalid = Capsule.changeset_zk(%Capsule{}, Map.put(base, "stationery", "neon-chartreuse"))
      refute invalid.valid?
      assert %{stationery: ["is not a valid stationery"]} = errors_on(invalid)

      # Missing stationery defaults to "classic".
      defaulted = Capsule.changeset_zk(%Capsule{}, base)
      assert Ecto.Changeset.get_field(defaulted, :stationery) == "classic"
    end

    test "sets sealed_at automatically", %{user: user, key: key} do
      enc_body = EncryptedUtils.encrypt_user_data("Body", user, key)

      changeset =
        Capsule.changeset_zk(%Capsule{}, %{
          "encrypted_body" => enc_body,
          "deliver_on" => Date.add(Date.utc_today(), 30),
          "user_id" => user.id
        })

      assert %DateTime{} = Ecto.Changeset.get_field(changeset, :sealed_at)
    end
  end

  describe "create_capsule_zk/2 (ZK boundary)" do
    test "persists ciphertext, never plaintext", %{user: user, key: key} do
      plaintext_title = "TopSecretTitleWord"
      plaintext_body = "ConfidentialBodyPhraseHere"

      enc_title = EncryptedUtils.encrypt_user_data(plaintext_title, user, key)
      enc_body = EncryptedUtils.encrypt_user_data(plaintext_body, user, key)

      assert {:ok, %Capsule{} = capsule} =
               Capsules.create_capsule_zk(user, %{
                 "encrypted_title" => enc_title,
                 "encrypted_body" => enc_body,
                 "deliver_on" => Date.add(Date.utc_today(), 30),
                 "word_count" => 3
               })

      # Reload from the DB to be sure we're asserting on stored bytes.
      stored = Repo.get!(Capsule, capsule.id)

      refute stored.title =~ plaintext_title
      refute stored.body =~ plaintext_body

      # ...and the round-trip still decrypts back to the original plaintext.
      decrypted = Capsules.decrypt_capsule(stored, user, key)
      assert decrypted.title == plaintext_title
      assert decrypted.body == plaintext_body
    end
  end

  describe "query split" do
    test "list_sealed / list_delivered / list_opening_today partition by deliver_on", %{
      user: user,
      key: key
    } do
      sealed = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 10)})
      today = insert_capsule(user, key, %{deliver_on: Date.utc_today()})
      past = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), -5)})

      assert Enum.map(Capsules.list_sealed(user), & &1.id) == [sealed.id]

      delivered_ids = Enum.map(Capsules.list_delivered(user), & &1.id)
      assert today.id in delivered_ids
      assert past.id in delivered_ids
      refute sealed.id in delivered_ids

      assert Enum.map(Capsules.list_opening_today(user), & &1.id) == [today.id]
    end

    test "count_sealed counts future capsules; count_opening_today excludes opened", %{
      user: user,
      key: key
    } do
      insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 10)})
      insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 20)})

      # Two opening today: one unopened, one already opened.
      insert_capsule(user, key, %{deliver_on: Date.utc_today()})

      insert_capsule(user, key, %{
        deliver_on: Date.utc_today(),
        opened_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert Capsules.count_sealed(user) == 2
      assert Capsules.count_opening_today(user) == 1
    end

    test "queries are scoped to the owner", %{user: user, key: key} do
      other = user_fixture()
      other_key = get_session_key(other, @valid_password)

      insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 10)})
      insert_capsule(other, other_key, %{deliver_on: Date.add(Date.utc_today(), 10)})

      assert Capsules.count_sealed(user) == 1
      assert Capsules.count_sealed(other) == 1
    end
  end

  describe "mark_opened/2" do
    test "sets opened_at, is idempotent, and is owner-only", %{user: user, key: key} do
      capsule = insert_capsule(user, key, %{deliver_on: Date.utc_today()})
      refute capsule.opened_at

      assert {:ok, opened} = Capsules.mark_opened(capsule, user)
      assert %DateTime{} = opened.opened_at

      # Idempotent: re-opening keeps the original timestamp.
      assert {:ok, again} = Capsules.mark_opened(opened, user)
      assert again.opened_at == opened.opened_at

      # Owner-only.
      other = user_fixture()
      assert {:error, :unauthorized} = Capsules.mark_opened(capsule, other)
    end
  end

  describe "delivered?/1" do
    test "gates purely on deliver_on" do
      assert Capsules.delivered?(%Capsule{deliver_on: Date.utc_today()})
      assert Capsules.delivered?(%Capsule{deliver_on: Date.add(Date.utc_today(), -1)})
      refute Capsules.delivered?(%Capsule{deliver_on: Date.add(Date.utc_today(), 1)})
      refute Capsules.delivered?(%Capsule{deliver_on: nil})
    end
  end

  describe "delivery worker support" do
    test "list_due_for_delivery returns due, not-yet-notified capsules", %{user: user, key: key} do
      due = insert_capsule(user, key, %{deliver_on: Date.utc_today()})
      _past_due = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), -3)})

      _already_notified =
        insert_capsule(user, key, %{
          deliver_on: Date.utc_today(),
          notified_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      _future = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 5)})

      due_ids = Enum.map(Capsules.list_due_for_delivery(), & &1.id)
      assert due.id in due_ids
      # Future + already-notified are excluded.
      assert length(due_ids) == 2
    end

    test "mark_notified flips notified_at and removes it from the due list", %{
      user: user,
      key: key
    } do
      capsule = insert_capsule(user, key, %{deliver_on: Date.utc_today()})
      assert capsule.id in Enum.map(Capsules.list_due_for_delivery(), & &1.id)

      assert {:ok, notified} = Capsules.mark_notified(capsule)
      assert %DateTime{} = notified.notified_at

      refute capsule.id in Enum.map(Capsules.list_due_for_delivery(), & &1.id)
    end
  end

  describe "delete_capsule/2" do
    test "is owner-only", %{user: user, key: key} do
      capsule = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 10)})

      other = user_fixture()
      assert {:error, :unauthorized} = Capsules.delete_capsule(capsule, other)
      assert Repo.get(Capsule, capsule.id)

      assert {:ok, _} = Capsules.delete_capsule(capsule, user)
      refute Repo.get(Capsule, capsule.id)
    end
  end

  describe "DeliveryWorker" do
    use Oban.Testing, repo: Mosslet.Repo

    alias Mosslet.Capsules.Jobs.DeliveryWorker

    test "marks all due capsules notified and is idempotent", %{user: user, key: key} do
      due_a = insert_capsule(user, key, %{deliver_on: Date.utc_today()})
      due_b = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), -2)})
      future = insert_capsule(user, key, %{deliver_on: Date.add(Date.utc_today(), 5)})

      assert :ok = perform_job(DeliveryWorker, %{"action" => "deliver_due"})

      assert Repo.get!(Capsule, due_a.id).notified_at
      assert Repo.get!(Capsule, due_b.id).notified_at
      refute Repo.get!(Capsule, future.id).notified_at

      # Idempotent: a second run doesn't re-announce (nothing left due).
      assert Capsules.list_due_for_delivery() == []
      assert :ok = perform_job(DeliveryWorker, %{"action" => "deliver_due"})
    end
  end
end
