defmodule MossletWeb.UserOnMountHooks do
  @moduledoc """
  This module houses on_mount hooks used by live views.
  Docs: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1
  """
  use MossletWeb, :verified_routes

  use Gettext, backend: MossletWeb.Gettext
  import Phoenix.Component
  import Phoenix.LiveView

  alias Mosslet.Accounts
  alias Mosslet.Accounts.Scope

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = maybe_assign_scope(socket, session)
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user do
      if user.confirmed_at do
        {:cont, socket}
      else
        socket =
          put_flash(
            socket,
            :info,
            gettext(
              "You must confirm your account first, please check your email for a confirmation link or send a new one."
            )
          )

        {:halt, redirect(socket, to: ~p"/auth/confirm")}
      end
    else
      socket = put_flash(socket, :error, gettext("You must sign in to access this page."))
      {:halt, redirect(socket, to: ~p"/auth/sign_in")}
    end
  end

  def on_mount(:require_authenticated_user_not_confirmed, _params, session, socket) do
    socket = maybe_assign_scope(socket, session)
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user do
      {:cont, socket}
    else
      socket = put_flash(socket, :error, gettext("You must sign in to access this page."))
      {:halt, redirect(socket, to: ~p"/auth/sign_in")}
    end
  end

  def on_mount(:require_confirmed_user, _params, session, socket) do
    socket = maybe_assign_scope(socket, session)
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && user.confirmed_at do
      {:cont, socket}
    else
      socket =
        put_flash(socket, :error, gettext("You must confirm your email to access this page."))

      {:halt, redirect(socket, to: ~p"/auth/sign_in")}
    end
  end

  def on_mount(:require_admin_user, _params, session, socket) do
    socket = maybe_assign_scope(socket, session)
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && user.is_admin? do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end

  def on_mount(:maybe_assign_user, _params, session, socket) do
    {:cont, maybe_assign_scope(socket, session)}
  end

  @doc """
  Org-branded sign-in / onboarding accent (Task #240 / #243, Phase B).

  When the request arrives on an org's custom subdomain host
  (`acmebiz.mosslet.com`) AND that org currently has the live subdomain add-on
  (`Orgs.subdomain_live?/1`), assigns `:subdomain_org` + `:subdomain_org_live?`
  so pre-auth pages can render the org NAME as ACCENT chrome. ZK: the org name is
  Cloak-at-rest (server-decryptable), so it is safe to show server-side; the org
  LOGO is the ZK `org_key` blob and is NOT shown pre-auth (no key holder yet).

  Resolve-but-don't-serve: a resolved-but-unentitled org sets
  `subdomain_org_live? = false`, so no branding is shown. Never weakens auth — it
  only adds an accent; authentication still runs against Mosslet's backend.
  """
  def on_mount(:assign_subdomain_branding, _params, _session, socket) do
    org = resolve_subdomain_org(socket)
    live? = org != nil and Mosslet.Orgs.subdomain_live?(org)

    socket =
      socket
      |> assign(:subdomain_org, if(live?, do: org))
      |> assign(:subdomain_org_live?, live?)

    {:cont, socket}
  end

  # Apex "switch to your branded space" hint (Task #246).
  #
  # On a connected mount that is NOT being served on an org subdomain (i.e. the
  # apex), assigns `:branded_space_orgs` — the orgs the current user belongs to
  # whose custom subdomain is live (`Orgs.list_branded_orgs_for_user/1`). The
  # authenticated layout renders a dismissible banner pointing members at their
  # branded host so their session can live single-origin on the subdomain.
  #
  # On a subdomain host (or the disconnected first render) the list is empty, so
  # nothing is shown. Read-only and idempotent — it NEVER redirects (consistent
  # with the leave-as-is routing decision); it only offers a user-initiated link.
  # Must be wired AFTER the auth hooks so `current_scope` is present.
  def on_mount(:assign_branded_space_hint, _params, _session, socket) do
    orgs =
      if connected?(socket) and not on_any_subdomain?(socket) do
        user = socket.assigns[:current_scope] && socket.assigns.current_scope.user
        Mosslet.Orgs.list_branded_orgs_for_user(user)
      else
        []
      end

    {:cont, assign(socket, :branded_space_orgs, orgs)}
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = maybe_assign_scope(socket, session)
    scope = socket.assigns.current_scope

    totp_pending = session["user_totp_pending"]

    cond do
      scope && scope.user && scope.key && !totp_pending ->
        signed_in_path =
          if scope.user.is_onboarded? do
            ~p"/app"
          else
            ~p"/app/users/onboarding"
          end

        {:halt, redirect(socket, to: signed_in_path)}

      scope && scope.user && scope.key && totp_pending ->
        {:halt, redirect(socket, to: ~p"/app/users/totp")}

      scope && scope.user && !scope.key ->
        socket =
          put_flash(socket, :info, "Please enter your password to unlock your session.")

        {:halt, redirect(socket, to: ~p"/auth/unlock")}

      true ->
        {:cont, socket}
    end
  end

  defp maybe_assign_scope(socket, session) do
    socket
    |> assign_new(:current_user, fn ->
      get_user(session["user_token"])
    end)
    |> assign_new(:key, fn ->
      session["key"]
    end)
    |> then(fn socket ->
      assign_new(socket, :current_scope, fn ->
        Scope.for_user(socket.assigns.current_user, key: socket.assigns.key)
      end)
    end)
  end

  defp get_user(nil), do: nil
  defp get_user(token), do: Accounts.get_user_by_session_token(token)

  # Resolves the org for the current request host, mirroring the browser plug's
  # pure parser (single non-reserved label off the canonical host). Returns the
  # org or nil. No-op (nil) when no canonical host is configured (e.g. tests that
  # don't set it) or the host is the apex/foreign/reserved.
  defp resolve_subdomain_org(socket) do
    with %URI{host: host} when is_binary(host) <- socket.host_uri,
         base when is_binary(base) <- Application.get_env(:mosslet, :canonical_host),
         {:ok, label} <- MossletWeb.Plugs.OrgSubdomain.subdomain_label(host, base) do
      Mosslet.Orgs.get_org_by_subdomain(label)
    else
      _ -> nil
    end
  end

  # True when the current socket is being served on ANY org subdomain (a single
  # non-reserved label off the canonical host). Used to suppress the apex
  # "switch to your branded space" hint when the member is already on a branded
  # host. Safely false on the apex / when no canonical host is configured.
  defp on_any_subdomain?(socket) do
    with %URI{host: host} when is_binary(host) <- socket.host_uri,
         base when is_binary(base) <- Application.get_env(:mosslet, :canonical_host) do
      match?({:ok, _}, MossletWeb.Plugs.OrgSubdomain.subdomain_label(host, base))
    else
      _ -> false
    end
  end
end
