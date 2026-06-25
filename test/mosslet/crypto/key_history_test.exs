defmodule Mosslet.Crypto.KeyHistoryTest do
  @moduledoc """
  Authoritative, deterministic specification + KAT (known-answer test) for the
  signed key-history leaf format (#290 step 4 / board #315).

  The deliverable lives in JS (assets/js/crypto/key_history.js), but the
  byte-for-byte contract is locked HERE, in Elixir, because the browser WASM
  (`sha3_512WithContext` + `sign`/`verify`) and this server-side NIF
  (`MetamorphicCrypto.Hash` / `MetamorphicCrypto.Sign`) are compiled from the
  SAME audited Rust crate (metamorphic-crypto). That shared crate guarantees the
  JS helper reproduces these hash values exactly, and any future SDK — and the
  future metamorphic-log leaf (#299/#316) — must too.

  ## Canonical leaf (mosslet/key-history/v1) — mirror of key_history.js

      canonical(entry) =
          u32_be(VERSION = 1)
       || u64_be(seq)
       || u64_be(ts_ms)
       || lp(enc_x25519_raw)
       || lp(enc_pq_raw)
       || lp(signing_pub_raw)
       || lp(prev_entry_hash_raw)        # 0-length for genesis

      where lp(x) = u32_be(byte_size(x)) || x

      entry_hash = sha3_512_with_context("mosslet/key-history/v1", base64(canonical))

  ## Signing

      genesis (seq 0)   : self-signed by its own signing secret (TOFU anchor)
      rotation (seq N>0): signed by the PREVIOUS entry's signing secret,
                          chained via prev_hash = prev.entry_hash

  ML-DSA signing is randomized (hedged), so signature BYTES are never pinned —
  only the canonical layout, the entry_hash digests, and sign/verify + chain
  semantics are locked.
  """
  use ExUnit.Case, async: true

  @context "mosslet/key-history/v1"
  @version 1

  # --- Reference implementation (kept identical to assets/js/crypto/key_history.js) ---

  defp lp(bytes), do: <<byte_size(bytes)::big-32, bytes::binary>>

  defp canonical_entry_bytes(%{
         seq: seq,
         ts: ts,
         enc_x25519: x,
         enc_pq: pq,
         sign_pub: sp,
         prev_hash: prev
       }) do
    prev_raw = if prev == "" or is_nil(prev), do: <<>>, else: Base.decode64!(prev)

    <<@version::big-32, seq::big-64, ts::big-64>> <>
      lp(Base.decode64!(x)) <>
      lp(Base.decode64!(pq)) <>
      lp(Base.decode64!(sp)) <>
      lp(prev_raw)
  end

  defp entry_hash(fields) do
    canonical = canonical_entry_bytes(fields)
    {:ok, b64} = MetamorphicCrypto.Hash.sha3_512_with_context(@context, Base.encode64(canonical))
    b64
  end

  defp build_genesis(%{enc_x25519: x, enc_pq: pq} = _enc, signing_kp, ts) do
    fields = %{
      seq: 0,
      ts: ts,
      enc_x25519: x,
      enc_pq: pq,
      sign_pub: signing_kp.public_key,
      prev_hash: ""
    }

    canonical = canonical_entry_bytes(fields)
    {:ok, sig} = MetamorphicCrypto.Sign.sign(canonical, @context, signing_kp.secret_key)

    fields
    |> Map.put(:v, @version)
    |> Map.put(:entry_hash, entry_hash(fields))
    |> Map.put(:sig, sig)
  end

  defp build_rotation(prev_entry, %{enc_x25519: x, enc_pq: pq}, new_signing_kp, prev_secret, ts) do
    fields = %{
      seq: prev_entry.seq + 1,
      ts: ts,
      enc_x25519: x,
      enc_pq: pq,
      sign_pub: new_signing_kp.public_key,
      prev_hash: prev_entry.entry_hash
    }

    canonical = canonical_entry_bytes(fields)
    {:ok, sig} = MetamorphicCrypto.Sign.sign(canonical, @context, prev_secret)

    fields
    |> Map.put(:v, @version)
    |> Map.put(:entry_hash, entry_hash(fields))
    |> Map.put(:sig, sig)
  end

  defp verify_entry(entry, signer_pub) do
    canonical = canonical_entry_bytes(entry)

    entry.entry_hash == entry_hash(entry) and
      MetamorphicCrypto.Sign.verify(canonical, @context, entry.sig, signer_pub)
  end

  defp verify_chain(entries, pinned_root) do
    [genesis | _] = entries

    cond do
      genesis.seq != 0 ->
        {:error, :not_genesis}

      pinned_root && genesis.sign_pub != pinned_root ->
        {:error, :root_mismatch}

      not verify_entry(genesis, genesis.sign_pub) ->
        {:error, :genesis_sig}

      true ->
        entries
        |> Enum.with_index()
        |> Enum.drop(1)
        |> Enum.reduce_while({:ok, genesis}, fn {cur, i}, {:ok, _} ->
          prev = Enum.at(entries, i - 1)

          cond do
            cur.seq != i -> {:halt, {:error, :seq}}
            cur.prev_hash != prev.entry_hash -> {:halt, {:error, :chain}}
            not verify_entry(cur, prev.sign_pub) -> {:halt, {:error, :sig}}
            true -> {:cont, {:ok, cur}}
          end
        end)
        |> case do
          {:ok, head} -> {:ok, head}
          err -> err
        end
    end
  end

  # --- Fixed, reproducible test material (hash KAT only — no signing) ---
  defp x_a, do: :binary.list_to_bin(Enum.map(0..31, &rem(&1 * 7 + 1, 256)))
  defp pq_a, do: :binary.list_to_bin(Enum.map(0..1599, &rem(&1, 256)))
  defp x_b, do: :binary.list_to_bin(Enum.map(0..31, &rem(&1 * 5 + 3, 256)))
  defp sp_fixed, do: :binary.list_to_bin(Enum.map(0..2624, &rem(&1 * 3, 256)))
  @genesis_ts 1_700_000_000_000
  @rotation_ts 1_700_000_100_000

  # --- LOCKED KAT VECTORS (cross-SDK contract; do not change without bumping v1) ---
  @kat_genesis_hash "ueTkShE9EQ1ROe8DFVa0m706AJPrsJyLGt2uSSzmStPty0xtu3gX2zjvBNdgA9swPWYEXx+wEsjDNXbOmzhJFA=="
  @kat_rotation_hash "14CrClVh3k5BrmUQT9FZ3UnE1wZG9820t3eXynXXMwmk6YV1V4ykoCiT79HA1BCWKtq6VU4SYEflZMYeRZoJjQ=="
  @kat_genesis_canon_size 4293

  describe "canonicalization" do
    test "fixed layout: u32_be(version) || u64_be(seq) || u64_be(ts) || lp(x) || lp(pq) || lp(sp) || lp(prev)" do
      x = x_a()
      pq = pq_a()
      sp = sp_fixed()

      fields = %{
        seq: 0,
        ts: @genesis_ts,
        enc_x25519: Base.encode64(x),
        enc_pq: Base.encode64(pq),
        sign_pub: Base.encode64(sp),
        prev_hash: ""
      }

      assert <<1::big-32, 0::big-64, @genesis_ts::big-64, 32::big-32, ^x::binary-size(32),
               1600::big-32, _pq::binary-size(1600), 2625::big-32, _sp::binary-size(2625),
               0::big-32>> = canonical_entry_bytes(fields)
    end

    test "genesis canonical byte size is locked" do
      fields = %{
        seq: 0,
        ts: @genesis_ts,
        enc_x25519: Base.encode64(x_a()),
        enc_pq: Base.encode64(pq_a()),
        sign_pub: Base.encode64(sp_fixed()),
        prev_hash: ""
      }

      assert byte_size(canonical_entry_bytes(fields)) == @kat_genesis_canon_size
    end
  end

  describe "entry_hash (KAT)" do
    test "genesis entry hash matches locked digest" do
      fields = %{
        seq: 0,
        ts: @genesis_ts,
        enc_x25519: Base.encode64(x_a()),
        enc_pq: Base.encode64(pq_a()),
        sign_pub: Base.encode64(sp_fixed()),
        prev_hash: ""
      }

      assert entry_hash(fields) == @kat_genesis_hash
      assert byte_size(Base.decode64!(@kat_genesis_hash)) == 64
    end

    test "rotation entry hash matches locked digest (chains to genesis hash)" do
      fields = %{
        seq: 1,
        ts: @rotation_ts,
        enc_x25519: Base.encode64(x_b()),
        enc_pq: Base.encode64(pq_a()),
        sign_pub: Base.encode64(sp_fixed()),
        prev_hash: @kat_genesis_hash
      }

      assert entry_hash(fields) == @kat_rotation_hash
    end

    test "context domain separation: changing the label changes the digest" do
      fields = %{
        seq: 0,
        ts: @genesis_ts,
        enc_x25519: Base.encode64(x_a()),
        enc_pq: Base.encode64(pq_a()),
        sign_pub: Base.encode64(sp_fixed()),
        prev_hash: ""
      }

      canonical = canonical_entry_bytes(fields)

      {:ok, other} =
        MetamorphicCrypto.Hash.sha3_512_with_context("mosslet/other/v1", Base.encode64(canonical))

      refute other == @kat_genesis_hash
    end
  end

  describe "sign / verify / chain semantics (real hybrid PQ keys)" do
    setup do
      enc = %{enc_x25519: Base.encode64(x_a()), enc_pq: Base.encode64(pq_a())}
      enc2 = %{enc_x25519: Base.encode64(x_b()), enc_pq: Base.encode64(pq_a())}
      g_kp = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      genesis = build_genesis(enc, g_kp, @genesis_ts)
      %{enc: enc, enc2: enc2, g_kp: g_kp, genesis: genesis}
    end

    test "genesis self-signature verifies", %{genesis: genesis} do
      assert verify_entry(genesis, genesis.sign_pub)
    end

    test "valid rotation chains + verifies under pinned root", ctx do
      r_kp = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      rotation = build_rotation(ctx.genesis, ctx.enc2, r_kp, ctx.g_kp.secret_key, @rotation_ts)

      assert {:ok, head} = verify_chain([ctx.genesis, rotation], ctx.genesis.sign_pub)
      assert head.sign_pub == r_kp.public_key
      assert head.enc_x25519 == ctx.enc2.enc_x25519
    end

    test "rotation signed by the WRONG (new) key is rejected — must be signed by previous key",
         ctx do
      r_kp = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      # Forge: sign with the NEW key instead of the previous (genesis) key.
      forged = build_rotation(ctx.genesis, ctx.enc2, r_kp, r_kp.secret_key, @rotation_ts)
      assert {:error, :sig} = verify_chain([ctx.genesis, forged], ctx.genesis.sign_pub)
    end

    test "root mismatch: genesis signing key differs from pinned root", ctx do
      other = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      assert {:error, :root_mismatch} = verify_chain([ctx.genesis], other.public_key)
    end

    test "tampered prev_hash breaks the chain", ctx do
      r_kp = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      rotation = build_rotation(ctx.genesis, ctx.enc2, r_kp, ctx.g_kp.secret_key, @rotation_ts)
      tampered = %{rotation | prev_hash: @kat_rotation_hash}
      assert {:error, _} = verify_chain([ctx.genesis, tampered], ctx.genesis.sign_pub)
    end

    test "reordered / seq-gap entries are rejected", ctx do
      r_kp = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      rotation = build_rotation(ctx.genesis, ctx.enc2, r_kp, ctx.g_kp.secret_key, @rotation_ts)
      assert {:error, _} = verify_chain([rotation, ctx.genesis], ctx.genesis.sign_pub)
    end

    test "tampered key material in an entry fails verify (entry_hash mismatch)", ctx do
      tampered = %{ctx.genesis | enc_x25519: Base.encode64(x_b())}
      refute verify_entry(tampered, tampered.sign_pub)
    end

    test "multi-rotation chain verifies end-to-end", ctx do
      r1 = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      r2 = MetamorphicCrypto.Sign.generate_signing_keypair(:cat5)
      rot1 = build_rotation(ctx.genesis, ctx.enc2, r1, ctx.g_kp.secret_key, @rotation_ts)
      rot2 = build_rotation(rot1, ctx.enc, r2, r1.secret_key, @rotation_ts + 100)

      assert {:ok, head} = verify_chain([ctx.genesis, rot1, rot2], ctx.genesis.sign_pub)
      assert head.sign_pub == r2.public_key
    end
  end
end
