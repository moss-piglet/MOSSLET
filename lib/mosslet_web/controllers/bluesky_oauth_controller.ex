defmodule MossletWeb.BlueskyOAuthController do
  @moduledoc """
  Handles Bluesky OAuth callbacks and client metadata requests.
  """
  use MossletWeb, :controller

  alias Mosslet.Bluesky
  alias Mosslet.Bluesky.OAuth

  @doc """
  Serves the OAuth client metadata document.
  This must be publicly accessible at the client_id URL.
  """
  def client_metadata(conn, _params) do
    redirect_uri = url(~p"/app/oauth/bluesky/callback")
    metadata = OAuth.client_metadata(redirect_uri)

    conn
    |> put_resp_content_type("application/json")
    |> json(metadata)
  end

  @doc """
  Initiates the OAuth flow by redirecting to Bluesky's authorization page.
  """
  def authorize(conn, _params) do
    redirect_uri = url(~p"/app/oauth/bluesky/callback")

    case OAuth.start_authorization(redirect_uri) do
      {:ok, authorization_url, state} ->
        conn
        |> put_session(:bluesky_oauth_state, state)
        |> redirect(external: authorization_url)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to start Bluesky authorization: #{inspect(reason)}")
        |> redirect(to: ~p"/app/users/bluesky")
    end
  end

  @doc """
  Handles the OAuth callback from Bluesky.
  """
  def callback(conn, %{"code" => code, "state" => state_param}) do
    stored_state = get_session(conn, :bluesky_oauth_state)

    cond do
      is_nil(stored_state) ->
        conn
        |> put_flash(:error, "OAuth session expired. Please try again.")
        |> redirect(to: ~p"/app/users/bluesky")

      stored_state.state != state_param ->
        conn
        |> put_flash(:error, "Invalid OAuth state. Please try again.")
        |> redirect(to: ~p"/app/users/bluesky")

      true ->
        redirect_uri = url(~p"/app/oauth/bluesky/callback")
        handle_token_exchange(conn, code, stored_state, redirect_uri)
    end
  end

  def callback(conn, %{"error" => error, "error_description" => description}) do
    conn
    |> delete_session(:bluesky_oauth_state)
    |> put_flash(:error, "Bluesky authorization failed: #{description || error}")
    |> redirect(to: ~p"/app/users/bluesky")
  end

  def callback(conn, %{"error" => error}) do
    conn
    |> delete_session(:bluesky_oauth_state)
    |> put_flash(:error, "Bluesky authorization failed: #{error}")
    |> redirect(to: ~p"/app/users/bluesky")
  end

  defp handle_token_exchange(conn, code, stored_state, redirect_uri) do
    case OAuth.exchange_code(code, stored_state, redirect_uri) do
      {:ok, tokens} ->
        save_bluesky_account(conn, tokens, stored_state)

      {:error, {:token_request_failed, _status, %{"error" => error, "error_description" => desc}}} ->
        conn
        |> delete_session(:bluesky_oauth_state)
        |> put_flash(:error, "Failed to connect Bluesky: #{desc || error}")
        |> redirect(to: ~p"/app/users/bluesky")

      {:error, reason} ->
        conn
        |> delete_session(:bluesky_oauth_state)
        |> put_flash(:error, "Failed to connect Bluesky: #{inspect(reason)}")
        |> redirect(to: ~p"/app/users/bluesky")
    end
  end

  defp save_bluesky_account(conn, tokens, oauth_state) do
    user = conn.assigns.current_scope.user
    did = tokens.sub

    case fetch_profile(tokens.access_token, did, oauth_state) do
      {:ok, handle} ->
        attrs = %{
          did: did,
          handle: handle,
          access_jwt: tokens.access_token,
          refresh_jwt: tokens.refresh_token,
          signing_key: Jason.encode!(oauth_state.dpop_private_key_jwk),
          pds_url: "https://bsky.social"
        }

        case Bluesky.create_account(user, attrs) do
          {:ok, _account} ->
            conn
            |> delete_session(:bluesky_oauth_state)
            |> put_flash(:success, "Successfully connected to Bluesky!")
            |> redirect(to: ~p"/app/users/bluesky")

          {:error, changeset} ->
            error_msg = format_changeset_errors(changeset)

            conn
            |> delete_session(:bluesky_oauth_state)
            |> put_flash(:error, "Failed to save Bluesky account: #{error_msg}")
            |> redirect(to: ~p"/app/users/bluesky")
        end

      {:error, reason} ->
        conn
        |> delete_session(:bluesky_oauth_state)
        |> put_flash(:error, "Failed to fetch Bluesky profile: #{inspect(reason)}")
        |> redirect(to: ~p"/app/users/bluesky")
    end
  end

  defp fetch_profile(access_token, did, oauth_state) do
    url = "https://bsky.social/xrpc/app.bsky.actor.getProfile"

    {:ok, dpop_proof} =
      OAuth.create_dpop_proof(
        oauth_state.dpop_private_key_jwk,
        oauth_state.dpop_public_key_jwk,
        "GET",
        url,
        access_token: access_token
      )

    case Mosslet.Bluesky.Client.get_profile(access_token, did, dpop_proof: dpop_proof) do
      {:ok, %{handle: handle}} ->
        {:ok, handle}

      {:error, {401, _}} ->
        {:error, :unauthorized}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
