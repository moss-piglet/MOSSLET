defmodule Mosslet.Crypto.KeyFingerprintTest do
  @moduledoc """
  Authoritative, deterministic specification + KAT (known-answer test) for the
  Phase 0 client-side key fingerprint and safety-number primitives.

  The deliverable lives in JS (assets/js/crypto/fingerprint.js), but the
  byte-for-byte contract is locked HERE, in Elixir, because the browser WASM
  (`sha3_512WithContext`) and this server-side NIF
  (`MetamorphicCrypto.Hash.sha3_512_with_context/2`) are compiled from the SAME
  audited Rust crate (metamorphic-crypto). That shared crate guarantees the JS
  helper reproduces these values exactly, and any future SDK must too.

  ## Canonicalization (mosslet/key-fingerprint/v1) — mirror of fingerprint.js

      canonical =
          u32_be(byte_size(x25519_raw)) || x25519_raw
        || u32_be(byte_size(mlkem_raw)) || mlkem_raw

      fingerprint =
        sha3_512_with_context("mosslet/key-fingerprint/v1", base64(canonical))

  X25519 public = 32 raw bytes; ML-KEM public = 1216 (Cat-3/768) or
  1600 (Cat-5/1024) raw bytes (both verified present in production data).

  ## Safety number (Signal-style, order-independent)

  Per fingerprint: first 30 digest bytes -> six 5-byte (40-bit) big-endian
  chunks, each `rem(_, 100_000)` zero-padded to 5 digits => 30 digits.
  `safety_number/2`: sort the two 30-digit strings, concatenate => 60 digits,
  display as 12 groups of 5.
  """
  use ExUnit.Case, async: true

  @context "mosslet/key-fingerprint/v1"

  # --- Reference implementation (kept identical to assets/js/crypto/fingerprint.js) ---

  defp canonical_key_bytes(x25519_raw, mlkem_raw) do
    <<byte_size(x25519_raw)::big-32, x25519_raw::binary, byte_size(mlkem_raw)::big-32,
      mlkem_raw::binary>>
  end

  defp compute_fingerprint(x25519_raw, mlkem_raw) do
    canonical = canonical_key_bytes(x25519_raw, mlkem_raw)
    {:ok, b64} = MetamorphicCrypto.Hash.sha3_512_with_context(@context, Base.encode64(canonical))
    b64
  end

  defp numeric_fingerprint(fingerprint_b64) do
    <<head::binary-size(30), _rest::binary>> = Base.decode64!(fingerprint_b64)

    for <<chunk::big-40 <- head>>, into: "" do
      String.pad_leading(Integer.to_string(rem(chunk, 100_000)), 5, "0")
    end
  end

  defp group_digits(digits, size) do
    digits
    |> String.codepoints()
    |> Enum.chunk_every(size)
    |> Enum.map_join(" ", &Enum.join/1)
  end

  defp safety_number(a_fp, b_fp) do
    [lo, hi] = Enum.sort([numeric_fingerprint(a_fp), numeric_fingerprint(b_fp)])
    group_digits(lo <> hi, 5)
  end

  defp display_fingerprint(fingerprint_b64) do
    fingerprint_b64
    |> Base.decode64!()
    |> Base.encode16(case: :upper)
    |> group_digits(4)
  end

  # --- Fixed, reproducible test key material ---
  # X25519 = 32 bytes; pqA = Cat-5 (1600 bytes), pqB = Cat-3 (1216 bytes).
  # Derivations are arbitrary-but-fixed so the JS helper / future SDK can
  # regenerate the exact same inputs and confirm the locked outputs below.
  defp x_a, do: :binary.list_to_bin(Enum.map(0..31, &rem(&1 * 7 + 1, 256)))
  defp pq_a, do: :binary.list_to_bin(Enum.map(0..1599, &rem(&1, 256)))
  defp x_b, do: :binary.list_to_bin(Enum.map(0..31, &rem(&1 * 5 + 3, 256)))
  defp pq_b, do: :binary.list_to_bin(Enum.map(0..1215, &rem(&1 * 3, 256)))

  # --- LOCKED KAT VECTORS (cross-SDK contract; do not change without bumping v1) ---
  @kat_fp_a "PAs2DG00sKdMrsE1pi4I+SW/P/PwTzKBNvfJTIFBYDwMnkh25ietPm9jR+4eiBgqI/evaex3fAZNHlCXe8Uwow=="
  @kat_fp_b "jMXAtCt+Se+amVdk6oSAx58OEP+2qmG+acn4mwp9fNO4XKKBg5HcrG5IlXgl7pgJ2mN7qkgk9PwyNnvxqRgLoA=="
  @kat_numeric_a "292615355071336474436098256353"
  @kat_numeric_b "620271874545696911038032936829"
  @kat_safety_number "29261 53550 71336 47443 60982 56353 62027 18745 45696 91103 80329 36829"
  @kat_display_a "3C0B 360C 6D34 B0A7 4CAE C135 A62E 08F9 25BF 3FF3 F04F 3281 36F7 C94C 8141 603C 0C9E 4876 E627 AD3E 6F63 47EE 1E88 182A 23F7 AF69 EC77 7C06 4D1E 5097 7BC5 30A3"

  describe "canonicalization" do
    test "length-prefixed layout: u32_be(len)||x25519 || u32_be(len)||mlkem" do
      x = x_a()
      pq = pq_b()

      assert <<32::big-32, ^x::binary-size(32), 1216::big-32, rest::binary>> =
               canonical_key_bytes(x, pq)

      assert rest == pq
    end
  end

  describe "computeFingerprint (KAT)" do
    test "Cat-5 (ML-KEM-1024) input matches locked digest" do
      assert compute_fingerprint(x_a(), pq_a()) == @kat_fp_a
    end

    test "Cat-3 (ML-KEM-768) input matches locked digest" do
      assert compute_fingerprint(x_b(), pq_b()) == @kat_fp_b
    end

    test "digest is 64 bytes" do
      assert byte_size(Base.decode64!(@kat_fp_a)) == 64
    end

    test "is deterministic" do
      assert compute_fingerprint(x_a(), pq_a()) == compute_fingerprint(x_a(), pq_a())
    end

    test "distinct keys produce distinct fingerprints" do
      refute compute_fingerprint(x_a(), pq_a()) == compute_fingerprint(x_b(), pq_b())
    end

    test "context domain separation: changing the label changes the digest" do
      canonical = canonical_key_bytes(x_a(), pq_a())

      {:ok, other} =
        MetamorphicCrypto.Hash.sha3_512_with_context("mosslet/other/v1", Base.encode64(canonical))

      refute other == @kat_fp_a
    end
  end

  describe "safetyNumber (KAT + properties)" do
    test "numeric fingerprints match locked vectors" do
      assert numeric_fingerprint(@kat_fp_a) == @kat_numeric_a
      assert numeric_fingerprint(@kat_fp_b) == @kat_numeric_b
    end

    test "safety number matches locked vector" do
      assert safety_number(@kat_fp_a, @kat_fp_b) == @kat_safety_number
    end

    test "is order-independent (A and B see the same number)" do
      assert safety_number(@kat_fp_a, @kat_fp_b) == safety_number(@kat_fp_b, @kat_fp_a)
    end

    test "is 60 digits formatted as 12 groups of 5" do
      sn = safety_number(@kat_fp_a, @kat_fp_b)
      groups = String.split(sn, " ")
      assert length(groups) == 12
      assert Enum.all?(groups, &(String.length(&1) == 5))
      assert String.replace(sn, " ", "") |> String.length() == 60
      assert String.match?(String.replace(sn, " ", ""), ~r/^\d{60}$/)
    end

    test "different key pairs produce different safety numbers" do
      x_c = :binary.list_to_bin(Enum.map(0..31, &rem(&1 * 11 + 9, 256)))
      fp_c = compute_fingerprint(x_c, pq_a())
      refute safety_number(@kat_fp_a, @kat_fp_b) == safety_number(@kat_fp_a, fp_c)
    end
  end

  describe "displayFingerprint (KAT)" do
    test "grouped uppercase hex matches locked vector" do
      assert display_fingerprint(@kat_fp_a) == @kat_display_a
    end

    test "is 32 groups of 4 hex chars for a 64-byte digest" do
      groups = String.split(display_fingerprint(@kat_fp_a), " ")
      assert length(groups) == 32
      assert Enum.all?(groups, &String.match?(&1, ~r/^[0-9A-F]{4}$/))
    end
  end
end
