defmodule Mosslet.Encrypted.UtilsTest do
  use ExUnit.Case, async: true

  alias Mosslet.Encrypted.Utils

  describe "decrypt/1" do
    setup do
      %{key: MetamorphicCrypto.Keys.generate_key()}
    end

    test "round-trips a UTF-8 string ciphertext (current wire format)", %{key: key} do
      ciphertext = Utils.encrypt(%{key: key, payload: "hello world"})
      assert {:ok, "hello world"} = Utils.decrypt(%{key: key, payload: ciphertext})
    end

    test "round-trips a raw-binary ciphertext (e.g. image bytes)", %{key: key} do
      bytes = :crypto.strong_rand_bytes(128)
      ciphertext = Utils.encrypt(%{key: key, payload: bytes})
      assert {:ok, ^bytes} = Utils.decrypt(%{key: key, payload: ciphertext})
    end

    test "recovers legacy raw-binary string ciphertext (pre-PQ enacl format)", %{key: key} do
      # Legacy enacl stored the *decoded* nonce<>ciphertext bytes, not base64.
      base64_ct = Utils.encrypt(%{key: key, payload: "legacy text"})
      legacy_raw_ct = Base.decode64!(base64_ct)

      refute String.valid?(legacy_raw_ct)
      assert {:ok, "legacy text"} = Utils.decrypt(%{key: key, payload: legacy_raw_ct})
    end

    test "recovers legacy raw-binary image ciphertext (pre-PQ enacl format)", %{key: key} do
      image = :crypto.strong_rand_bytes(256)
      base64_ct = Utils.encrypt(%{key: key, payload: image})
      legacy_raw_ct = Base.decode64!(base64_ct)

      refute String.valid?(legacy_raw_ct)
      assert {:ok, ^image} = Utils.decrypt(%{key: key, payload: legacy_raw_ct})
    end

    test "returns :failed_verification (does not raise) on malformed raw-binary input" do
      # Regression: the metamorphic_crypto NIF raises ArgumentError on raw-binary
      # input; decrypt/1 must rescue it instead of crashing the caller.
      malformed = <<155, 253, 12, 199, 48, 51, 201, 90, 160, 203, 118, 74>>
      key = "+jgq272Ra79X3zCWVCQGlLqySMmcCJVg7TxOuletSOo="

      assert {:error, :failed_verification} = Utils.decrypt(%{key: key, payload: malformed})
    end

    test "returns :failed_verification when the key is wrong", %{key: key} do
      ciphertext = Utils.encrypt(%{key: key, payload: "secret"})
      wrong_key = MetamorphicCrypto.Keys.generate_key()

      assert {:error, :failed_verification} =
               Utils.decrypt(%{key: wrong_key, payload: ciphertext})
    end

    test "handles nil and empty payloads", %{key: key} do
      assert {:ok, nil} = Utils.decrypt(%{key: key, payload: nil})
      assert {:ok, ""} = Utils.decrypt(%{key: key, payload: ""})
    end
  end
end
