defmodule MossletWeb.OrgTransferActions do
  @moduledoc """
  Shared LiveView event-handling helpers for the org ownership-transfer handshake
  (Task #237), used VERBATIM by the Family and Business dashboards so the two
  plans stay in parity.

  Each helper performs the password-gated context call, flashes a friendly,
  ZK-safe message (ids only — never plaintext/keys/secrets), and re-runs the
  caller's data-refresh function (`assign_business_data/1` or
  `assign_family_data/1`) so the dashboard reflects the new state. They return the
  updated `socket`; the LiveView wraps it in `{:noreply, socket}`.
  """

  import Phoenix.Component, only: [to_form: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Orgs

  @doc """
  Initiates an ownership transfer from the current owner to the chosen member.
  `refresh` is the LiveView's `assign_*_data/1` function.
  """
  def do_initiate_transfer(socket, to_user_id, password, refresh)
      when is_function(refresh, 1) do
    org = socket.assigns.org
    current_user = socket.assigns.current_scope.user

    with true <- is_binary(to_user_id) and to_user_id != "",
         to_user when not is_nil(to_user) <- Mosslet.Accounts.get_user(to_user_id),
         {:ok, _transfer} <-
           Orgs.initiate_ownership_transfer(org, current_user, to_user, password) do
      socket
      |> assign(:transfer_modal_open, false)
      |> assign(:transfer_form, to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer))
      |> put_flash(:info, gettext("Ownership transfer sent. It completes once they accept."))
      |> refresh.()
    else
      false ->
        put_flash(socket, :error, gettext("Please choose a member to transfer ownership to."))

      nil ->
        put_flash(socket, :error, gettext("That member could not be found."))

      {:error, reason} ->
        socket
        |> reset_transfer_password()
        |> put_flash(:error, transfer_error_message(reason))
    end
  end

  @doc """
  Accepts a pending transfer (the proposed new owner). Uses the accepting user's
  `session_key` (`current_scope.key`) to ZK-safely reconcile the org's Stripe
  customer email in-session.
  """
  def do_accept_transfer(socket, transfer_id, password, refresh)
      when is_function(refresh, 1) do
    current_user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key

    with %Orgs.OwnershipTransfer{} = transfer <- Orgs.get_ownership_transfer(transfer_id),
         {:ok, _accepted} <-
           Orgs.accept_ownership_transfer(transfer, current_user, password, session_key) do
      socket
      |> reset_transfer_password()
      |> put_flash(:info, gettext("You are now the owner of this organization."))
      |> refresh.()
    else
      nil ->
        put_flash(socket, :error, gettext("That transfer is no longer available."))

      {:error, reason} ->
        socket
        |> reset_transfer_password()
        |> put_flash(:error, transfer_error_message(reason))
    end
  end

  @doc "Declines a pending transfer (the proposed new owner refuses)."
  def do_decline_transfer(socket, transfer_id, refresh) when is_function(refresh, 1) do
    current_user = socket.assigns.current_scope.user

    with %Orgs.OwnershipTransfer{} = transfer <- Orgs.get_ownership_transfer(transfer_id),
         {:ok, _declined} <- Orgs.decline_ownership_transfer(transfer, current_user) do
      socket
      |> put_flash(:info, gettext("Ownership transfer declined."))
      |> refresh.()
    else
      nil -> put_flash(socket, :error, gettext("That transfer is no longer available."))
      {:error, reason} -> put_flash(socket, :error, transfer_error_message(reason))
    end
  end

  @doc "Cancels a pending transfer (the original owner withdraws)."
  def do_cancel_transfer(socket, transfer_id, refresh) when is_function(refresh, 1) do
    current_user = socket.assigns.current_scope.user

    with %Orgs.OwnershipTransfer{} = transfer <- Orgs.get_ownership_transfer(transfer_id),
         {:ok, _cancelled} <- Orgs.cancel_ownership_transfer(transfer, current_user) do
      socket
      |> put_flash(:info, gettext("Ownership transfer cancelled."))
      |> refresh.()
    else
      nil -> put_flash(socket, :error, gettext("That transfer is no longer available."))
      {:error, reason} -> put_flash(socket, :error, transfer_error_message(reason))
    end
  end

  defp reset_transfer_password(socket) do
    assign(
      socket,
      :transfer_form,
      to_form(%{"password" => "", "to_user_id" => ""}, as: :transfer)
    )
  end

  defp transfer_error_message(:invalid_password),
    do: gettext("That password is incorrect. Please try again.")

  defp transfer_error_message(:not_owner),
    do: gettext("Only the organization's owner can transfer ownership.")

  defp transfer_error_message(:not_a_member),
    do: gettext("Ownership can only be transferred to a current member.")

  defp transfer_error_message(:single_member_org),
    do: gettext("Invite another member before transferring ownership.")

  defp transfer_error_message(:transfer_already_pending),
    do: gettext("A transfer is already pending for this organization.")

  defp transfer_error_message(:cannot_transfer_to_self),
    do: gettext("You can't transfer ownership to yourself.")

  defp transfer_error_message(:not_recipient),
    do: gettext("This transfer wasn't addressed to you.")

  defp transfer_error_message(:not_initiator),
    do: gettext("Only the member who started this transfer can cancel it.")

  defp transfer_error_message(:not_pending),
    do: gettext("This transfer is no longer pending.")

  defp transfer_error_message(_), do: gettext("Something went wrong. Please try again.")
end
