defmodule Mosslet.Bluesky.OAuth do
  @moduledoc """
  Bluesky OAuth implementation with PKCE and DPoP support.

  Implements the AT Protocol OAuth flow for client applications:
  1. Generate PKCE code verifier/challenge
  2. Generate DPoP key pair for proof-of-possession
  3. Push Authorization Request (PAR) to get request_uri
  4. Redirect user to authorization endpoint
  5. Exchange authorization code for tokens (with DPoP proof)
  6. Refresh tokens as needed (with DPoP proof)
  """

  require Logger

  @authorization_server "https://bsky.social"
  @client_id_base "https://mosslet.com"
  @scope "atproto transition:generic"

  defmodule State do
    @moduledoc "OAuth state stored in session during authorization flow"
    @derive Jason.Encoder
    defstruct [
      :code_verifier,
      :dpop_private_key_jwk,
      :dpop_public_key_jwk,
      :state,
      :nonce,
      :created_at
    ]
  end

  @doc """
  Starts the OAuth authorization flow.

  Returns {:ok, authorization_url, state} where state should be stored in session.
  """
  def start_authorization(redirect_uri) do
    with {:ok, metadata} <- fetch_authorization_server_metadata(),
         {:ok, pkce} <- generate_pkce(),
         {:ok, dpop_keys} <- generate_dpop_keypair(),
         {:ok, state_token} <- generate_state_token(),
         {:ok, request_uri} <-
           push_authorization_request(metadata, pkce, dpop_keys, redirect_uri, state_token) do
      state = %State{
        code_verifier: pkce.code_verifier,
        dpop_private_key_jwk: dpop_keys.private_jwk,
        dpop_public_key_jwk: dpop_keys.public_jwk,
        state: state_token,
        nonce: nil,
        created_at: DateTime.utc_now()
      }

      authorization_url = build_authorization_url(metadata, request_uri)

      {:ok, authorization_url, state}
    end
  end

  @doc """
  Exchanges the authorization code for access and refresh tokens.
  """
  def exchange_code(code, state, redirect_uri) do
    with {:ok, metadata} <- fetch_authorization_server_metadata(),
         {:ok, dpop_proof} <-
           create_dpop_proof(
             state.dpop_private_key_jwk,
             state.dpop_public_key_jwk,
             "POST",
             metadata["token_endpoint"]
           ),
         {:ok, tokens} <- request_tokens(metadata, code, state, redirect_uri, dpop_proof) do
      {:ok, tokens}
    end
  end

  @doc """
  Refreshes the access token using the refresh token.
  """
  def refresh_tokens(refresh_token, dpop_private_jwk, dpop_public_jwk) do
    with {:ok, metadata} <- fetch_authorization_server_metadata() do
      request_token_refresh(metadata, refresh_token, dpop_private_jwk, dpop_public_jwk, nil)
    end
  end

  @doc """
  Gets the client ID for the OAuth flow.
  The client ID is the URL to the client metadata document.
  """
  def client_id do
    host = Application.get_env(:mosslet, :canonical_host) || "localhost:4000"
    scheme = if String.contains?(host, "localhost"), do: "http", else: "https"
    "#{scheme}://#{host}/oauth/client-metadata.json"
  end

  @doc """
  Returns the client metadata document that must be served at the client_id URL.
  """
  def client_metadata(redirect_uri) do
    %{
      "client_id" => client_id(),
      "client_name" => "Mosslet",
      "client_uri" => @client_id_base,
      "logo_uri" => "#{@client_id_base}/images/logo.png",
      "tos_uri" => "#{@client_id_base}/terms",
      "policy_uri" => "#{@client_id_base}/privacy",
      "redirect_uris" => [redirect_uri],
      "scope" => @scope,
      "grant_types" => ["authorization_code", "refresh_token"],
      "response_types" => ["code"],
      "token_endpoint_auth_method" => "none",
      "application_type" => "web",
      "dpop_bound_access_tokens" => true
    }
  end

  defp fetch_authorization_server_metadata do
    url = "#{@authorization_server}/.well-known/oauth-authorization-server"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to fetch OAuth metadata: #{status} - #{inspect(body)}")
        {:error, :metadata_fetch_failed}

      {:error, reason} ->
        Logger.error("Failed to fetch OAuth metadata: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_pkce do
    code_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    code_challenge =
      :crypto.hash(:sha256, code_verifier)
      |> Base.url_encode64(padding: false)

    {:ok, %{code_verifier: code_verifier, code_challenge: code_challenge}}
  end

  defp generate_dpop_keypair do
    {pub_key, priv_key} = :crypto.generate_key(:ecdh, :secp256r1)

    <<4, x::binary-size(32), y::binary-size(32)>> = pub_key

    kid =
      :crypto.hash(:sha256, pub_key) |> Base.url_encode64(padding: false) |> String.slice(0, 16)

    public_jwk = %{
      "kty" => "EC",
      "crv" => "P-256",
      "x" => Base.url_encode64(x, padding: false),
      "y" => Base.url_encode64(y, padding: false),
      "kid" => kid
    }

    private_jwk =
      Map.merge(public_jwk, %{
        "d" => Base.url_encode64(priv_key, padding: false)
      })

    {:ok, %{public_jwk: public_jwk, private_jwk: private_jwk}}
  end

  defp generate_state_token do
    {:ok, :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)}
  end

  defp push_authorization_request(metadata, pkce, dpop_keys, redirect_uri, state_token) do
    push_authorization_request(metadata, pkce, dpop_keys, redirect_uri, state_token, nil)
  end

  defp push_authorization_request(metadata, pkce, dpop_keys, redirect_uri, state_token, nonce) do
    par_endpoint = metadata["pushed_authorization_request_endpoint"]

    {:ok, dpop_proof} =
      create_dpop_proof(
        dpop_keys.private_jwk,
        dpop_keys.public_jwk,
        "POST",
        par_endpoint,
        nonce
      )

    body = %{
      "client_id" => client_id(),
      "response_type" => "code",
      "redirect_uri" => redirect_uri,
      "scope" => @scope,
      "state" => state_token,
      "code_challenge" => pkce.code_challenge,
      "code_challenge_method" => "S256"
    }

    case Req.post(par_endpoint,
           form: body,
           headers: [
             {"DPoP", dpop_proof},
             {"Content-Type", "application/x-www-form-urlencoded"}
           ]
         ) do
      {:ok, %{status: status, body: %{"request_uri" => request_uri}}} when status in [200, 201] ->
        {:ok, request_uri}

      {:ok, %{status: 400, headers: headers, body: %{"error" => "use_dpop_nonce"}}}
      when is_nil(nonce) ->
        case get_dpop_nonce(headers) do
          {:ok, new_nonce} ->
            push_authorization_request(
              metadata,
              pkce,
              dpop_keys,
              redirect_uri,
              state_token,
              new_nonce
            )

          :error ->
            {:error,
             {:par_failed, 400,
              %{"error" => "use_dpop_nonce", "error_description" => "No nonce in response"}}}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("PAR request failed: #{status} - #{inspect(body)}")
        {:error, {:par_failed, status, body}}

      {:error, reason} ->
        Logger.error("PAR request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_dpop_nonce(headers) when is_map(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> {:ok, nonce}
      _ -> :error
    end
  end

  defp build_authorization_url(metadata, request_uri) do
    auth_endpoint = metadata["authorization_endpoint"]

    query =
      URI.encode_query(%{
        "client_id" => client_id(),
        "request_uri" => request_uri
      })

    "#{auth_endpoint}?#{query}"
  end

  defp create_dpop_proof(private_jwk, public_jwk, http_method, http_uri, nonce \\ nil) do
    jti = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    iat = System.system_time(:second)

    header = %{
      "typ" => "dpop+jwt",
      "alg" => "ES256",
      "jwk" => public_jwk
    }

    payload = %{
      "jti" => jti,
      "htm" => http_method,
      "htu" => http_uri,
      "iat" => iat
    }

    payload = if nonce, do: Map.put(payload, "nonce", nonce), else: payload

    sign_jwt(header, payload, private_jwk)
  end

  defp sign_jwt(header, payload, private_jwk) do
    d_bytes = Base.url_decode64!(private_jwk["d"], padding: false)

    header_b64 = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    payload_b64 = payload |> Jason.encode!() |> Base.url_encode64(padding: false)
    signing_input = "#{header_b64}.#{payload_b64}"

    signature = :crypto.sign(:ecdsa, :sha256, signing_input, [d_bytes, :secp256r1])

    {:ok, der_sig} = decode_der_signature(signature)
    raw_sig = der_sig |> Base.url_encode64(padding: false)

    {:ok, "#{signing_input}.#{raw_sig}"}
  end

  defp decode_der_signature(der) do
    <<0x30, _len, 0x02, r_len, r::binary-size(r_len), 0x02, s_len, rest::binary>> = der
    <<s::binary-size(s_len), _::binary>> = rest

    r_padded = pad_to_32(r)
    s_padded = pad_to_32(s)

    {:ok, r_padded <> s_padded}
  end

  defp pad_to_32(bytes) when byte_size(bytes) == 32, do: bytes

  defp pad_to_32(bytes) when byte_size(bytes) < 32 do
    padding = 32 - byte_size(bytes)
    :binary.copy(<<0>>, padding) <> bytes
  end

  defp pad_to_32(bytes) when byte_size(bytes) > 32 do
    binary_part(bytes, byte_size(bytes) - 32, 32)
  end

  defp request_tokens(metadata, code, state, redirect_uri, dpop_proof) do
    request_tokens(metadata, code, state, redirect_uri, dpop_proof, nil)
  end

  defp request_tokens(metadata, code, state, redirect_uri, _dpop_proof, nonce) do
    token_endpoint = metadata["token_endpoint"]

    {:ok, dpop_proof} =
      create_dpop_proof(
        state.dpop_private_key_jwk,
        state.dpop_public_key_jwk,
        "POST",
        token_endpoint,
        nonce
      )

    body = %{
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => redirect_uri,
      "client_id" => client_id(),
      "code_verifier" => state.code_verifier
    }

    case Req.post(token_endpoint,
           form: body,
           headers: [
             {"DPoP", dpop_proof},
             {"Content-Type", "application/x-www-form-urlencoded"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           access_token: body["access_token"],
           refresh_token: body["refresh_token"],
           token_type: body["token_type"],
           expires_in: body["expires_in"],
           scope: body["scope"],
           sub: body["sub"]
         }}

      {:ok, %{status: 400, headers: headers, body: %{"error" => "use_dpop_nonce"}}}
      when is_nil(nonce) ->
        case get_dpop_nonce(headers) do
          {:ok, new_nonce} ->
            request_tokens(metadata, code, state, redirect_uri, nil, new_nonce)

          :error ->
            {:error,
             {:token_request_failed, 400,
              %{"error" => "use_dpop_nonce", "error_description" => "No nonce in response"}}}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Token request failed: #{status} - #{inspect(body)}")
        {:error, {:token_request_failed, status, body}}

      {:error, reason} ->
        Logger.error("Token request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp request_token_refresh(metadata, refresh_token, dpop_private_jwk, dpop_public_jwk, nonce) do
    token_endpoint = metadata["token_endpoint"]

    {:ok, dpop_proof} =
      create_dpop_proof(
        dpop_private_jwk,
        dpop_public_jwk,
        "POST",
        token_endpoint,
        nonce
      )

    body = %{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
      "client_id" => client_id()
    }

    case Req.post(token_endpoint,
           form: body,
           headers: [
             {"DPoP", dpop_proof},
             {"Content-Type", "application/x-www-form-urlencoded"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           access_token: body["access_token"],
           refresh_token: body["refresh_token"],
           token_type: body["token_type"],
           expires_in: body["expires_in"]
         }}

      {:ok, %{status: 400, headers: headers, body: %{"error" => "use_dpop_nonce"}}}
      when is_nil(nonce) ->
        case get_dpop_nonce(headers) do
          {:ok, new_nonce} ->
            request_token_refresh(
              metadata,
              refresh_token,
              dpop_private_jwk,
              dpop_public_jwk,
              new_nonce
            )

          :error ->
            {:error,
             {:token_refresh_failed, 400,
              %{"error" => "use_dpop_nonce", "error_description" => "No nonce in response"}}}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Token refresh failed: #{status} - #{inspect(body)}")
        {:error, {:token_refresh_failed, status, body}}

      {:error, reason} ->
        Logger.error("Token refresh error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
