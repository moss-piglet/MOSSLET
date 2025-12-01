defmodule MossletWeb.EditNotificationsLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok, assign_form(socket, socket.assigns.current_user)}
  end

  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={:edit_notifications} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Notification Settings
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Control your notification preferences for a peaceful experience.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Current Status Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class={[
                  "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden",
                  if(@current_user.is_subscribed_to_marketing_notifications,
                    do:
                      "bg-gradient-to-br from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-teal-900/30",
                    else:
                      "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700"
                  )
                ]}>
                  <.phx_icon
                    name={
                      if @current_user.is_subscribed_to_marketing_notifications,
                        do: "hero-bell",
                        else: "hero-bell-slash"
                    }
                    class={[
                      "h-4 w-4",
                      if(@current_user.is_subscribed_to_marketing_notifications,
                        do: "text-emerald-600 dark:text-emerald-400",
                        else: "text-slate-500 dark:text-slate-400"
                      )
                    ]}
                  />
                </div>
                <span>Calm Notifications</span>
                <span class={[
                  "inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium",
                  if(@current_user.is_subscribed_to_marketing_notifications,
                    do:
                      "bg-gradient-to-r from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600",
                    else:
                      "bg-gradient-to-r from-slate-100 to-slate-200 text-slate-800 dark:from-slate-700 dark:to-slate-600 dark:text-slate-200 border border-slate-300 dark:border-slate-600"
                  )
                ]}>
                  {if @current_user.is_subscribed_to_marketing_notifications,
                    do: "Enabled",
                    else: "Disabled"}
                </span>
              </div>
            </:title>

            <div class="space-y-6">
              <%!-- Current status explanation --%>
              <div class={[
                "p-4 rounded-lg border",
                if(@current_user.is_subscribed_to_marketing_notifications,
                  do:
                    "bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10 border-emerald-200 dark:border-emerald-700",
                  else:
                    "bg-gradient-to-br from-slate-50/50 to-slate-100/30 dark:from-slate-800/50 dark:to-slate-700/20 border-slate-200 dark:border-slate-700"
                )
              ]}>
                <div class="flex items-start gap-3">
                  <.phx_icon
                    name={
                      if @current_user.is_subscribed_to_marketing_notifications,
                        do: "hero-check-circle",
                        else: "hero-minus-circle"
                    }
                    class={[
                      "h-5 w-5 mt-0.5 flex-shrink-0",
                      if(@current_user.is_subscribed_to_marketing_notifications,
                        do: "text-emerald-600 dark:text-emerald-400",
                        else: "text-slate-500 dark:text-slate-400"
                      )
                    ]}
                  />
                  <div class="space-y-2">
                    <h3 class={[
                      "font-medium text-sm",
                      if(@current_user.is_subscribed_to_marketing_notifications,
                        do: "text-emerald-800 dark:text-emerald-200",
                        else: "text-slate-700 dark:text-slate-300"
                      )
                    ]}>
                      {if @current_user.is_subscribed_to_marketing_notifications,
                        do: "Calm Notifications Enabled",
                        else: "Notifications Disabled"}
                    </h3>
                    <p class={[
                      "text-sm leading-relaxed",
                      if(@current_user.is_subscribed_to_marketing_notifications,
                        do: "text-emerald-700 dark:text-emerald-300",
                        else: "text-slate-600 dark:text-slate-400"
                      )
                    ]}>
                      <span :if={@current_user.is_subscribed_to_marketing_notifications}>
                        You'll receive gentle, calm notifications that appear only when you're actively using MOSSLET. These won't interrupt you or pull your attention away from other activities.
                      </span>
                      <span :if={!@current_user.is_subscribed_to_marketing_notifications}>
                        You won't receive any calm notifications. You can always check your timeline and connections manually when you visit MOSSLET.
                      </span>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Notification Settings Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon name="hero-cog-6-tooth" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
                </div>
                Notification Preferences
              </div>
            </:title>

            <div class="space-y-6">
              <%!-- What notifications include --%>
              <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
                <h3 class="font-medium text-sm text-slate-900 dark:text-slate-100 mb-3">
                  What calm notifications include:
                </h3>
                <div class="space-y-2 text-sm text-slate-600 dark:text-slate-400">
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-user-plus"
                      class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                    />
                    <span>New connection requests and acceptances</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon name="hero-users" class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0" />
                    <span>Group invitations and activity updates</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-chat-bubble-left-right"
                      class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                    />
                    <span>Mentions and direct interactions</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon name="hero-bell" class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0" />
                    <span>Important account or security updates</span>
                  </div>
                </div>
              </div>

              <%!-- Form for updating notifications --%>
              <.form
                id="update_profile_form"
                for={@form}
                phx-change="update_profile"
                class="space-y-6"
              >
                <DesignSystem.liquid_checkbox
                  field={@form[:is_subscribed_to_marketing_notifications]}
                  label="Enable calm notifications"
                  help={
                    if @current_user.is_subscribed_to_marketing_notifications,
                      do:
                        "Disable to stop receiving gentle notifications when you're actively using MOSSLET.",
                      else:
                        "Enable to receive calm, non-intrusive notifications that only appear while you're using the app."
                  }
                />

                <DesignSystem.liquid_checkbox
                  field={@form[:is_subscribed_to_email_notifications]}
                  label="Enable email notifications"
                  help={
                    if @current_user.is_subscribed_to_email_notifications,
                      do:
                        "You will receive up to 1 email per day when friends share posts with you and you're offline.",
                      else:
                        "Enable to receive up to 1 daily email when friends share posts with you and you're not actively online."
                  }
                />
              </.form>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Email Notifications Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon name="hero-envelope" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
                </div>
                <div class="flex items-center gap-3">
                  <span>Email Notifications</span>
                  <span class={[
                    "inline-flex px-2.5 py-0.5 text-xs rounded-lg font-medium",
                    if(@current_user.is_subscribed_to_email_notifications,
                      do:
                        "bg-gradient-to-r from-emerald-100 to-teal-200 text-emerald-800 dark:from-emerald-800 dark:to-teal-700 dark:text-emerald-200 border border-emerald-300 dark:border-emerald-600",
                      else:
                        "bg-gradient-to-r from-slate-100 to-slate-200 text-slate-800 dark:from-slate-700 dark:to-slate-600 dark:text-slate-200 border border-slate-300 dark:border-slate-600"
                    )
                  ]}>
                    {if @current_user.is_subscribed_to_email_notifications,
                      do: "Enabled",
                      else: "Disabled"}
                  </span>
                </div>
              </div>
            </:title>

            <div class="space-y-4">
              <div class={[
                "p-4 rounded-lg border",
                if(@current_user.is_subscribed_to_email_notifications,
                  do:
                    "bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10 border-emerald-200 dark:border-emerald-700",
                  else:
                    "bg-gradient-to-br from-slate-50/50 to-slate-100/30 dark:from-slate-800/50 dark:to-slate-700/20 border-slate-200 dark:border-slate-700"
                )
              ]}>
                <div class="flex items-start gap-3">
                  <.phx_icon
                    name={
                      if @current_user.is_subscribed_to_email_notifications,
                        do: "hero-check-circle",
                        else: "hero-minus-circle"
                    }
                    class={[
                      "h-5 w-5 mt-0.5 flex-shrink-0",
                      if(@current_user.is_subscribed_to_email_notifications,
                        do: "text-emerald-600 dark:text-emerald-400",
                        else: "text-slate-500 dark:text-slate-400"
                      )
                    ]}
                  />
                  <div class="space-y-2">
                    <h3 class={[
                      "font-medium text-sm",
                      if(@current_user.is_subscribed_to_email_notifications,
                        do: "text-emerald-800 dark:text-emerald-200",
                        else: "text-slate-700 dark:text-slate-300"
                      )
                    ]}>
                      {if @current_user.is_subscribed_to_email_notifications,
                        do: "Email Notifications Enabled",
                        else: "Email Notifications Disabled"}
                    </h3>
                    <p class={[
                      "text-sm leading-relaxed",
                      if(@current_user.is_subscribed_to_email_notifications,
                        do: "text-emerald-700 dark:text-emerald-300",
                        else: "text-slate-600 dark:text-slate-400"
                      )
                    ]}>
                      <span :if={@current_user.is_subscribed_to_email_notifications}>
                        You will receive up to 1 email per day when friends share posts with you and you're not currently online. This gentle daily digest keeps you connected without overwhelming your inbox.
                      </span>
                      <span :if={!@current_user.is_subscribed_to_email_notifications}>
                        You won't receive any email notifications. You can always check your timeline and connections manually when you visit MOSSLET.
                      </span>
                    </p>
                  </div>
                </div>
              </div>

              <div class="bg-blue-100 dark:bg-blue-900/30 rounded-lg p-4 border border-blue-200 dark:border-blue-700">
                <h3 class="text-sm font-medium text-blue-800 dark:text-blue-200 mb-2">
                  What email notifications include:
                </h3>
                <div class="space-y-2 text-sm text-blue-700 dark:text-blue-300">
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-calendar-days"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>Maximum 1 email per day (calm by design)</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-power"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>Only sent when you're offline or not actively using MOSSLET</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-users"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>When friends share posts directly with you</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-shield-check"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>Privacy-first: No content details revealed, just notification counts</span>
                  </div>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Philosophy Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-purple-50/50 to-violet-50/30 dark:from-purple-900/20 dark:to-violet-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
                  <.phx_icon name="hero-heart" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
                </div>
                <span class="text-purple-800 dark:text-purple-200">Our Calm Philosophy</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-moon" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
                    <span class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                      No interruptions
                    </span>
                  </div>
                  <p class="text-sm text-purple-700 dark:text-purple-300 ml-6">
                    Calm notifications never interrupt you outside the app
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-calendar-days"
                      class="h-4 w-4 text-purple-600 dark:text-purple-400"
                    />
                    <span class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                      Daily email digest
                    </span>
                  </div>
                  <p class="text-sm text-purple-700 dark:text-purple-300 ml-6">
                    Maximum 1 email per day, never overwhelming your inbox
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-clock" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
                    <span class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                      Your time, your choice
                    </span>
                  </div>
                  <p class="text-sm text-purple-700 dark:text-purple-300 ml-6">
                    Check MOSSLET when it fits your schedule
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-shield-check"
                      class="h-4 w-4 text-purple-600 dark:text-purple-400"
                    />
                    <span class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                      Gentle presence
                    </span>
                  </div>
                  <p class="text-sm text-purple-700 dark:text-purple-300 ml-6">
                    Notifications appear softly, only while you're here
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-sparkles"
                      class="h-4 w-4 text-purple-600 dark:text-purple-400"
                    />
                    <span class="text-sm font-semibold text-purple-800 dark:text-purple-200">
                      Mindful design
                    </span>
                  </div>
                  <p class="text-sm text-purple-700 dark:text-purple-300 ml-6">
                    Built to enhance connection, not addiction
                  </p>
                </div>
              </div>

              <div class="pt-4 border-t border-purple-200 dark:border-purple-700">
                <p class="text-sm text-purple-700 dark:text-purple-300">
                  <span class="font-medium">Remember:</span>
                  MOSSLET calm notifications are designed to inform, not distract. They only exist within the app
                  and respect your digital wellness. Email notifications are limited to 1 per day and are privacy-first, never revealing poster details.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Essential Account Emails Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon name="hero-envelope" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
                </div>
                <span class="text-blue-800 dark:text-blue-200">Essential Account Emails</span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-blue-700 dark:text-blue-300 leading-relaxed">
                While MOSSLET never sends marketing emails or newsletters, you will receive
                <strong class="font-medium">essential security and account management emails</strong>
                that are necessary for your account's protection.
              </p>

              <div class="space-y-3">
                <h3 class="text-sm font-medium text-blue-800 dark:text-blue-200">
                  You'll receive emails for:
                </h3>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm text-blue-700 dark:text-blue-300">
                  <div class="flex items-start gap-2">
                    <.phx_icon name="hero-key" class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0" />
                    <span>Password reset requests</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-at-symbol"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>Email address change confirmations</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-shield-exclamation"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>Critical security alerts</span>
                  </div>
                  <div class="flex items-start gap-2">
                    <.phx_icon
                      name="hero-user-circle"
                      class="h-4 w-4 mt-0.5 text-blue-500 flex-shrink-0"
                    />
                    <span>Account verification emails</span>
                  </div>
                </div>
              </div>

              <div class="bg-blue-100 dark:bg-blue-900/30 rounded-lg p-3 border border-blue-200 dark:border-blue-700">
                <p class="text-sm text-blue-700 dark:text-blue-300">
                  <span class="font-medium">Important:</span>
                  These essential emails cannot be disabled as they are required for account security and functionality.
                  They are sent only when you take specific actions or when your account's security is at risk.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Technical Details Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-slate-50/50 to-slate-100/30 dark:from-slate-800/50 dark:to-slate-700/20">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100 dark:from-slate-700 dark:via-slate-600 dark:to-slate-700">
                  <.phx_icon
                    name="hero-information-circle"
                    class="h-4 w-4 text-slate-600 dark:text-slate-400"
                  />
                </div>
                <span class="text-slate-800 dark:text-slate-200">How It Works</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="text-sm text-slate-600 dark:text-slate-400 space-y-3">
                <p class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-computer-desktop"
                    class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                  />
                  <span>
                    <strong class="text-slate-900 dark:text-slate-100">In-app only:</strong>
                    Notifications appear as gentle indicators in your MOSSLET interface when you're actively using the service.
                  </span>
                </p>
                <p class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-eye-slash"
                    class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                  />
                  <span>
                    <strong class="text-slate-900 dark:text-slate-100">No tracking:</strong>
                    We don't track your browsing, send emails, or use any external notification services.
                  </span>
                </p>
                <p class="flex items-start gap-2">
                  <.phx_icon
                    name="hero-user-circle"
                    class="h-4 w-4 mt-0.5 text-slate-500 flex-shrink-0"
                  />
                  <span>
                    <strong class="text-slate-900 dark:text-slate-100">Your control:</strong>
                    You can enable or disable notifications at any time, and the change takes effect immediately.
                  </span>
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    case Accounts.update_user_notifications(socket.assigns.current_user, user_params) do
      {:ok, current_user} ->
        Accounts.user_lifecycle_action("after_update_profile", current_user)

        socket =
          socket
          |> put_flash(
            :success,
            gettext("Your notification preferences have been updated successfully.")
          )
          |> assign(current_user: current_user)
          |> assign_form(current_user)
          |> push_navigate(to: "/app/users/edit-notifications")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, gettext("Update failed. Please check the form for issues."))
          |> assign(form: to_form(changeset))
          |> push_navigate(to: "/app/users/edit-notifications")

        {:noreply, socket}
    end
  end

  defp assign_form(socket, user) do
    assign(socket, page_title: "Settings", form: to_form(User.notifications_changeset(user)))
  end
end
