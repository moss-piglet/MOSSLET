defmodule MossletWeb.OrgInviteLive do
  @moduledoc """
  Public, tokenized invite landing page (Task #222, EPIC #207).

  An invitee who clicks the link in an org-invitation email lands here — whether
  or not they are signed in, and whether or not they even have a MOSSLET account.
  We resolve the signed token to the invitation (+ org) and route intelligently:

    * invalid / expired / revoked token → friendly dead-end.
    * signed out + the invited email has NO account → "create your free account"
      CTA, carrying the token through the ZK registration funnel.
    * signed out + the invited email HAS an account → "sign in to accept" CTA,
      carrying the token through sign-in.
    * signed in + the invite matches this account → inline Accept / Decline.
    * signed in + unconfirmed account → "confirm your account first" notice.
    * signed in as a DIFFERENT account → honest masked notice (we never reveal the
      full invited address to a mismatched user).

  ZK-safe: the token is a `Phoenix.Token`-signed (NOT encrypted) wrapper of the
  invitation id — no key material or PII ever rides in the URL or email. Account
  existence is determined purely via blind-index hashes (`User.email_hash` /
  `Invitation.sent_to_hash`), never by decryption.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Orgs

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Invitation")
      |> assign(:token, token)
      |> resolve_invite()

    {:ok, socket}
  end

  # Resolves the token, then computes which branch to render. Kept in one place so
  # the accept/decline handlers can re-resolve after acting.
  defp resolve_invite(socket) do
    case Orgs.verify_invite_token(socket.assigns.token) do
      {:ok, invitation} ->
        socket
        |> assign(:invitation, invitation)
        |> assign(:org, invitation.org)
        |> assign(:state, invite_state(invitation, socket.assigns.current_scope))

      {:error, :expired} ->
        socket
        |> assign(:invitation, nil)
        |> assign(:org, nil)
        |> assign(:state, :expired)

      {:error, :invalid} ->
        socket
        |> assign(:invitation, nil)
        |> assign(:org, nil)
        |> assign(:state, :invalid)
    end
  end

  # Branch selection. current_scope is nil for signed-out visitors.
  defp invite_state(invitation, nil) do
    if Accounts.get_user_by_email(invitation.sent_to) do
      :signed_out_has_account
    else
      :signed_out_no_account
    end
  end

  defp invite_state(invitation, %{user: %{} = user}) do
    cond do
      user.email_hash != invitation.sent_to_hash -> :signed_in_mismatch
      is_nil(user.confirmed_at) -> :signed_in_unconfirmed
      true -> :signed_in_match
    end
  end

  defp invite_state(_invitation, _scope), do: :invalid

  @impl true
  def render(assigns) do
    ~H"""
    <.layout type="public" current_scope={@current_scope} current_page={:invite}>
      <div class="relative isolate min-h-[70vh] flex items-center justify-center px-4 py-16">
        <div
          class="absolute inset-0 -z-10 overflow-hidden pointer-events-none"
          aria-hidden="true"
        >
          <div class="absolute left-1/2 top-1/4 -translate-x-1/2 transform-gpu blur-3xl">
            <div class="aspect-square w-[32rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20 rounded-full">
            </div>
          </div>
        </div>

        <div class="w-full max-w-md">
          <div class="rounded-2xl bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm ring-1 ring-slate-200/60 dark:ring-slate-700/60 shadow-xl shadow-emerald-500/5 p-8 sm:p-10">
            {render_state(assigns)}
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  # --- Valid invite states ---------------------------------------------------

  defp render_state(%{state: :signed_in_match} = assigns) do
    ~H"""
    <div id="invite-accept" class="text-center">
      <.invite_badge type={@org.type} />
      <h1 class={heading_classes()}>{invite_headline(@org)}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {invite_subtext(@org)}
      </p>

      <div class="mt-8 grid grid-cols-1 sm:grid-cols-2 gap-3">
        <.phx_button
          phx-click="decline"
          phx-value-id={@invitation.id}
          data-confirm={gettext("Decline this invitation?")}
          class="bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200 border border-slate-300 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-600"
        >
          {gettext("Decline")}
        </.phx_button>
        <.phx_button phx-click="accept" phx-value-id={@invitation.id}>
          {gettext("Accept invitation")}
        </.phx_button>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :signed_in_unconfirmed} = assigns) do
    ~H"""
    <div id="invite-unconfirmed" class="text-center">
      <.invite_badge type={@org.type} />
      <h1 class={heading_classes()}>{invite_headline(@org)}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {gettext("Confirm your account to accept this invitation.")}
      </p>
      <div
        class="mt-6 rounded-xl border border-amber-300 bg-amber-50 dark:border-amber-700 dark:bg-amber-950/40 p-4 text-left text-amber-800 dark:text-amber-200"
        role="alert"
      >
        <p class="text-sm">
          {gettext(
            "Please confirm your account by clicking the link in the email we sent you. Once confirmed, your invitation will be waiting for you here."
          )}
        </p>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :signed_in_mismatch} = assigns) do
    ~H"""
    <div id="invite-mismatch" class="text-center">
      <.invite_badge type={@org.type} />
      <h1 class={heading_classes()}>{invite_headline(@org)}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {gettext("This invitation was sent to a different email address (%{masked}).",
          masked: mask_email(@invitation.sent_to)
        )}
      </p>
      <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
        {gettext("To accept it, sign out and sign in with that address.")}
      </p>
      <div class="mt-8">
        <.link
          href={~p"/auth/sign_out"}
          method="delete"
          class={primary_link_classes()}
        >
          <.phx_icon name="hero-arrow-right-start-on-rectangle" class="w-5 h-5" />
          {gettext("Sign out")}
        </.link>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :signed_out_has_account} = assigns) do
    ~H"""
    <div id="invite-sign-in" class="text-center">
      <.invite_badge type={@org.type} />
      <h1 class={heading_classes()}>{invite_headline(@org)}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {gettext("You already have a MOSSLET account — sign in to accept.")}
      </p>
      <div class="mt-8">
        <.link
          navigate={~p"/auth/sign_in?#{[invite_token: @token]}"}
          class={primary_link_classes()}
        >
          <.phx_icon name="hero-arrow-right-end-on-rectangle" class="w-5 h-5" />
          {gettext("Sign in to accept")}
        </.link>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :signed_out_no_account} = assigns) do
    ~H"""
    <div id="invite-register" class="text-center">
      <.invite_badge type={@org.type} />
      <h1 class={heading_classes()}>{invite_headline(@org)}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {register_subtext(@org)}
      </p>
      <div class="mt-8">
        <.link
          navigate={~p"/auth/register?#{[plan: register_plan(@org), invite_token: @token]}"}
          class={primary_link_classes()}
        >
          <.phx_icon name="hero-user-plus" class="w-5 h-5" />
          {gettext("Create your free account")}
        </.link>
      </div>
      <p class="mt-6 text-sm text-slate-500 dark:text-slate-400">
        {gettext("Already have a MOSSLET account?")}
        <.link
          navigate={~p"/auth/sign_in?#{[invite_token: @token]}"}
          class="font-medium text-emerald-600 hover:text-emerald-700 dark:text-emerald-400"
        >
          {gettext("Sign in")}
        </.link>
      </p>
    </div>
    """
  end

  # --- Dead-end states -------------------------------------------------------

  defp render_state(%{state: :expired} = assigns) do
    ~H"""
    <div id="invite-expired" class="text-center">
      <div class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-300">
        <.phx_icon name="hero-clock" class="w-7 h-7" />
      </div>
      <h1 class={heading_classes()}>{gettext("This invitation link has expired")}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {gettext(
          "Invitation links are valid for 7 days. Ask whoever invited you to send a fresh invitation — it only takes a moment."
        )}
      </p>
      <div class="mt-8">
        <.link navigate={~p"/"} class={secondary_link_classes()}>
          {gettext("Back to home")}
        </.link>
      </div>
    </div>
    """
  end

  defp render_state(%{state: :invalid} = assigns) do
    ~H"""
    <div id="invite-invalid" class="text-center">
      <div class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-300">
        <.phx_icon name="hero-x-mark" class="w-7 h-7" />
      </div>
      <h1 class={heading_classes()}>{gettext("This invitation is no longer valid")}</h1>
      <p class="mt-3 text-slate-600 dark:text-slate-300">
        {gettext(
          "The link may be incorrect, or the invitation may have already been accepted or revoked. If you think this is a mistake, ask whoever invited you to resend it."
        )}
      </p>
      <div class="mt-8">
        <.link navigate={~p"/"} class={secondary_link_classes()}>
          {gettext("Back to home")}
        </.link>
      </div>
    </div>
    """
  end

  # --- Shared bits -----------------------------------------------------------

  attr :type, :atom, required: true

  defp invite_badge(assigns) do
    ~H"""
    <div class="mx-auto mb-4 inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30">
      <.phx_icon
        name={if @type == :family, do: "hero-home", else: "hero-building-office-2"}
        class="w-4 h-4 text-emerald-600 dark:text-emerald-400"
      />
      <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
        {if @type == :family, do: gettext("Family invitation"), else: gettext("Team invitation")}
      </span>
    </div>
    """
  end

  @impl true
  def handle_event("accept", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    membership = Orgs.accept_invitation!(user, id)

    Mosslet.Logs.log("orgs.accept_invitation", %{
      user: user,
      org_id: membership.org_id,
      metadata: %{membership_id: membership.id}
    })

    {:noreply,
     socket
     |> put_flash(:success, gettext("Invitation accepted — welcome aboard!"))
     |> push_navigate(to: org_path(membership.org))}
  end

  @impl true
  def handle_event("decline", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    invitation = Orgs.reject_invitation!(user, id)

    Mosslet.Logs.log("orgs.reject_invitation", %{
      user: user,
      org_id: invitation.org_id
    })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Invitation declined."))
     |> push_navigate(to: ~p"/app")}
  end

  defp org_path(%{type: :family, slug: slug}), do: ~p"/app/family/#{slug}"
  defp org_path(%{slug: slug}), do: ~p"/app/business/#{slug}"

  # Family/Business copy ------------------------------------------------------

  defp invite_headline(%{type: :family, name: name}),
    do: gettext("Join the %{name} family on MOSSLET", name: name)

  defp invite_headline(%{name: name}),
    do: gettext("Join %{name} on MOSSLET", name: name)

  defp invite_subtext(%{type: :family}),
    do:
      gettext(
        "A calm, private space to stay close with the people who matter — no ads, no tracking, no surveillance."
      )

  defp invite_subtext(_org),
    do:
      gettext(
        "A private space where your team collaborates without the stress and tracking of traditional platforms."
      )

  defp register_subtext(%{type: :family, name: name}),
    do:
      gettext("Create your free account to join the %{name} family. It only takes a minute.",
        name: name
      )

  defp register_subtext(%{name: name}),
    do: gettext("Create your free account to join %{name}. It only takes a minute.", name: name)

  defp register_plan(%{type: :family}), do: "family"
  defp register_plan(%{type: :business}), do: "business"
  defp register_plan(_), do: "personal"

  # Masks an email for display to a MISMATCHED signed-in user so we never reveal
  # the full invited address. e.g. "alice@example.com" -> "a•••@e•••.com".
  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] ->
        mask_part(local) <> "@" <> mask_domain(domain)

      _ ->
        "•••"
    end
  end

  defp mask_email(_), do: "•••"

  defp mask_part(<<first::utf8, _rest::binary>>), do: <<first::utf8>> <> "•••"
  defp mask_part(_), do: "•••"

  defp mask_domain(domain) do
    case String.split(domain, ".") do
      [host | rest] when rest != [] ->
        mask_part(host) <> "." <> Enum.join(rest, ".")

      _ ->
        mask_part(domain)
    end
  end

  # Styling helpers -----------------------------------------------------------

  defp heading_classes do
    [
      "mt-2 text-2xl sm:text-3xl font-bold tracking-tight leading-tight",
      "bg-gradient-to-r from-teal-500 to-emerald-500",
      "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
      "bg-clip-text text-transparent"
    ]
  end

  defp primary_link_classes do
    [
      "group relative inline-flex w-full justify-center items-center gap-3",
      "rounded-xl py-4 px-6 text-base font-semibold",
      "bg-gradient-to-r from-teal-500 to-emerald-500 hover:from-teal-600 hover:to-emerald-600",
      "text-white shadow-lg shadow-emerald-500/25",
      "transition-all duration-200 ease-out transform-gpu hover:scale-[1.02] active:scale-[0.98]",
      "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2 dark:focus:ring-offset-slate-800"
    ]
  end

  defp secondary_link_classes do
    [
      "inline-flex items-center gap-2 text-sm font-medium",
      "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
      "transition-colors duration-200"
    ]
  end
end
