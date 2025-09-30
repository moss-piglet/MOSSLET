defmodule MossletWeb.TimelineLive.BlockModalComponent do
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

  def handle_event("validate_block", %{"block" => _block_params}, socket) do
    # Basic validation can be added here if needed
    {:noreply, socket}
  end

  def handle_event("submit_block", %{"block" => block_params}, socket) do
    # Send the block data back to the parent LiveView
    send(self(), {:submit_block, block_params})
    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    # Send close event to parent LiveView
    send(self(), {:close_block_modal})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="block-modal-component">
      <%= if @show do %>
        <.liquid_modal
          id="block-user-modal"
          show={@show}
          on_cancel={JS.push("close_modal", target: @myself)}
          size="md"
        >
          <:title>
            <div class="flex items-center gap-3">
              <div class="p-2.5 rounded-xl bg-gradient-to-br from-rose-100 to-rose-100 dark:from-rose-900/30 dark:to-rose-900/30">
                <.phx_icon name="hero-no-symbol" class="h-5 w-5 text-rose-600 dark:text-rose-400" />
              </div>
              <div>
                <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                  Block {@user_name}
                </h3>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  They won't be able to interact with you
                </p>
              </div>
            </div>
          </:title>

          <div class="space-y-6">
            <.form
              for={@form_data}
              as={:block}
              phx-submit="submit_block"
              phx-change="validate_block"
              phx-target={@myself}
              id="block-form"
              class="space-y-6"
            >
              <input type="hidden" name="block[blocked_id]" value={@user_id} />

              <%!-- Block type selection --%>
              <div class="space-y-3">
                <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
                  What would you like to block?
                </label>
                <div class="space-y-2">
                  <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                    <input
                      type="radio"
                      name="block[block_type]"
                      value="full"
                      checked="checked"
                      class="mt-1 h-4 w-4 text-rose-600 focus:ring-rose-500 border-slate-300 dark:border-slate-600"
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">Everything</div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Block all posts, replies, and interactions from this user
                      </div>
                    </div>
                  </label>

                  <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                    <input
                      type="radio"
                      name="block[block_type]"
                      value="posts_only"
                      class="mt-1 h-4 w-4 text-rose-600 focus:ring-rose-500 border-slate-300 dark:border-slate-600"
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">Posts only</div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Hide their posts but allow replies to your content
                      </div>
                    </div>
                  </label>

                  <label class="relative flex items-start p-4 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-all duration-200">
                    <input
                      type="radio"
                      name="block[block_type]"
                      value="replies_only"
                      class="mt-1 h-4 w-4 text-rose-600 focus:ring-rose-500 border-slate-300 dark:border-slate-600"
                    />
                    <div class="ml-3">
                      <div class="font-medium text-slate-900 dark:text-slate-100">Replies only</div>
                      <div class="text-sm text-slate-600 dark:text-slate-400">
                        Block replies but still see their posts
                      </div>
                    </div>
                  </label>
                </div>
              </div>

              <%!-- Reason field --%>
              <div class="space-y-2">
                <label
                  for="block_reason"
                  class="block text-sm font-medium text-slate-900 dark:text-slate-100"
                >
                  Reason for blocking (optional)
                </label>
                <input
                  type="text"
                  name="block[reason]"
                  id="block_reason"
                  class="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-500 focus:ring-2 focus:ring-rose-500 focus:border-rose-500 transition-all duration-200"
                  placeholder="Why are you blocking this user?"
                  maxlength="200"
                />
              </div>

              <%!-- What happens notice --%>
              <div class="p-4 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700">
                <div class="flex gap-3">
                  <.phx_icon
                    name="hero-information-circle"
                    class="h-5 w-5 text-slate-600 dark:text-slate-400 flex-shrink-0 mt-0.5"
                  />
                  <div class="text-sm text-slate-700 dark:text-slate-300">
                    <p class="font-medium mb-1">What happens when you block someone:</p>
                    <ul class="text-slate-600 dark:text-slate-400 space-y-1">
                      <li>• They won't be notified that you blocked them</li>
                      <li>• You won't see their content in your timeline</li>
                      <li>• They won't be able to interact with your posts</li>
                      <li>• You can unblock them anytime from your settings</li>
                    </ul>
                  </div>
                </div>
              </div>

              <%!-- Action buttons --%>
              <div class="flex justify-end gap-3 pt-2">
                <.liquid_button
                  type="button"
                  variant="ghost"
                  color="slate"
                  phx-click="close_modal"
                  phx-target={@myself}
                >
                  Cancel
                </.liquid_button>
                <.liquid_button
                  type="submit"
                  color="rose"
                  icon="hero-no-symbol"
                >
                  Block User
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
