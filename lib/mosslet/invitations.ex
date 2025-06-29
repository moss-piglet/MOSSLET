defmodule Mosslet.Invitations do
  @moduledoc """
  The Invitations context.

  Note: We currently
  do not persist invites to the database,
  and use Ecto changesets for change tracking
  on virtual fields before sending an email.
  """

  import Ecto.Query, warn: false

  alias Mosslet.Invitations.Invite

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking invite changes.

  ## Examples

      iex> change_invitation(invite)
      %Ecto.Changeset{data: %Invite{}}

  """
  def change_invitation(%Invite{} = invite, attrs \\ %{}) do
    Invite.changeset(invite, attrs)
  end
end
