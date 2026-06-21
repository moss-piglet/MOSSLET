defmodule MossletWeb.UserHomeLive.ProfileViewModel do
  @moduledoc """
  View-model for `MossletWeb.UserHomeLive` (the user profile page).

  Profile rendering forks on *who is viewing whom*: the owner sees their own
  profile, a connection sees a `:connections`-visibility profile, and anyone
  sees a `:public` profile. Each mode resolves the displayed name/username/email
  and the profile detail fields (about/website/alternate email) through a
  different zero-knowledge path:

    * `:own`        — server fast-path decrypt of identity; profile detail fields
                      are sealed for browser-side decryption (true ZK).
    * `:connections`— identity + detail fields sealed with the viewer's
                      per-connection key for browser-side decryption (true ZK).
    * `:public`     — identity + detail fields decrypted server-side (public).

  This module concentrates that decision logic (previously two inline `cond`
  blocks in `mount/3`) into a single, testable struct so the LiveView and its
  components can read from one consistent shape. It performs **no** additional
  decryption beyond what `MossletWeb.Helpers.decrypt_profile_fields/4` and
  `resolve_decrypted_field/2` already did — the ZK invariants are unchanged.
  """

  alias MossletWeb.Helpers

  @typedoc """
  Which render variant applies, derived from `{owner?, profile.visibility}`.

  `:denied` is retained for completeness; in practice the
  `:maybe_ensure_private_profile` on_mount halts before a denied profile reaches
  the LiveView render.
  """
  @type access :: :own | :connections | :public | :denied

  @type identity :: %{name: String.t() | nil, username: String.t() | nil, email: String.t() | nil}

  @type t :: %__MODULE__{
          access: access(),
          owner?: boolean(),
          visibility: atom(),
          fields: map() | nil,
          identity: identity(),
          show_name?: boolean(),
          show_email?: boolean(),
          show_avatar?: boolean()
        }

  defstruct access: :denied,
            owner?: false,
            visibility: nil,
            fields: nil,
            identity: %{name: nil, username: nil, email: nil},
            show_name?: false,
            show_email?: false,
            show_avatar?: false

  @doc """
  Builds the profile view-model.

    * `profile_user` — the user whose profile is being viewed.
    * `current_user` — the viewing (session) user.
    * `key`          — the viewer's session key.
    * `user_connection` — the confirmed connection between the two users, or
      `nil` (always `nil` for the owner / unconnected viewers).
  """
  @spec build(
          profile_user :: struct(),
          current_user :: struct(),
          key :: binary(),
          user_connection :: struct() | nil
        ) :: t()
  def build(profile_user, current_user, key, user_connection) do
    owner? = current_user.id === profile_user.id
    profile = profile_user.connection.profile
    visibility = profile_user.visibility

    access = access(owner?, visibility, user_connection)
    fields = decrypt_fields(access, profile_user, current_user, key, user_connection)
    identity = identity(access, current_user, fields)

    %__MODULE__{
      access: access,
      owner?: owner?,
      visibility: visibility,
      fields: fields,
      identity: identity,
      show_name?: profile_flag(profile, :show_name?),
      show_email?: profile_flag(profile, :show_email?),
      show_avatar?: profile_flag(profile, :show_avatar?)
    }
  end

  # --- access mode -----------------------------------------------------------

  defp access(true, _visibility, _user_connection), do: :own

  defp access(false, :connections, user_connection) when not is_nil(user_connection),
    do: :connections

  defp access(false, :public, _user_connection), do: :public
  defp access(false, _visibility, _user_connection), do: :denied

  # --- profile detail fields (about / website / alternate email + identity) --
  #
  # Mirrors the original mount `cond`: each viewing mode delegates to
  # `decrypt_profile_fields/4` with the appropriate `:viewing` option (and the
  # per-connection key for connections).

  defp decrypt_fields(:own, _profile_user, current_user, key, _user_connection) do
    Helpers.decrypt_profile_fields(
      current_user.connection.profile,
      current_user,
      key,
      viewing: :own,
      connection: current_user.connection
    )
  end

  defp decrypt_fields(:connections, profile_user, current_user, key, user_connection) do
    Helpers.decrypt_profile_fields(
      profile_user.connection.profile,
      current_user,
      key,
      viewing: :connection,
      uconn_key: user_connection.key,
      connection: profile_user.connection
    )
  end

  defp decrypt_fields(:public, profile_user, current_user, key, _user_connection) do
    Helpers.decrypt_profile_fields(
      profile_user.connection.profile,
      current_user,
      key,
      viewing: :public,
      connection: profile_user.connection
    )
  end

  defp decrypt_fields(:denied, _profile_user, _current_user, _key, _user_connection), do: nil

  # --- displayed identity (name / username / email) --------------------------
  #
  # For the owner, use the `resolve_decrypted_field/2` fast path; otherwise read
  # the identity fields surfaced by `decrypt_profile_fields/4`.

  defp identity(:own, current_user, _fields) do
    %{
      name: Helpers.resolve_decrypted_field(current_user, :name),
      username: Helpers.resolve_decrypted_field(current_user, :username),
      email: Helpers.resolve_decrypted_field(current_user, :email)
    }
  end

  defp identity(_access, _current_user, fields) when is_map(fields) do
    %{name: fields[:name], username: fields[:username], email: fields[:email]}
  end

  defp identity(_access, _current_user, _fields) do
    %{name: nil, username: nil, email: nil}
  end

  defp profile_flag(nil, _flag), do: false
  defp profile_flag(profile, flag), do: !!Map.get(profile, flag)
end
