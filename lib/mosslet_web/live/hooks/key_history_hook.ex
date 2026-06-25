defmodule MossletWeb.KeyHistoryHook do
  @moduledoc """
  Global LiveView hook for the signed key-history WRITE path (#290 step 4 / #315).

  The browser-side `SessionKeyDeriver` (app layout, every authenticated page)
  generates the hybrid PQ signing keypair + builds the genesis leaf when a user
  has none yet, then pushes two events. Because that hook is global — not tied to
  any single LiveView — we attach the matching `handle_event` handlers globally
  via `attach_hook/4` (mirroring `SyncStatusHook`), so whichever authenticated
  LiveView happens to be mounted receives them.

  Both handlers act on the CURRENT USER ONLY (server-authoritative; the user id
  is never taken from params) and the server stays DUMB — it stores the opaque,
  browser-signed material and never signs or verifies:

    * `"store_signing_keys"` → `Accounts.set_user_signing_keys/3`
      Persists the signing public key + the secret sealed under the user's
      `user_key`.

    * `"append_key_history"` → `Accounts.append_key_history_entry/4`
      Appends one opaque, byte-reproducible public leaf. Append-only / idempotent
      at the context layer (`on_conflict: :nothing` on `[:user_id, :seq]`), so a
      duplicate `seq` is a harmless no-op.

  Wiring: add `MossletWeb.KeyHistoryHook` to the `on_mount` list of each
  authenticated `live_session` in the router.
  """

  import Phoenix.LiveView, only: [attach_hook: 4]

  alias Mosslet.Accounts

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :key_history_write, :handle_event, &handle_event/3)}
  end

  defp handle_event(
         "store_signing_keys",
         %{
           "signing_public_key" => signing_public_key,
           "encrypted_signing_private_key" => encrypted_signing_private_key
         },
         socket
       )
       when is_binary(signing_public_key) and signing_public_key != "" and
              is_binary(encrypted_signing_private_key) and encrypted_signing_private_key != "" do
    case current_user(socket) do
      %{} = user ->
        _ =
          Accounts.set_user_signing_keys(
            user,
            signing_public_key,
            encrypted_signing_private_key
          )

      _ ->
        :ok
    end

    {:halt, socket}
  end

  defp handle_event("store_signing_keys", _params, socket), do: {:halt, socket}

  defp handle_event(
         "append_key_history",
         %{"seq" => seq, "entry" => entry} = params,
         socket
       )
       when is_binary(entry) and entry != "" do
    seq = normalize_seq(seq)
    signing_public_key = params["signing_public_key"]

    case {current_user(socket), seq} do
      {%{id: user_id}, s} when is_integer(s) and s >= 0 ->
        _ = Accounts.append_key_history_entry(user_id, s, entry, signing_public_key)

      _ ->
        :ok
    end

    {:halt, socket}
  end

  defp handle_event("append_key_history", _params, socket), do: {:halt, socket}

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp current_user(socket) do
    case socket.assigns do
      %{current_scope: %{user: %{} = user}} -> user
      %{current_user: %{} = user} -> user
      _ -> nil
    end
  end

  defp normalize_seq(seq) when is_integer(seq), do: seq

  defp normalize_seq(seq) when is_binary(seq) do
    case Integer.parse(seq) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp normalize_seq(_), do: nil
end
