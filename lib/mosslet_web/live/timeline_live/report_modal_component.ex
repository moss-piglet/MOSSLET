defmodule MossletWeb.TimelineLive.ReportModalComponent do
  use MossletWeb, :live_component

  import MossletWeb.CoreComponents, only: [phx_input: 1, phx_icon: 1]
  import MossletWeb.DesignSystem, only: [liquid_button: 1, liquid_modal: 1]

  alias Phoenix.LiveView.JS

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form_data, %{})}
  end

  def handle_event("validate_report", %{"report" => _report_params}, socket) do
    # Basic validation can be added here if needed
    {:noreply, socket}
  end

  def handle_event("submit_report", %{"report" => report_params}, socket) do
    # Send the report data back to the parent LiveView
    send(self(), {:submit_report, report_params})
    {:noreply, socket |> push_event("restore-body-scroll", %{})}
  end

  def handle_event("close_modal", _params, socket) do
    # Send close event to parent LiveView
    send(self(), {:close_report_modal, %{}})
    {:noreply, assign(socket, :show, false)}
  end

  def render(assigns) do
    ~H"""
    <div
      id="report-modal-component-container"
      class="report-modal-component"
      phx-hook="RestoreBodyScroll"
    >
      <%= if @show do %>
        <.liquid_modal
          id={"report-post-modal-#{@post_id}"}
          show={@show}
          on_cancel={JS.push("close_report_modal", target: "#timeline-container")}
          size="lg"
        >
          <:title>
            <div class="flex items-center gap-3">
              <div class="p-2.5 rounded-xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30">
                <.phx_icon name="hero-flag" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
              </div>
              <div>
                <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                  Report this {if Map.get(assigns.report_reply_context, :reply_id),
                    do: "reply",
                    else: "post"}
                </h3>
                <p class="text-sm text-amber-700 dark:text-amber-400">
                  Help us keep the community safe
                </p>
              </div>
            </div>
          </:title>

          <div class="space-y-6">
            <.form
              for={@form_data}
              as={:report}
              phx-submit="submit_report"
              phx-change="validate_report"
              phx-target={@myself}
              id={"report-form-#{@post_id}"}
              class="space-y-6"
            >
              <.phx_input type="hidden" name="report[post_id]" value={@post_id} />
              <.phx_input type="hidden" name="report[reported_user_id]" value={@reported_user_id} />
              <.phx_input
                :if={Map.get(assigns.report_reply_context, :reply_id)}
                type="hidden"
                name="report[reply_id]"
                value={Map.get(assigns.report_reply_context, :reply_id)}
              />

              <%!-- Report type selection --%>
              <div class="space-y-3">
                <label class="block text-sm font-medium text-amber-800 dark:text-amber-300">
                  What's the issue?
                </label>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <label class="relative flex items-start p-4 border border-amber-200 dark:border-amber-700/50 rounded-xl hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[report_type]"
                      value="harassment"
                      class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                      required
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">Harassment</div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Threats, bullying, or abuse
                      </div>
                    </div>
                  </label>

                  <label class="relative flex items-start p-4 border border-amber-200 dark:border-amber-700/50 rounded-xl hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[report_type]"
                      value="spam"
                      class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                      required
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">Spam</div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Unwanted or repetitive content
                      </div>
                    </div>
                  </label>

                  <label class="relative flex items-start p-4 border border-amber-200 dark:border-amber-700/50 rounded-xl hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[report_type]"
                      value="content"
                      class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                      required
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">
                        Inappropriate Content
                      </div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Violates community guidelines
                      </div>
                    </div>
                  </label>

                  <label class="relative flex items-start p-4 border border-amber-200 dark:border-amber-700/50 rounded-xl hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[report_type]"
                      value="other"
                      class="mt-1 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                      required
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">Other</div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Something else
                      </div>
                    </div>
                  </label>
                </div>
              </div>

              <%!-- Severity selection --%>
              <div class="space-y-3">
                <label class="block text-sm font-medium text-amber-800 dark:text-amber-300">
                  How serious is this issue?
                </label>
                <div class="flex flex-wrap gap-2">
                  <label class="flex items-center px-4 py-2 border border-amber-200 dark:border-amber-700/50 rounded-full hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[severity]"
                      value="low"
                      class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                      required
                    />
                    <span class="text-sm text-slate-700 dark:text-slate-300">Minor</span>
                  </label>
                  <label class="flex items-center px-4 py-2 border border-amber-200 dark:border-amber-700/50 rounded-full hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[severity]"
                      value="medium"
                      class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                    />
                    <span class="text-sm text-slate-700 dark:text-slate-300">Moderate</span>
                  </label>
                  <label class="flex items-center px-4 py-2 border border-amber-200 dark:border-amber-700/50 rounded-full hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[severity]"
                      value="high"
                      class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                    />
                    <span class="text-sm text-slate-700 dark:text-slate-300">Serious</span>
                  </label>
                  <label class="flex items-center px-4 py-2 border border-amber-200 dark:border-amber-700/50 rounded-full hover:bg-amber-50 dark:hover:bg-amber-900/20 cursor-pointer transition-all duration-200 hover:border-amber-300 dark:hover:border-amber-600">
                    <input
                      type="radio"
                      name="report[severity]"
                      value="critical"
                      class="mr-2 h-4 w-4 text-amber-600 focus:ring-amber-500 border-amber-300 dark:border-amber-600"
                    />
                    <span class="text-sm text-slate-700 dark:text-slate-300">Critical</span>
                  </label>
                </div>
              </div>

              <%!-- Reason field --%>
              <div class="space-y-2">
                <label
                  for="report_reason"
                  class="block text-sm font-medium text-amber-800 dark:text-amber-300"
                >
                  Brief reason
                </label>
                <input
                  type="text"
                  name="report[reason]"
                  id={"report_reason_#{@post_id}"}
                  class="w-full px-4 py-3 border border-amber-300 dark:border-amber-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-200"
                  placeholder={"Why are you reporting this #{if Map.get(assigns.report_reply_context, :reply_id), do: "reply", else: "post"}?"}
                  maxlength="100"
                  required
                />
              </div>

              <%!-- Details field --%>
              <div class="space-y-2">
                <label
                  for="report_details"
                  class="block text-sm font-medium text-amber-800 dark:text-amber-300"
                >
                  Additional details (optional)
                </label>
                <textarea
                  name="report[details]"
                  id={"report_details_#{@post_id}"}
                  rows="3"
                  class="w-full px-4 py-3 border border-amber-300 dark:border-amber-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-200 resize-none"
                  placeholder={"Provide any additional context that might help our moderation team understand this #{if Map.get(assigns.report_reply_context, :reply_id), do: "reply", else: "post"}..."}
                  maxlength="1000"
                ></textarea>
              </div>

              <%!-- Enhanced privacy and transparency notice --%>
              <div class="space-y-4">
                <%!-- What admins can see --%>
                <div class="p-4 bg-teal-50 dark:bg-teal-900/20 rounded-xl border border-teal-200 dark:border-teal-700/50">
                  <div class="flex gap-3">
                    <.phx_icon
                      name="hero-eye"
                      class="h-5 w-5 text-teal-600 dark:text-teal-400 flex-shrink-0 mt-0.5"
                    />
                    <div class="text-sm text-teal-800 dark:text-teal-200">
                      <p class="font-medium mb-2">How moderation works:</p>
                      <ul class="space-y-1 list-disc text-teal-700 dark:text-teal-300 text-xs leading-relaxed">
                        <li>Your reason and context are reviewed by our moderation team</li>
                        <li>Decisions are made using pattern recognition and report metadata</li>
                        <li>This protects both community members and our moderation team</li>
                      </ul>
                    </div>
                  </div>
                </div>

                <%!-- What's protected --%>
                <div class="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700">
                  <div class="flex gap-3">
                    <.phx_icon
                      name="hero-shield-check"
                      class="h-5 w-5 text-slate-600 dark:text-slate-400 flex-shrink-0 mt-0.5"
                    />
                    <div class="text-sm text-slate-700 dark:text-slate-300">
                      <p class="font-medium mb-2">Your privacy is protected:</p>
                      <ul class="space-y-1 list-disc text-slate-600 dark:text-slate-400 text-xs leading-relaxed">
                        <li>The reported user won't know who submitted this report</li>
                        <li>Your report details are encrypted for moderator access only</li>
                        <li>
                          {if Map.get(assigns.report_reply_context, :reply_id),
                            do: "Reply",
                            else: "Post"} content remains separately encrypted and protected
                        </li>
                        <li>Pattern analysis helps prevent false reporting abuse</li>
                        <li>All moderation decisions are logged and auditable</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Action buttons --%>
              <div class="flex justify-end gap-3 pt-2">
                <.liquid_button
                  type="button"
                  variant="ghost"
                  color="slate"
                  phx-click={JS.exec("data-cancel", to: "#report-post-modal-#{@post_id}")}
                >
                  Cancel
                </.liquid_button>
                <.liquid_button
                  type="submit"
                  color="amber"
                  icon="hero-flag"
                >
                  Submit Report
                </.liquid_button>
              </div>
            </.form>
          </div>
        </.liquid_modal>
      <% end %>
    </div>
    """
  end
end
