defmodule MossletWeb.OrgDeleteActions do
  @moduledoc """
  Shared LiveView event-handling helpers for owner-facing SAFE org deletion +
  true ZK teardown (Task #227), used VERBATIM by the Family and Business
  dashboards so the two plans stay in parity.

  The delete is high-friction and irreversible: the owner must type the org's
  name exactly AND re-enter their password. The authoritative DB teardown runs
  synchronously in `Orgs.delete_org_safely/2`; best-effort external side-effects
  (immediate Stripe cancel + customer delete) are offloaded to an Oban job.

  ZK-safe: helpers flash friendly, id-only messages — never plaintext, keys, or
  secrets. On success the LiveView navigates the (now ex-)owner away from the
  deleted org. They return the updated `socket`; the caller wraps `{:noreply, …}`.
  """

  import Phoenix.Component, only: [to_form: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_navigate: 2]
  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Orgs

  @doc "Opens the delete-confirmation modal with a fresh, empty form."
  def open_delete_org_modal(socket) do
    socket
    |> assign(:delete_modal_open, true)
    |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete_org))
  end

  @doc "Closes the delete-confirmation modal and resets the form."
  def close_delete_org_modal(socket) do
    socket
    |> assign(:delete_modal_open, false)
    |> assign(:delete_form, to_form(%{"password" => ""}, as: :delete_org))
  end

  @doc """
  Performs the safe deletion. `confirm_name` must match the org name exactly and
  `password` must re-authenticate the owner. `redirect_to` is where to send the
  ex-owner after a successful delete (the org no longer exists).
  """
  def do_delete_org(socket, confirm_name, password, redirect_to)
      when is_binary(redirect_to) do
    org = socket.assigns.org
    current_user = socket.assigns.current_scope.user

    cond do
      not name_matches?(confirm_name, org.name) ->
        socket
        |> reset_delete_password()
        |> put_flash(
          :error,
          gettext("That name didn't match. Type the organization's name exactly to confirm.")
        )

      true ->
        case Orgs.delete_org_safely(org, current_user, password) do
          {:ok, _summary} ->
            socket
            |> assign(:delete_modal_open, false)
            |> put_flash(
              :info,
              gettext("Organization deleted. Its plan, circles, and files are being torn down.")
            )
            |> push_navigate(to: redirect_to)

          {:error, reason} ->
            socket
            |> reset_delete_password()
            |> put_flash(:error, delete_error_message(reason))
        end
    end
  end

  defp name_matches?(confirm_name, org_name)
       when is_binary(confirm_name) and is_binary(org_name) do
    String.trim(confirm_name) == String.trim(org_name)
  end

  defp name_matches?(_, _), do: false

  defp reset_delete_password(socket) do
    assign(socket, :delete_form, to_form(%{"password" => ""}, as: :delete_org))
  end

  defp delete_error_message(:invalid_password),
    do: gettext("That password is incorrect. Please try again.")

  defp delete_error_message(:not_owner),
    do: gettext("Only the organization's owner can delete it.")

  defp delete_error_message(_),
    do: gettext("Something went wrong deleting the organization. Please try again.")
end
