defmodule Mosslet.Accounts.Scope do
  @moduledoc """
  Defines the scope for authenticated resources.

  The scope contains the authenticated user and their encryption key,
  tying resources to specific users (and eventually families/organizations).

  ## Fields

    * `:user` - The authenticated user
    * `:key` - The user's decryption key (from password unlock)

  Future fields (not yet implemented):
    * `:family` - The family account
    * `:family_key` - Key for shared family content
    * `:org` - The organization
    * `:org_key` - Key for shared org content

  ## Security

  The scope lives in socket assigns (memory) during a request. The encryption
  key originates from the encrypted session cookie - this struct does not
  change the security model, only how we organize the data.

  ## Usage

  In LiveViews and controllers, access via `@current_scope`:

      @current_scope.user
      @current_scope.key

  In context functions, pattern match:

      def list_posts(%Scope{user: user, key: key}) do
        # user-scoped query with decryption capability
      end

  ## Migration

  During migration, both `@current_user`/`@key` and `@current_scope` are
  available. New code should use `@current_scope`.
  """

  alias Mosslet.Accounts.User

  @type t :: %__MODULE__{
          user: User.t() | nil,
          key: binary() | nil
        }

  defstruct user: nil, key: nil

  @doc """
  Creates a scope for the given user.

  ## Options

    * `:key` - The user's decryption key

  Returns nil if no user is given.
  """
  def for_user(user, opts \\ [])

  def for_user(%User{} = user, opts) do
    %__MODULE__{
      user: user,
      key: Keyword.get(opts, :key)
    }
  end

  def for_user(nil, _opts), do: nil

  @doc """
  Returns the user's ID from the scope, or nil.
  """
  def user_id(%__MODULE__{user: %User{id: id}}), do: id
  def user_id(_), do: nil

  @doc """
  Returns true if the scope has a valid encryption key.
  """
  def has_key?(%__MODULE__{key: key}) when is_binary(key) and byte_size(key) > 0, do: true
  def has_key?(_), do: false
end
