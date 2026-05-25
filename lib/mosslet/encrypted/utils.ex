defmodule Mosslet.Encrypted.Utils do
  @moduledoc """
  Encryption utility functions for implementing
  asymmetric encryption for people's accounts.

  Uses MetamorphicCrypto (Rust NIF) for NaCl-compatible operations.
  Wire-format compatible with libsodium and the browser WASM module.

  Special thanks to [@badubizzle](https://github.com/badubizzle).
  """

  @spec generate_key :: binary
  def generate_key do
    MetamorphicCrypto.Keys.generate_key()
  end

  @doc """
  Takes in a key and payload and encrypt payload with the key.
  map: %{key: key, payload: payload}

  Returns `nil` if the payload is nil (nothing to encrypt).
  """
  @spec encrypt(%{key: binary, payload: binary | nil}) :: binary | nil
  def encrypt(%{payload: nil}), do: nil

  def encrypt(%{key: key, payload: payload}) do
    if String.valid?(payload) do
      {:ok, ciphertext} = MetamorphicCrypto.SecretBox.encrypt_string(payload, key)
      ciphertext
    else
      # Raw binary payload (e.g. image bytes) — encode to base64 first
      {:ok, ciphertext} = MetamorphicCrypto.SecretBox.encrypt(Base.encode64(payload), key)
      ciphertext
    end
  end

  @spec decrypt(%{key: binary, payload: binary}) :: {:error, :failed_verification} | {:ok, binary}
  def decrypt(%{key: key, payload: payload}) when is_binary(payload) do
    case MetamorphicCrypto.SecretBox.decrypt_string(payload, key) do
      {:ok, plaintext} ->
        {:ok, plaintext}

      {:error, _reason} ->
        # Plaintext may be raw binary (e.g. image bytes), not UTF-8.
        # Fall back to raw decrypt which returns base64-encoded plaintext.
        case MetamorphicCrypto.SecretBox.decrypt(payload, key) do
          {:ok, plaintext_b64} -> {:ok, Base.decode64!(plaintext_b64)}
          {:error, _reason} -> {:error, :failed_verification}
        end
    end
  end

  def decrypt(%{key: _key, payload: nil}), do: {:ok, nil}
  def decrypt(%{key: _key, payload: ""}), do: {:ok, ""}
  def decrypt(_), do: {:error, :invalid_input}

  @spec decrypt_key_hash(
          binary,
          binary
        ) :: {:error, :failed_verification} | {:ok, binary}
  def decrypt_key_hash(pwd, key_hash) do
    [salt, uk] = key_hash |> String.split("$")
    {:ok, key} = MetamorphicCrypto.KDF.derive_session_key(pwd, salt)

    case decrypt(%{key: key, payload: uk}) do
      {:ok, d_key} -> {:ok, d_key}
      {:error, e} -> {:error, e}
    end
  end

  @doc """
  Takes a password and a key and generate encrypted unique user key.
  This key can only be decrypted with the same password
  """
  @spec generate_key_hash(binary, binary) :: %{key_hash: binary}
  def generate_key_hash(pwd, key) do
    # derive a key from the password
    %{key: gen_key, salt: salt} = derive_pwd_key(pwd)

    # encrypt unique key with password derived key
    key_hash = encrypt(%{key: gen_key, payload: key})

    # return encrypted key with the salt
    %{key_hash: salt <> "$" <> key_hash}
  end

  @spec generate_key_pairs :: %{private: binary, public: binary}
  def generate_key_pairs do
    {public, private} = MetamorphicCrypto.Keys.generate_keypair()
    %{private: private, public: public}
  end

  @spec generate_pq_key_pairs :: %{private: binary, public: binary}
  def generate_pq_key_pairs do
    generate_pq_key_pairs(:cat5)
  end

  @doc """
  Generate a hybrid ML-KEM + X25519 keypair at the given security level.

  Accepts `:cat3` (ML-KEM-768) or `:cat5` (default, ML-KEM-1024).

  Returns `%{private: secret_key_b64, public: public_key_b64}`.
  """
  @spec generate_pq_key_pairs(MetamorphicCrypto.Hybrid.security_level()) :: %{
          private: binary,
          public: binary
        }
  def generate_pq_key_pairs(level) when level in [:cat3, :cat5] do
    {public, private} = MetamorphicCrypto.Hybrid.generate_keypair(level)
    %{private: private, public: public}
  end

  @spec decrypt_message_for_user(binary, %{private: binary, public: binary}, keyword) ::
          {:error, :failed_verification} | {:ok, binary}
  def decrypt_message_for_user(
        encrypted_message,
        %{public: public_key, private: private_key},
        opts \\ []
      ) do
    pq_secret_key = Keyword.get(opts, :pq_secret_key)

    # Always use Seal.unseal_from_user — it auto-detects legacy (v1) vs hybrid (v2)
    # ciphertext format. For legacy ciphertext, pq_secret_key is ignored even if present.
    # For hybrid ciphertext, pq_secret_key is required.
    unseal_opts = if pq_secret_key, do: [pq_secret_key: pq_secret_key], else: []

    case MetamorphicCrypto.Seal.unseal_from_user(
           encrypted_message,
           public_key,
           private_key,
           unseal_opts
         ) do
      {:ok, plaintext} -> {:ok, normalize_unsealed_key(plaintext)}
      {:error, _reason} -> {:error, :failed_verification}
    end
  end

  # The WASM sealForUser decodes its base64 input to raw bytes before sealing,
  # while the NIF seal_for_user seals the UTF-8 string as-is.
  #
  # After unseal, server-sealed keys return the original base64 string (44 chars),
  # while browser-sealed keys return raw 32 bytes.
  #
  # Normalize to always return a base64 string so callers (encrypt, decrypt)
  # receive a consistent format.
  defp normalize_unsealed_key(plaintext) when byte_size(plaintext) == 32 do
    case Base.decode64(plaintext) do
      {:ok, _} ->
        # Already valid base64 (e.g. a 32-char base64 string that happens to decode)
        plaintext

      :error ->
        # Raw 32 bytes from WASM-sealed key — encode to base64
        Base.encode64(plaintext)
    end
  end

  defp normalize_unsealed_key(plaintext), do: plaintext

  @spec encrypt_message_for_user_with_pk(
          binary,
          %{public: binary},
          keyword
        ) :: binary
  def encrypt_message_for_user_with_pk(message, %{public: public_key}, opts \\ []) do
    pq_public_key = Keyword.get(opts, :pq_public_key)
    level = Keyword.get(opts, :level, :cat5)

    if pq_public_key do
      {:ok, ciphertext} =
        MetamorphicCrypto.Seal.seal_for_user(message, public_key,
          pq_public_key: pq_public_key,
          level: level
        )

      ciphertext
    else
      {:ok, ciphertext} = MetamorphicCrypto.BoxSeal.seal(message, public_key)
      ciphertext
    end
  end

  @doc """
  Builds PQ opts keyword list from a user struct.

  Returns `[pq_public_key: key, level: level]` if the user has a PQ public key,
  or `[]` if not (which causes `encrypt_message_for_user_with_pk/3`
  to fall back to legacy box_seal).

  The security level is auto-detected from the PQ public key size:
  - 1600 bytes (raw) → `:cat5` (ML-KEM-1024)
  - 1216 bytes (raw) → `:cat3` (ML-KEM-768)

  An explicit `:level` option overrides the auto-detection.
  """
  @spec pq_opts_for_user(map, keyword) :: keyword
  def pq_opts_for_user(user, opts \\ [])

  def pq_opts_for_user(%{pq_public_key: pq_pk}, opts)
      when is_binary(pq_pk) and pq_pk != "" do
    level = Keyword.get_lazy(opts, :level, fn -> detect_pq_level(pq_pk) end)
    [pq_public_key: pq_pk, level: level]
  end

  def pq_opts_for_user(_, _opts), do: []

  @doc """
  Builds PQ opts keyword list for the server's PQ keypair.

  Returns `[pq_public_key: key, level: :cat5]` when the `SERVER_PQ_PUBLIC_KEY`
  env var is set, or `[]` otherwise (falls back to legacy `box_seal`).

  Used when sealing context keys for public-visibility content (posts, groups,
  memories, profiles, reports) with the server's public key.
  """
  @spec pq_opts_for_server() :: keyword
  def pq_opts_for_server do
    case Mosslet.Encrypted.Session.server_pq_public_key() do
      nil -> []
      "" -> []
      pq_pk -> [pq_public_key: pq_pk, level: :cat5]
    end
  end

  @doc """
  Returns the server's PQ secret key for unsealing, or `nil` if not configured.

  Used by `decrypt_public_item_key/1` and `decrypt_public_item/2` to unseal
  hybrid-sealed public content keys.
  """
  @spec server_pq_unseal_opts() :: keyword
  def server_pq_unseal_opts do
    case Mosslet.Encrypted.Session.server_pq_secret_key() do
      nil -> []
      "" -> []
      pq_sk -> [pq_secret_key: pq_sk]
    end
  end

  @doc """
  Detects the PQ security level from a base64-encoded public key.

  Returns `:cat5` for 1600-byte keys (ML-KEM-1024) and `:cat3` for
  1216-byte keys (ML-KEM-768). Defaults to `:cat5` if unrecognized.
  """
  @spec detect_pq_level(binary) :: :cat3 | :cat5
  def detect_pq_level(pq_public_key_b64) when is_binary(pq_public_key_b64) do
    case Base.decode64(pq_public_key_b64) do
      {:ok, raw} when byte_size(raw) == 1216 -> :cat3
      {:ok, raw} when byte_size(raw) == 1600 -> :cat5
      _ -> :cat5
    end
  end

  # PRIVATE FUNCTIONS

  defp derive_pwd_key(pwd) do
    salt = MetamorphicCrypto.Keys.generate_salt()
    {:ok, key} = MetamorphicCrypto.KDF.derive_session_key(pwd, salt)
    %{salt: salt, key: key}
  end
end
