defmodule Mosslet.Bluesky.Client do
  @moduledoc """
  AT Protocol client for Bluesky integration.

  Handles authentication, token refresh, and API operations for syncing
  posts between Mosslet and Bluesky.

  ## Usage

      # Authenticate with handle and app password
      {:ok, session} = Mosslet.Bluesky.Client.create_session("user.bsky.social", "app-password")

      # Refresh an expired session
      {:ok, session} = Mosslet.Bluesky.Client.refresh_session(refresh_jwt)

      # Fetch user's posts
      {:ok, %{feed: posts, cursor: cursor}} = Mosslet.Bluesky.Client.get_author_feed(access_jwt, did)

      # Create a new post
      {:ok, result} = Mosslet.Bluesky.Client.create_post(access_jwt, did, "Hello from Mosslet!")
  """

  require Logger

  @default_pds "https://bsky.social"
  @default_timeout 30_000

  @type session :: %{
          did: String.t(),
          handle: String.t(),
          access_jwt: String.t(),
          refresh_jwt: String.t(),
          email: String.t() | nil
        }

  @type post_record :: %{
          text: String.t(),
          created_at: String.t(),
          facets: list() | nil,
          embed: map() | nil,
          reply: map() | nil
        }

  @doc """
  Creates a new Bluesky account on a PDS.

  This allows users to create a Bluesky account directly from Mosslet,
  which is a privacy-first onboarding experience.

  ## Options

    * `:pds_url` - PDS to create account on (default: bsky.social)
    * `:invite_code` - Invite code if required by the PDS

  ## Examples

      {:ok, account} = create_account("alice.bsky.social", "alice@example.com", "securepassword123")
      {:ok, account} = create_account("alice.bsky.social", "alice@example.com", "password", invite_code: "bsky-social-abc123")
  """
  @spec create_account(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, session()} | {:error, term()}
  def create_account(handle, email, password, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    body =
      %{
        handle: handle,
        email: email,
        password: password
      }
      |> maybe_put(:inviteCode, opts[:invite_code])

    request(:post, pds_url, "/xrpc/com.atproto.server.createAccount", body)
  end

  @doc """
  Checks if a handle is available for registration.

  ## Examples

      {:ok, %{available: true}} = check_handle_availability("alice.bsky.social")
  """
  @spec check_handle_availability(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def check_handle_availability(handle, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/com.atproto.server.checkAccountStatus", %{handle: handle})
  end

  @doc """
  Describes the server capabilities and requirements.

  Useful for checking if invite codes are required, etc.

  ## Examples

      {:ok, %{inviteCodeRequired: true, ...}} = describe_server()
  """
  @spec describe_server(keyword()) :: {:ok, map()} | {:error, term()}
  def describe_server(opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/com.atproto.server.describeServer", %{})
  end

  @doc """
  Creates a new authenticated session with Bluesky.

  Uses app passwords (not main account password) for security.
  Returns session info including DID, handle, and JWT tokens.

  ## Examples

      {:ok, session} = create_session("alice.bsky.social", "xxxx-xxxx-xxxx-xxxx")
      {:ok, session} = create_session("alice.bsky.social", "xxxx-xxxx-xxxx-xxxx", pds_url: "https://custom.pds.com")
  """
  @spec create_session(String.t(), String.t(), keyword()) :: {:ok, session()} | {:error, term()}
  def create_session(identifier, password, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:post, pds_url, "/xrpc/com.atproto.server.createSession", %{
      identifier: identifier,
      password: password
    })
  end

  @doc """
  Refreshes an authenticated session using the refresh token.

  Should be called before the access token expires (typically 2 hours).
  Returns new access and refresh tokens.

  Note: For OAuth-authenticated sessions, use `refresh_oauth_session/4` instead,
  as OAuth tokens require DPoP proofs.
  """
  @spec refresh_session(String.t(), keyword()) :: {:ok, session()} | {:error, term()}
  def refresh_session(refresh_jwt, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:post, pds_url, "/xrpc/com.atproto.server.refreshSession", %{}, auth: refresh_jwt)
  end

  @doc """
  Refreshes an OAuth-authenticated session using the refresh token with DPoP.

  This is the correct method for OAuth tokens which require DPoP proofs.
  Pass the signing key (private JWK) that was used during OAuth authorization.

  ## Examples

      {:ok, tokens} = refresh_oauth_session(refresh_token, signing_key_jwk)
  """
  @spec refresh_oauth_session(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh_oauth_session(refresh_token, signing_key_jwk, opts \\ []) do
    alias Mosslet.Bluesky.OAuth

    with {:ok, metadata} <- fetch_oauth_metadata(),
         public_jwk <- derive_public_jwk(signing_key_jwk),
         {:ok, tokens} <-
           do_oauth_refresh(metadata, refresh_token, signing_key_jwk, public_jwk, opts) do
      {:ok, tokens}
    end
  end

  defp fetch_oauth_metadata do
    url = "https://bsky.social/.well-known/oauth-authorization-server"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to fetch OAuth metadata: #{status} - #{inspect(body)}")
        {:error, :metadata_fetch_failed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp derive_public_jwk(%{"kty" => "EC", "crv" => crv, "x" => x, "y" => y} = jwk) do
    %{"kty" => "EC", "crv" => crv, "x" => x, "y" => y, "kid" => jwk["kid"]}
  end

  defp do_oauth_refresh(metadata, refresh_token, private_jwk, public_jwk, opts, nonce \\ nil) do
    alias Mosslet.Bluesky.OAuth

    token_endpoint = metadata["token_endpoint"]

    {:ok, dpop_proof} =
      OAuth.create_dpop_proof(private_jwk, public_jwk, "POST", token_endpoint, nonce: nonce)

    body = %{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
      "client_id" => OAuth.client_id()
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
        case get_dpop_nonce_from_headers(headers) do
          {:ok, new_nonce} ->
            do_oauth_refresh(metadata, refresh_token, private_jwk, public_jwk, opts, new_nonce)

          :error ->
            {:error, {:token_refresh_failed, "No nonce in use_dpop_nonce response"}}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("OAuth token refresh failed: #{status} - #{inspect(body)}")
        {:error, {:token_refresh_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_dpop_nonce_from_headers(headers) when is_map(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> {:ok, nonce}
      nonce when is_binary(nonce) -> {:ok, nonce}
      _ -> :error
    end
  end

  defp get_dpop_nonce_from_headers(headers) when is_list(headers) do
    case List.keyfind(headers, "dpop-nonce", 0) do
      {_, nonce} -> {:ok, nonce}
      nil -> :error
    end
  end

  defp get_dpop_nonce_from_headers(_), do: :error

  @doc """
  Deletes the current session (logout).
  """
  @spec delete_session(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_session(refresh_jwt, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    case request(:post, pds_url, "/xrpc/com.atproto.server.deleteSession", %{}, auth: refresh_jwt) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Permanently deletes the user's Bluesky account.

  This is an irreversible operation that removes all data associated with
  the account from the PDS.

  ## Options

    * `:pds_url` - PDS where the account is hosted (default: bsky.social)

  ## Examples

      :ok = delete_bluesky_account(access_jwt, did)
  """
  @spec delete_bluesky_account(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_bluesky_account(access_jwt, did, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    body = %{did: did}

    case request(:post, pds_url, "/xrpc/com.atproto.server.deleteAccount", body, auth: access_jwt) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Gets the current session info.
  """
  @spec get_session(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_session(access_jwt, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/com.atproto.server.getSession", %{}, auth: access_jwt)
  end

  @doc """
  Describes a repository and returns its handle and other metadata.

  This uses the `com.atproto.repo.describeRepo` endpoint which works with the
  `atproto` OAuth scope (unlike `app.bsky.actor.getProfile` which requires app-level scope).

  ## Examples

      {:ok, %{handle: "alice.bsky.social", did: "did:plc:..."}} = describe_repo(jwt, "did:plc:...")
  """
  @spec describe_repo(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def describe_repo(access_jwt, repo, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/com.atproto.repo.describeRepo", %{repo: repo}, auth: access_jwt)
  end

  @doc """
  Resolves a handle to a DID.

  ## Examples

      {:ok, %{did: "did:plc:..."}} = resolve_handle("alice.bsky.social")
  """
  @spec resolve_handle(String.t(), keyword()) :: {:ok, %{did: String.t()}} | {:error, term()}
  def resolve_handle(handle, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/com.atproto.identity.resolveHandle", %{handle: handle})
  end

  @doc """
  Gets a user's profile.

  **DEPRECATED**: This endpoint requires `app.bsky` OAuth scope which is not available
  with the standard `atproto` scope. Use `describe_repo/3` instead for OAuth flows,
  or use this only with app password authentication.
  """
  @deprecated "Use describe_repo/3 for OAuth flows"
  @spec get_profile(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_profile(access_jwt, actor, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/app.bsky.actor.getProfile", %{actor: actor}, auth: access_jwt)
  end

  @doc """
  Gets posts from a user's feed (their authored posts).

  **DEPRECATED**: This endpoint requires `app.bsky` OAuth scope which is not available
  with the standard `atproto` scope. Use `list_records/4` with collection "app.bsky.feed.post"
  instead for OAuth flows, or use this only with app password authentication.

  ## Options

    * `:limit` - Number of posts to fetch (default: 50, max: 100)
    * `:cursor` - Pagination cursor from previous response
    * `:filter` - One of "posts_with_replies", "posts_no_replies", "posts_with_media", "posts_and_author_threads"

  ## Examples

      {:ok, %{feed: posts, cursor: cursor}} = get_author_feed(jwt, "did:plc:...", limit: 25)
  """
  @deprecated "Use list_records/4 with collection \"app.bsky.feed.post\" for OAuth flows"
  @spec get_author_feed(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_author_feed(access_jwt, actor, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    params =
      %{actor: actor}
      |> maybe_put(:limit, opts[:limit])
      |> maybe_put(:cursor, opts[:cursor])
      |> maybe_put(:filter, opts[:filter])

    request(:get, pds_url, "/xrpc/app.bsky.feed.getAuthorFeed", params, auth: access_jwt)
  end

  @doc """
  Lists records from a repository collection.

  Used for fetching raw post records from the AT Protocol repo.

  ## Options

    * `:limit` - Number of records (default: 50, max: 100)
    * `:cursor` - Pagination cursor
    * `:reverse` - Reverse chronological order (default: false)

  ## Examples

      {:ok, %{records: posts, cursor: cursor}} = list_records(jwt, did, "app.bsky.feed.post")
  """
  @spec list_records(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def list_records(access_jwt, repo, collection, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    params =
      %{repo: repo, collection: collection}
      |> maybe_put(:limit, opts[:limit])
      |> maybe_put(:cursor, opts[:cursor])
      |> maybe_put(:reverse, opts[:reverse])

    request(:get, pds_url, "/xrpc/com.atproto.repo.listRecords", params, auth: access_jwt)
  end

  @doc """
  Gets a specific record by its AT URI.

  ## Examples

      {:ok, record} = get_record(jwt, did, "app.bsky.feed.post", "rkey123")
  """
  @spec get_record(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_record(access_jwt, repo, collection, rkey, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    params = %{repo: repo, collection: collection, rkey: rkey}

    request(:get, pds_url, "/xrpc/com.atproto.repo.getRecord", params, auth: access_jwt)
  end

  @doc """
  Creates a new post on Bluesky.

  ## Options

    * `:reply` - Reply reference `%{root: %{uri: ..., cid: ...}, parent: %{uri: ..., cid: ...}}`
    * `:embed` - Embed object (images, links, quotes)
    * `:facets` - Rich text facets (mentions, links, hashtags)
    * `:langs` - Language tags (e.g., ["en"])
    * `:created_at` - Custom timestamp (defaults to now)

  ## Examples

      {:ok, %{uri: uri, cid: cid}} = create_post(jwt, did, "Hello world!")

      # With reply
      {:ok, result} = create_post(jwt, did, "Reply text", reply: %{
        root: %{uri: "at://...", cid: "baf..."},
        parent: %{uri: "at://...", cid: "baf..."}
      })
  """
  @spec create_post(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_post(access_jwt, repo, text, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    record =
      %{
        "$type" => "app.bsky.feed.post",
        "text" => text,
        "createdAt" => opts[:created_at] || DateTime.utc_now() |> DateTime.to_iso8601()
      }
      |> maybe_put("reply", opts[:reply])
      |> maybe_put("embed", opts[:embed])
      |> maybe_put("facets", opts[:facets])
      |> maybe_put("langs", opts[:langs])

    body = %{
      repo: repo,
      collection: "app.bsky.feed.post",
      record: record
    }

    request(:post, pds_url, "/xrpc/com.atproto.repo.createRecord", body, auth: access_jwt)
  end

  @doc """
  Deletes a post from Bluesky.

  ## Examples

      :ok = delete_post(jwt, did, "rkey123")
  """
  @spec delete_post(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_post(access_jwt, repo, rkey, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    body = %{
      repo: repo,
      collection: "app.bsky.feed.post",
      rkey: rkey
    }

    case request(:post, pds_url, "/xrpc/com.atproto.repo.deleteRecord", body, auth: access_jwt) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Uploads a blob (image) to Bluesky.

  Returns the blob reference to use in post embeds.

  ## Examples

      {:ok, %{blob: blob}} = upload_blob(jwt, image_binary, "image/jpeg")

      # Use in post
      create_post(jwt, did, "Check this out!", embed: %{
        "$type" => "app.bsky.embed.images",
        "images" => [%{"alt" => "Description", "image" => blob}]
      })
  """
  @spec upload_blob(String.t(), binary(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def upload_blob(access_jwt, data, content_type, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:post, pds_url, "/xrpc/com.atproto.repo.uploadBlob", data,
      auth: access_jwt,
      content_type: content_type,
      raw_body: true
    )
  end

  @doc """
  Creates a like on a post.

  ## Examples

      {:ok, %{uri: uri, cid: cid}} = create_like(jwt, did, post_uri, post_cid)
  """
  @spec create_like(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_like(access_jwt, repo, subject_uri, subject_cid, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    record = %{
      "$type" => "app.bsky.feed.like",
      "subject" => %{"uri" => subject_uri, "cid" => subject_cid},
      "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    body = %{
      repo: repo,
      collection: "app.bsky.feed.like",
      record: record
    }

    request(:post, pds_url, "/xrpc/com.atproto.repo.createRecord", body, auth: access_jwt)
  end

  @doc """
  Creates a repost of a post.

  ## Examples

      {:ok, %{uri: uri, cid: cid}} = create_repost(jwt, did, post_uri, post_cid)
  """
  @spec create_repost(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_repost(access_jwt, repo, subject_uri, subject_cid, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    record = %{
      "$type" => "app.bsky.feed.repost",
      "subject" => %{"uri" => subject_uri, "cid" => subject_cid},
      "createdAt" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    body = %{
      repo: repo,
      collection: "app.bsky.feed.repost",
      record: record
    }

    request(:post, pds_url, "/xrpc/com.atproto.repo.createRecord", body, auth: access_jwt)
  end

  @doc """
  Gets a post thread (post with replies and parent context).

  **DEPRECATED**: This endpoint requires `app.bsky` OAuth scope which is not available
  with the standard `atproto` scope. Use this only with app password authentication.

  ## Options

    * `:depth` - How many levels of replies to fetch (default: 6, max: 1000)
    * `:parent_height` - How many parent posts to fetch (default: 80, max: 1000)

  ## Examples

      {:ok, %{thread: thread}} = get_post_thread(jwt, "at://did:plc:.../app.bsky.feed.post/...")
  """
  @deprecated "Requires app.bsky OAuth scope - use only with app password auth"
  @spec get_post_thread(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_post_thread(access_jwt, uri, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    params =
      %{uri: uri}
      |> maybe_put(:depth, opts[:depth])
      |> maybe_put(:parentHeight, opts[:parent_height])

    request(:get, pds_url, "/xrpc/app.bsky.feed.getPostThread", params, auth: access_jwt)
  end

  @doc """
  Gets multiple posts by their URIs.

  **DEPRECATED**: This endpoint requires `app.bsky` OAuth scope which is not available
  with the standard `atproto` scope. Use `get_record/5` for individual posts with OAuth,
  or use this only with app password authentication.

  ## Examples

      {:ok, %{posts: posts}} = get_posts(jwt, ["at://...", "at://..."])
  """
  @deprecated "Requires app.bsky OAuth scope - use get_record/5 or app password auth"
  @spec get_posts(String.t(), list(String.t()), keyword()) :: {:ok, map()} | {:error, term()}
  def get_posts(access_jwt, uris, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    request(:get, pds_url, "/xrpc/app.bsky.feed.getPosts", %{uris: uris}, auth: access_jwt)
  end

  @doc """
  Gets the user's home timeline feed.

  **DEPRECATED**: This endpoint requires `app.bsky` OAuth scope which is not available
  with the standard `atproto` scope. Use this only with app password authentication.

  ## Options

    * `:limit` - Number of posts (default: 50, max: 100)
    * `:cursor` - Pagination cursor

  ## Examples

      {:ok, %{feed: posts, cursor: cursor}} = get_timeline(jwt, limit: 25)
  """
  @deprecated "Requires app.bsky OAuth scope - use only with app password auth"
  @spec get_timeline(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_timeline(access_jwt, opts \\ []) do
    pds_url = opts[:pds_url] || @default_pds

    params =
      %{}
      |> maybe_put(:limit, opts[:limit])
      |> maybe_put(:cursor, opts[:cursor])

    request(:get, pds_url, "/xrpc/app.bsky.feed.getTimeline", params, auth: access_jwt)
  end

  @doc """
  Extracts the rkey from an AT URI.

  ## Examples

      "3jui7kd2zoq2s" = extract_rkey("at://did:plc:abc123/app.bsky.feed.post/3jui7kd2zoq2s")
  """
  @spec extract_rkey(String.t()) :: String.t() | nil
  def extract_rkey(at_uri) when is_binary(at_uri) do
    case String.split(at_uri, "/") do
      [_at, _empty, _did, _collection, rkey] -> rkey
      _ -> nil
    end
  end

  def extract_rkey(_), do: nil

  @doc """
  Extracts the DID from an AT URI.

  ## Examples

      "did:plc:abc123" = extract_did("at://did:plc:abc123/app.bsky.feed.post/3jui7kd2zoq2s")
  """
  @spec extract_did(String.t()) :: String.t() | nil
  def extract_did(at_uri) when is_binary(at_uri) do
    case String.split(at_uri, "/") do
      ["at:", "", did, _collection, _rkey] -> did
      _ -> nil
    end
  end

  def extract_did(_), do: nil

  @doc """
  Builds an AT URI from components.

  ## Examples

      "at://did:plc:abc123/app.bsky.feed.post/3jui7kd2zoq2s" = build_at_uri("did:plc:abc123", "app.bsky.feed.post", "3jui7kd2zoq2s")
  """
  @spec build_at_uri(String.t(), String.t(), String.t()) :: String.t()
  def build_at_uri(did, collection, rkey) do
    "at://#{did}/#{collection}/#{rkey}"
  end

  @doc """
  Parses rich text and extracts facets for mentions, links, and hashtags.

  Returns the text and facets to use when creating a post.

  ## Examples

      {text, facets} = parse_facets("Hello @alice.bsky.social! Check out https://example.com #bluesky")
  """
  @spec parse_facets(String.t()) :: {String.t(), list(map())}
  def parse_facets(text) do
    facets = []

    facets = facets ++ extract_mention_facets(text)
    facets = facets ++ extract_link_facets(text)
    facets = facets ++ extract_hashtag_facets(text)

    {text, facets}
  end

  defp extract_mention_facets(text) do
    regex =
      ~r/@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?/

    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start, length} | _] ->
      handle = String.slice(text, start + 1, length - 1)

      %{
        "index" => %{"byteStart" => start, "byteEnd" => start + length},
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#mention",
            "did" => handle
          }
        ]
      }
    end)
  end

  defp extract_link_facets(text) do
    regex = ~r/https?:\/\/[^\s<>\[\]()]+/

    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start, length} | _] ->
      uri = String.slice(text, start, length)

      %{
        "index" => %{"byteStart" => start, "byteEnd" => start + length},
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#link",
            "uri" => uri
          }
        ]
      }
    end)
  end

  defp extract_hashtag_facets(text) do
    regex = ~r/#[a-zA-Z][a-zA-Z0-9_]*/

    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start, length} | _] ->
      tag = String.slice(text, start + 1, length - 1)

      %{
        "index" => %{"byteStart" => start, "byteEnd" => start + length},
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#tag",
            "tag" => tag
          }
        ]
      }
    end)
  end

  defp request(method, pds_url, path, body_or_params, opts \\ []) do
    do_request(method, pds_url, path, body_or_params, opts, _retried_nonce = false)
  end

  defp do_request(method, pds_url, path, body_or_params, opts, retried_nonce) do
    url = pds_url <> path
    headers = build_headers(opts)
    timeout = opts[:timeout] || @default_timeout

    req_opts = [
      headers: headers,
      receive_timeout: timeout
    ]

    req_opts =
      case method do
        :get ->
          Keyword.put(req_opts, :params, body_or_params)

        :post ->
          if opts[:raw_body] do
            Keyword.put(req_opts, :body, body_or_params)
          else
            Keyword.put(req_opts, :json, body_or_params)
          end
      end

    case apply(Req, method, [url, req_opts]) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, atomize_keys(body)}

      {:ok,
       %Req.Response{status: 400, headers: resp_headers, body: %{"error" => "use_dpop_nonce"}}}
      when not retried_nonce ->
        handle_dpop_nonce_retry(method, pds_url, path, body_or_params, opts, resp_headers)

      {:ok, %Req.Response{status: status, body: body}} ->
        error = atomize_keys(body)

        Logger.warning(
          "Bluesky API request failed: #{method} #{path} -> #{status}: #{inspect(error)}"
        )

        {:error, {status, error}}

      {:error, reason} ->
        Logger.error("Bluesky API request error: #{method} #{path} -> #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_dpop_nonce_retry(method, pds_url, path, body_or_params, opts, resp_headers) do
    signing_key = opts[:signing_key]
    access_token = opts[:auth]

    case {signing_key, extract_dpop_nonce(resp_headers)} do
      {nil, _} ->
        Logger.warning("DPoP nonce required but no signing_key provided for retry")
        {:error, {400, %{error: :use_dpop_nonce, message: "No signing key for nonce retry"}}}

      {_, nil} ->
        Logger.warning("DPoP nonce required but no nonce in response headers")
        {:error, {400, %{error: :use_dpop_nonce, message: "No nonce in response"}}}

      {signing_key, nonce} ->
        Logger.debug("Retrying request with DPoP nonce")
        url = pds_url <> path
        public_key = derive_public_jwk(signing_key)

        {:ok, new_dpop_proof} =
          Mosslet.Bluesky.OAuth.create_dpop_proof(
            signing_key,
            public_key,
            String.upcase(to_string(method)),
            url,
            nonce: nonce,
            access_token: access_token
          )

        opts = Keyword.put(opts, :dpop_proof, new_dpop_proof)
        do_request(method, pds_url, path, body_or_params, opts, true)
    end
  end

  defp extract_dpop_nonce(headers) when is_map(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> nonce
      nonce when is_binary(nonce) -> nonce
      _ -> nil
    end
  end

  defp extract_dpop_nonce(headers) when is_list(headers) do
    case List.keyfind(headers, "dpop-nonce", 0) do
      {_, nonce} -> nonce
      nil -> nil
    end
  end

  defp extract_dpop_nonce(_), do: nil

  defp build_headers(opts) do
    content_type = opts[:content_type] || "application/json"
    headers = [{"content-type", content_type}]

    case {opts[:auth], opts[:dpop_proof]} do
      {nil, _} ->
        headers

      {token, nil} ->
        [{"authorization", "Bearer #{token}"} | headers]

      {token, dpop_proof} ->
        [{"authorization", "DPoP #{token}"}, {"dpop", dpop_proof} | headers]
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value
end
