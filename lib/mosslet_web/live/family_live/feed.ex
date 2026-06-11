defmodule MossletWeb.FamilyLive.Feed do
  @moduledoc """
  Guardian's "Family" reading surface.

  Lists the managed members whose content the current guardian can read (active
  guardianships) and explains where that co-sealed content appears. Co-sealed
  posts/conversations already surface in the guardian's normal timeline and
  conversations because they hold a real `UserPost` / `UserConversation` row —
  this view keeps the guardianship relationship explicit and honest on both ends
  (see `docs/GUARDIANSHIP_DESIGN.md` §6.4).
  """
  use MossletWeb, :live_view

  alias Mosslet.Orgs

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    org = Orgs.get_org!(current_user, slug)
    membership = Orgs.get_membership!(current_user, slug)

    cond do
      org.type != :family ->
        {:ok,
         socket
         |> put_flash(:error, "Not a family organization")
         |> push_navigate(to: ~p"/app/family")}

      membership.role != :guardian ->
        {:ok,
         socket
         |> put_flash(:error, "Only guardians have a family reading feed.")
         |> push_navigate(to: ~p"/app/family/#{slug}")}

      true ->
        managed =
          membership
          |> Orgs.list_guardianships_for_guardian_membership()
          |> Enum.filter(&(&1.status == :active))
          |> Enum.map(fn g ->
            %{
              guardianship: g,
              managed_name: resolve_display_name(g.managed_membership.user, current_user, key)
            }
          end)

        {:ok,
         socket
         |> assign(:org, org)
         |> assign(:membership, membership)
         |> assign(:managed, managed)
         |> assign(:page_title, "#{org.name} — Family feed")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_page={:family}
      sidebar_current_page={:family}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 space-y-6">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/app/family/#{@org.slug}"}
            class="p-1.5 -ml-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
            aria-label="Back to family"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
              Family feed
            </h1>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Content shared with you as a guardian, readable with your own private key.
            </p>
          </div>
        </header>

        <div :if={@managed == []} class="text-center py-12">
          <p class="text-sm text-slate-500 dark:text-slate-400">
            No active guardianships yet. When a managed member accepts your guardianship, their
            posts and conversations will appear in your normal timeline and conversations.
          </p>
        </div>

        <ul :if={@managed != []} role="list" class="space-y-3">
          <li
            :for={item <- @managed}
            id={"managed-#{item.guardianship.id}"}
            class="rounded-2xl border border-teal-200/70 dark:border-teal-800/40 bg-teal-50/70 dark:bg-teal-900/15 p-4"
          >
            <div class="flex items-start gap-2.5">
              <.phx_icon name="hero-eye" class="size-5 text-teal-600 dark:text-teal-400 mt-0.5" />
              <div>
                <p class="text-sm font-semibold text-teal-900 dark:text-teal-100">
                  Shared with you as {item.managed_name}'s guardian
                </p>
                <p class="mt-1 text-xs text-teal-800/90 dark:text-teal-200/80">
                  {item.managed_name}'s posts and conversations are co-sealed for your key. They
                  appear in your
                  <.link navigate={~p"/app/timeline"} class="underline font-medium">timeline</.link>
                  and <.link navigate={~p"/app/conversations"} class="underline font-medium">conversations</.link>,
                  decrypted with your own private key. Mosslet's servers can't read them.
                </p>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </.layout>
    """
  end

  defp resolve_display_name(%{id: same_id}, %{id: same_id}, _key), do: "You"

  defp resolve_display_name(user, current_user, key) do
    case Mosslet.Accounts.get_user_connection_between_users(user.id, current_user.id) do
      %{} = uconn ->
        uconn = Mosslet.Repo.preload(uconn, :connection)
        get_decrypted_connection_name(uconn, current_user, key)

      _ ->
        "your family member"
    end
  end
end
