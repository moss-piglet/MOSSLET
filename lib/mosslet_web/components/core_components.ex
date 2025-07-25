defmodule MossletWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At the first glance, this module may seem daunting, but its goal is
  to provide some core building blocks in your application, such as modals,
  tables, and forms. The components are mostly markup and well documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes
  use PetalComponents

  use Gettext, backend: MossletWeb.Gettext
  import MossletWeb.Helpers

  import MossletWeb.ColorSchemeSwitch
  import MossletWeb.Helpers
  import MossletWeb.PublicLayout
  import MossletWeb.SidebarLayout
  import MossletWeb.StackedLayout

  alias Phoenix.LiveView.JS

  @doc """
  Renders the local time for a struct with
  the relative formatting.
  """
  attr :at, :any, required: true
  attr :id, :any, required: true

  def local_time_ago(assigns) do
    ~H"""
    <time phx-hook="LocalTimeAgo" id={"time-#{@id}-ago"} class="hidden">{@at}</time>
    """
  end

  @doc """
  Renders the local time for a struct with
  the full formatting.
  """
  attr :at, :any, required: true
  attr :id, :any, required: true

  def local_time_full(assigns) do
    ~H"""
    <time phx-hook="LocalTimeFull" id={"time-#{@id}-full"} class="hidden">{@at}</time>
    """
  end

  @doc """
  Renders the local time for a struct with
  the medium formatting.
  """
  attr :at, :any, required: true
  attr :id, :any, required: true

  def local_time_med(assigns) do
    ~H"""
    <time phx-hook="LocalTimeMed" id={"time-#{@id}-med"} class="hidden">{@at}</time>
    """
  end

  @doc """
  Renders the current local time.
  """
  attr :id, :any, required: true

  def local_time_now(assigns) do
    ~H"""
    <time phx-hook="LocalTimeNow" id={"now-#{@id}"} class="hidden"></time>
    """
  end

  @doc """
  Renders the current local time in medium format.
  """
  attr :id, :any, required: true

  def local_time_now_med(assigns) do
    ~H"""
    <time phx-hook="LocalTimeNowMed" id={"now-#{@id}-med"} class="hidden"></time>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/app/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :close_icon?, :boolean, default: false
  attr :class, :string, default: nil, doc: "optional string of css classes to apply to the modal"

  attr :on_click_away, :atom,
    default: :close,
    doc:
      "The behavior to perform when a mouse click happens outside the modal. Defaults to close. Set to `:none` to keep open"

  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def phx_modal(assigns) do
    click_away =
      case assigns.on_click_away do
        :close -> JS.exec("data-cancel", to: "##{assigns.id}")
        _other_or_none -> %JS{}
      end

    assigns = assign(assigns, :click_away, click_away)

    ~H"""
    <div
      id={@id}
      phx-mounted={@show && phx_show_modal(@id)}
      phx-remove={phx_hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-background-50/90 dark:bg-zinc-950/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 z-10 w-screen pl-2 pr-6 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="phx-modal">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={%JS{}}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white dark:bg-gray-800 shadow-lg ring-1 transition overflow-visible"
            >
              <div class="absolute top-6 right-5">
                <button
                  id={"close-button-#{@id}"}
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 group"
                  data-tippy-content="Close"
                  phx-hook="TippyHook"
                  aria-label={gettext("close")}
                >
                  <.icon
                    name="hero-x-circle"
                    class="size-8 text-gray-500 dark:text-gray-400 group-hover:text-gray-400 dark:group-hover:text-gray-300"
                  />
                </button>
              </div>
              <div id={"#{@id}-content"} class="phx-modal-content">
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def carousel(assigns) do
    ~H"""
    <script src="https://unpkg.com/smoothscroll-polyfill@0.4.4/dist/smoothscroll.js">
    </script>

    <div
      x-data="{
        skip: 1,
        atBeginning: false,
        atEnd: false,
        next() {
            this.to((current, offset) => current + (offset * this.skip))
        },
        prev() {
            this.to((current, offset) => current - (offset * this.skip))
        },
        to(strategy) {
            let slider = this.$refs.slider
            let current = slider.scrollLeft
            let offset = slider.firstElementChild.getBoundingClientRect().width
            slider.scrollTo({ left: strategy(current, offset), behavior: 'smooth' })
        },
        focusableWhenVisible: {
            'x-intersect:enter'() {
                this.$el.removeAttribute('tabindex')
            },
            'x-intersect:leave'() {
                this.$el.setAttribute('tabindex', '-1')
            },
        },
        disableNextAndPreviousButtons: {
            'x-intersect:enter.threshold.05'() {
                let slideEls = this.$el.parentElement.children

                // If this is the first slide.
                if (slideEls[0] === this.$el) {
                    this.atBeginning = true
                // If this is the last slide.
                } else if (slideEls[slideEls.length-1] === this.$el) {
                    this.atEnd = true
                }
            },
            'x-intersect:leave.threshold.05'() {
                let slideEls = this.$el.parentElement.children

                // If this is the first slide.
                if (slideEls[0] === this.$el) {
                    this.atBeginning = false
                // If this is the last slide.
                } else if (slideEls[slideEls.length-1] === this.$el) {
                    this.atEnd = false
                }
            },
        },
    }"
      class="flex flex-col pt-16 mx-auto max-w-7xl px-6 lg:px-4"
    >
      <div
        x-on:keydown.right="next"
        x-on:keydown.left="prev"
        tabindex="0"
        role="region"
        aria-labelledby="carousel-label"
        class="flex"
      >
        <h2 id="carousel-label" class="sr-only" hidden>Carousel</h2>

        <%!-- Prev Button --%>
        <button
          x-on:click="prev"
          class="text-6xl"
          x-bind:aria-disabled="atBeginning"
          x-bind:tabindex="atEnd ? -1 : 0"
          x-bind:class="{ 'opacity-50 cursor-not-allowed': atBeginning }"
        >
          <span aria-hidden="true">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-6 text-gray-800 dark:text-gray-200"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="m11.25 9-3 3m0 0 3 3m-3-3h7.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
              />
            </svg>
          </span>
          <span class="sr-only">Skip to previous slide page</span>
        </button>

        <span id="carousel-content-label" class="sr-only" hidden>Carousel</span>

        <ul
          x-ref="slider"
          tabindex="0"
          role="listbox"
          aria-labelledby="carousel-content-label"
          class="flex w-full snap-x snap-mandatory overflow-hidden bg-transparent rounded-2xl"
        >
          <li
            x-bind="disableNextAndPreviousButtons"
            class="flex w-3/3 shrink-0 snap-start flex-col items-center justify-center px-2"
            role="option"
          >
            <img
              src={~p"/images/landing_page/light-timeline-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 color-scheme-light-timeline-preview"
              width="2432"
              height="1442"
            />

            <img
              src={~p"/images/landing_page/dark-timeline-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl dark:shadow-emerald-500/50 ring-1 ring-emerald-900/10 color-scheme-dark-timeline-preview"
              width="2432"
              height="1442"
            />
          </li>

          <li
            x-bind="disableNextAndPreviousButtons"
            class="flex w-3/3 shrink-0 snap-start flex-col items-center justify-center p-2"
            role="option"
          >
            <img
              src={~p"/images/landing_page/light-profile-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 color-scheme-light-timeline-preview"
              width="2432"
              height="1442"
            />

            <img
              src={~p"/images/landing_page/dark-profile-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl dark:shadow-emerald-500/50 ring-1 ring-emerald-900/10 color-scheme-dark-timeline-preview"
              width="2432"
              height="1442"
            />
          </li>

          <li
            x-bind="disableNextAndPreviousButtons"
            class="flex w-3/3 shrink-0 snap-start flex-col items-center justify-center p-2"
            role="option"
          >
            <img
              src={~p"/images/landing_page/light-timeline-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 color-scheme-light-timeline-preview"
              width="2432"
              height="1442"
            />
            <img
              src={~p"/images/landing_page/dark-timeline-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl dark:shadow-emerald-500/50 ring-1 ring-emerald-900/10 color-scheme-dark-timeline-preview"
              width="2432"
              height="1442"
            />
          </li>

          <li
            x-bind="disableNextAndPreviousButtons"
            class="flex w-3/3 shrink-0 snap-start flex-col items-center justify-center p-2"
            role="option"
          >
            <img
              src={~p"/images/landing_page/light-timeline-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 color-scheme-light-timeline-preview"
              width="2432"
              height="1442"
            />
            <img
              src={~p"/images/landing_page/dark-timeline-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl dark:shadow-emerald-500/50 ring-1 ring-emerald-900/10 color-scheme-dark-timeline-preview"
              width="2432"
              height="1442"
            />
          </li>
        </ul>

        <%!-- Next Button --%>
        <button
          x-on:click="next"
          class="text-6xl"
          x-bind:aria-disabled="atEnd"
          x-bind:tabindex="atEnd ? -1 : 0"
          x-bind:class="{ 'opacity-50 cursor-not-allowed': atEnd }"
        >
          <span aria-hidden="true">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="size-6 text-gray-800 dark:text-gray-200"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="m12.75 15 3-3m0 0-3-3m3 3h-7.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
              />
            </svg>
          </span>
          <span class="sr-only">Skip to next slide page</span>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Returns a button triggered dropdown with aria keyboard and focus supporrt.

  Accepts the follow slots:

    * `:id` - The id to uniquely identify this dropdown
    * `:img` - The optional img to show beside the button title
    * `:title` - The button title
    * `:subtitle` - The button subtitle

  ## Examples

      <.dropdown id={@id}>
        <:img src={@current_user.avatar_url}/>
        <:title><%= @current_user.name %></:title>
        <:subtitle>@<%= @current_user.username %></:subtitle>

        <:link navigate={profile_path(@current_user)}>View Profile</:link>
        <:link navigate={~p"/app/settings"}Settings</:link>
      </.dropdown>
  """
  attr :id, :string, required: true
  attr :svg_arrows, :boolean, default: true
  attr :button_class, :string, default: ""
  attr :connection?, :boolean, default: false

  slot :img do
    attr :src, :string
  end

  slot :title
  slot :subtitle
  slot :connection_block

  slot :link do
    attr :link_id, :string
    attr :navigate, :string
    attr :href, :string
    attr :phx_click, :any
    attr :phx_value_post_id, :any
    attr :phx_value_user_id, :any
    attr :phx_value_shared_username, :any
    attr :method, :any
    attr :data_confirm, :any
    attr :override_classes, :boolean
    attr :phx_hook, :string
    attr :data_tippy_content, :string
  end

  def dropdown(assigns) do
    ~H"""
    <%!-- User account dropdown --%>
    <div class={if !@connection?, do: "px-3 mt-6 relative inline-block text-left"}>
      <div>
        <button
          id={@id}
          type="button"
          class={"group w-full border border-1 rounded-md bg-background-50 dark:bg-gray-900 border-background-100 dark:border-gray-950 shadow-md dark:shadow-emerald-500/50 px-3.5 py-2 text-sm text-left focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-primary-100 focus:ring-primary-500" <> @button_class}
          phx-click={show_dropdown("##{@id}-dropdown")}
          phx-hook="Menu"
          data-active-class="bg-background-50"
          aria-haspopup="true"
        >
          <div :if={@connection?} class="flex flex-col group text-center items-center">
            {render_slot(@connection_block)}
          </div>
          <span class="flex w-full justify-between items-center">
            <span class="flex min-w-0 items-center justify-between space-x-3">
              <%= for img <- @img do %>
                <img
                  class="w-10 h-10 rounded-full flex-shrink-0"
                  alt=""
                  title="action dropdown"
                  {assigns_to_attributes(img)}
                />
              <% end %>
              <span class="flex-1 flex flex-col min-w-0">
                <span class="text-background-700 dark:text-gray-200 text-sm font-medium truncate">
                  {render_slot(@title)}
                </span>
                <span class="text-gray-500 dark:text-gray-400 text-sm truncate">
                  {render_slot(@subtitle)}
                </span>
              </span>
            </span>
            <svg
              :if={@svg_arrows}
              class="flex-shrink-0 h-5 w-5 text-background-700 group-hover:text-background-800 dark:text-gray-200 dark:group-hover:text-gray-300"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 3a1 1 0 01.707.293l3 3a1 1 0 01-1.414 1.414L10 5.414 7.707 7.707a1 1 0 01-1.414-1.414l3-3A1 1 0 0110 3zm-3.707 9.293a1 1 0 011.414 0L10 14.586l2.293-2.293a1 1 0 011.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z"
                clip-rule="evenodd"
              >
              </path>
            </svg>
          </span>
        </button>
      </div>
      <div
        id={"#{@id}-dropdown"}
        phx-click-away={hide_dropdown("##{@id}-dropdown")}
        class="hidden z-10 mx-3 origin-top absolute right-0 left-0 mt-1 rounded-md shadow-lg dark:shadow-emerald-500/50 bg-background-50 dark:bg-gray-950 ring-1 ring-background-100 dark:ring-gray-950 ring-opacity-5 divide-y divide-background-200 dark:divide-gray-900"
        role="menu"
        aria-labelledby={@id}
      >
        <div class="py-1" role="none">
          <%= for link <- @link do %>
            <.link
              :if={link}
              id={link.link_id}
              tabindex="-1"
              role="menuitem"
              class="block px-4 py-2 text-sm text-background-700 dark:text-gray-200 hover:bg-background-100 dark:hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-background-100 focus:ring-background-500"
              phx-click={link.phx_click}
              phx-value-post-id={link.phx_value_post_id}
              phx-value-user-id={link.phx_value_user_id}
              phx-value-shared-username={link.phx_value_shared_username}
              data-confirm={link.data_confirm}
              phx-hook={link.phx_hook}
              data-tippy-content={link.data_tippy_content}
              {link}
            >
              {render_slot(link)}
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def show_dropdown(to) do
    JS.show(
      to: to,
      transition:
        {"transition ease-out duration-120", "transform opacity-0 scale-95",
         "transform opacity-100 scale-100"}
    )
    |> JS.set_attribute({"aria-expanded", "true"}, to: to)
  end

  def hide_dropdown(to) do
    JS.hide(
      to: to,
      transition:
        {"transition ease-in duration-120", "transform opacity-100 scale-100",
         "transform opacity-0 scale-95"}
    )
    |> JS.remove_attribute("aria-expanded", to: to)
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.phx_flash kind={:info} flash={@flash} />
      <.phx_flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.phx_flash>
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error, :success], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def phx_flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-cyan-50 text-cyan-800 ring-cyan-500 fill-cyan-900",
        @kind == :success && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-emerald-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
      phx-hook="Flash"
    >
      cyan
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :success} name="hero-check-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.phx_flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def phx_flash_group(assigns) do
    ~H"""
    <.phx_flash kind={:info} title="Info!" flash={@flash} />
    <.phx_flash kind={:success} title="Success!" flash={@flash} />
    <.phx_flash kind={:error} title="Error!" flash={@flash} />
    <.phx_flash
      id="client-error"
      kind={:error}
      title="We can't find the internet"
      phx-disconnected={show(".phx-client-error #client-error")}
      phx-connected={hide("#client-error")}
      hidden
    >
      Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.phx_flash>

    <.phx_flash
      id="server-error"
      kind={:error}
      title="Something went wrong!"
      phx-disconnected={show(".phx-server-error #server-error")}
      phx-connected={hide("#server-error")}
      hidden
    >
      Hang in there while we get back on track
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.phx_flash>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  attr :class, :string, doc: "the optional css classes to style the form's div"
  attr :apply_classes?, :boolean, default: false

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class={if @apply_classes?, do: @class, else: "mt-10 space-y-8 bg-white dark:bg-gray-800"}>
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def phx_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-full bg-emerald-600 hover:bg-emerald-500 py-2 px-3",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :description?, :boolean, default: false
  attr :apply_classes?, :boolean, default: false
  attr :classes, :string

  attr :help, :string, default: nil
  attr :errors, :list, default: []
  attr :required, :boolean, default: false
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step ticks)

  slot :inner_block
  slot :description_block

  def phx_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> phx_input()
  end

  def phx_input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div phx-feedback-for={@name}>
      <div class="relative flex items-start pb-4 pt-3.5">
        <div class="min-w-0 flex-1 text-sm leading-6">
          <label class="font-semibold text-zinc-900 dark:text-white">{@label}</label>
          <div :if={@description?} id={@id <> "_description"} class="text-zinc-500 dark:text-gray-400">
            {render_slot(@description_block)}
          </div>
        </div>
        <div class="ml-3 flex h-6 items-center">
          <input type="hidden" name={@name} value="false" />
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class="h-4 w-4 rounded border-emerald-300 text-emerald-700 focus:ring-emerald-500"
            {@rest}
          />
        </div>
        <.error :for={msg <- @errors}>{msg}</.error>
      </div>
    </div>
    """
  end

  def phx_input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <div :if={@description?} id={@id <> "_description"} class="mt-2 text-sm leading-6 text-zinc-600">
        {render_slot(@description_block)}
      </div>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
      <.help :if={@help} text={@help} class="mt-1" />
    </div>
    """
  end

  def phx_input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <textarea
        id={@id}
        name={@name}
        class={
          if @apply_classes?,
            do: [
              "#{@classes} min-h-[6rem]",
              @errors == [] && "border-zinc-500 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ],
            else: [
              "bg-white dark:bg-gray-950 mt-2 block w-full rounded-lg text-zinc-900 dark:text-gray-100 focus:ring-0 sm:text-sm sm:leading-6",
              "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
              @errors == [] &&
                "border-zinc-300 focus:border-zinc-400 dark:border-gray-600 dark:focus:border-emerald-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]
        }
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
      <.help :if={@help} text={@help} class="mt-2" />
    </div>
    """
  end

  def phx_input(%{type: "range"} = assigns) do
    {local, rest} = Map.split(assigns.rest, [:min, :max, :step, :ticks])

    assigns =
      assigns
      |> assign(:min, Map.get(local, :min, 0))
      |> assign(:max, Map.get(local, :max, 9))
      |> assign(:step, Map.get(local, :step, 1))
      |> assign(:ticks, Map.get(local, :ticks, false))
      |> assign(:rest, rest)

    ~H"""
    <div phx-feedback-for={@name} class="text-sm">
      <.label :if={@label} for={@id} required={@required}>{@label}</.label>
      <div class="mx-auto w-full">
        <input
          id={@id}
          class="w-full cursor-pointer rounded-full accent-rose-500"
          {@rest}
          type="range"
          name={@name}
          min={@min}
          max={@max}
          step={@step}
          value={@value}
          list={"#{@id}-values"}
        />
        <%= if @ticks do %>
          <datalist id={"#{@id}-values"}>
            <option :for={tick_val <- @min..@max//@step} value={tick_val} label={tick_val}></option>
          </datalist>
        <% end %>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
      <.help :if={@help} text={@help} class="mt-2" />
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def phx_input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}>{@label}</.label>
      <div :if={@description?} id={@id <> "_description"} class="mt-2 text-sm leading-6 text-zinc-600">
        {render_slot(@description_block)}
      </div>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={
          if @apply_classes?,
            do: [
              @classes,
              @errors == [] && "border-zinc-300 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ],
            else: [
              "mt-2 block w-full rounded-lg text-zinc-900 dark:text-white focus:ring-0 sm:text-sm sm:leading-6",
              "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
              @errors == [] && "border-zinc-300 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]
        }
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
      <.help :if={@help} text={@help} class="mt-2" />
    </div>
    """
  end

  @doc """
  LiveSelect live_select component.
  """
  def live_select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns =
      assigns
      |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
      |> assign(:live_select_opts, assigns_to_attributes(assigns, [:errors, :label]))

    ~H"""
    <div phx-feedback-for={@field.name}>
      <.label for={@field.id}>{@label}</.label>
      <LiveSelect.live_select
        field={@field}
        text_input_class={[
          "dark:bg-gray-800 mt-2 block w-full rounded-lg border-zinc-300 border-2 py-[7px] px-[11px]",
          "text-zinc-900 focus:outline-none focus:ring-4 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-emerald-500 phx-no-feedback:focus:ring-emerald-800/5 phx-no-feedback:focus:ring-2",
          "border-zinc-300 dark:border-gray-600 dark:text-gray-300 dark:placeholder:text-gray-300 focus:border-emerald-500 focus:ring-emerald-800/5 focus:ring-2",
          @errors != [] && "border-rose-400 focus:border-rose-400 focus:ring-rose-400/10"
        ]}
        {@live_select_opts}
      />

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  attr :required, :boolean, default: false
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800 dark:text-white">
      {render_slot(@inner_block)}
      {if @required, do: " *", else: ""}
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :errors_list, required: false, doc: "The optional errors_list slot to render"
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      {render_slot(@inner_block)}
      <ul
        :if={@errors_list}
        id="form-errors"
        class="flex ml-10 mt-4 gap-3 text-sm leading-6 text-rose-600 list-disc"
      >
        {render_slot(@errors_list)}
      </ul>
    </p>
    """
  end

  @doc """
  Generates a generic input help text message.
  """
  attr :text, :string, required: true
  attr :class, :string, default: nil

  def help(assigns) do
    ~H"""
    <p class={["text-gray-500", @class]}>{@text}</p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8 text-zinc-800">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def phx_table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pr-6 pb-4 font-normal">{col[:label]}</th>
            <th class="relative p-0 pb-4"><span class="sr-only">{gettext("Actions")}</span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="group hover:bg-zinc-50 dark:hover:bg-gray-950"
          >
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 dark:hover:bg-gray-950 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  {render_slot(col, @row_item.(row))}
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 dark:hover:bg-gray-950 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  {render_slot(action, @row_item.(row))}
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with sticky styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id"><%= user.id %></:col>
        <:col :let={user} label="username"><%= user.username %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def sticky_table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="mt-8 flow-root">
      <div class="overflow-visible">
        <div class="inline-block min-w-full py-2 align-middle">
          <table class="min-w-full border-separate border-spacing-0">
            <thead>
              <tr>
                <th
                  :for={col <- @col}
                  class="sticky top-0 z-10 border-b border-gray-300 dark:border-emerald-700 bg-background-50 dark:bg-gray-950 bg-opacity-75 py-3.5 pr-3 text-left text-sm font-semibold text-gray-900 dark:text-gray-300 backdrop-blur backdrop-filter"
                >
                  {col[:label]}
                </th>
                <th class="sticky top-0 z-10 border-b border-gray-300 dark:border-emerald-700 bg-background-50 dark:bg-gray-950 bg-opacity-75 py-3.5 pr-3 text-left text-sm font-semibold text-gray-900 dark:text-gray-300 backdrop-blur backdrop-filter">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody
              id={@id}
              phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
              class="relative divide-y divide-zinc-100 border-t border-gray-300 dark:border-emerald-700 text-sm leading-6 text-zinc-700 dark:text-gray-300"
            >
              <tr
                :for={row <- @rows}
                id={@row_id && @row_id.(row)}
                class="group hover:bg-background-200 dark:hover:bg-gray-800"
              >
                <td
                  :for={{col, i} <- Enum.with_index(@col)}
                  phx-click={@row_click && @row_click.(row)}
                  class={["relative p-0", @row_click && "hover:cursor-pointer"]}
                >
                  <div class="relative py-4 pr-2">
                    <span class="absolute -inset-y-px right-0 -left-4" />
                    <span class={[
                      "relative",
                      i == 0 && "font-semibold text-zinc-900 dark:text-gray-100"
                    ]}>
                      {render_slot(col, @row_item.(row))}
                    </span>
                  </div>
                </td>
                <td :if={@action != []} class="relative w-14 p-0">
                  <div class="relative whitespace-nowrap p-4 text-right text-sm font-medium">
                    <span class="absolute -inset-y-px -right-4 left-0" />
                    <span
                      :for={action <- @action}
                      class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700 dark:text-gray-100 dark:group-hover:text-gray-200"
                    >
                      {render_slot(action, @row_item.(row))}
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title"><%= @post.title %></:item>
        <:item title="Views"><%= @post.views %></:item>
      </.list>
  """
  attr :container_class, :any, default: nil
  attr :id, :any, default: nil

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div id={@id} class={if @container_class, do: @container_class, else: "mt-14"}>
      <dl class="-my-4 divide-y divide-zinc-100">
        <div :for={item <- @item} class="flex gap-4 py-4 text-sm leading-6 sm:gap-8">
          <dt class="w-1/4 flex-none font-semibold text-gray-700 dark:text-white">
            {item.title}
          </dt>
          <dd class="text-zinc-500 dark:text-gray-300">{render_slot(item)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/app/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  attr :class, :string, default: "mt-16"
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class={@class}>
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  attr :navigate, :any, required: true
  attr :nav_title, :string, required: true
  slot :inner_block, required: true

  def info_banner(assigns) do
    ~H"""
    <div class="rounded-lg bg-background-200 dark:bg-gray-800 p-4 mt-8 shadow-lg dark:shadow-emerald-500/50">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg
            class="h-5 w-5 text-background-500 dark:text-gray-400"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <div class="ml-3 flex-1 md:flex md:justify-between">
          <p class="text-sm text-background-800 dark:text-gray-200">{render_slot(@inner_block)}</p>
          <p class="mt-3 text-sm md:ml-6 md:mt-0">
            <.link
              navigate={@navigate}
              class="whitespace-nowrap font-medium text-background-800 hover:text-background-700 dark:text-gray-200 dark:hover:text-gray-100"
            >
              {@nav_title}
              <span aria-hidden="true"> &rarr;</span>
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr(:src, :string, default: nil, doc: "hosted avatar URL")
  attr(:alt, :string, default: nil, doc: "avatar alt text")
  attr(:size, :string, default: "h-12 w-12", doc: "the height and width sizes")
  attr(:text_size, :string, default: "md", doc: "the text size for initials, defaults to lg")
  attr(:class, :string, default: "", doc: "CSS class")
  attr(:name, :string, default: nil, doc: "name for placeholder initials")
  attr(:user, :any, default: nil, doc: "the current user struct")
  attr(:key, :string, default: nil, doc: "the current user session key")

  attr(:rest, :global)

  def phx_avatar(assigns) do
    ~H"""
    <%= if src_blank?(@src) && (!@name || @name == "") do %>
      <img
        class={
          if @class == "",
            do: "inline-block #{@size} rounded-md bg-background-50 dark:bg-gray-900",
            else: @class
        }
        src={~p"/images/logo.svg"}
        alt="Mosslet egg logo"
      />
    <% else %>
      <%= if src_nil?(@src) && @name do %>
        <span class={
          if @class == "",
            do:
              "inline-flex #{@size} items-center justify-center  rounded-md bg-background-50 dark:bg-gray-900",
            else: "inline-flex #{@class} #{@size} items-center justify-center "
        }>
          <p class={"text-#{@text_size} font-semibold text-emerald-600 dark:text-emerald-400 leading-none"}>
            {generate_initials(@name)}
          </p>
        </span>
      <% else %>
        <%= if @src == "" && @name do %>
          <span class={
            if @class == "",
              do:
                "inline-flex text-#{@size} items-center justify-center rounded-md bg-background-50 dark:bg-gray-900",
              else: "inline-flex #{@class} #{@size} items-center justify-center"
          }>
            <.spinner size="md" class="text-primary-500" />
          </span>
        <% else %>
          <img
            class={
              if @class == "",
                do: "inline-block #{@size} rounded-full bg-background-50 dark:bg-gray-900",
                else: @class
            }
            src={@src}
            alt={@alt}
          />
        <% end %>
      <% end %>
    <% end %>
    """
  end

  attr(:src, :string, default: nil, doc: "hosted avatar URL")
  attr(:alt, :string, default: nil, doc: "avatar alt text")
  attr(:size, :string, default: "h-12 w-12", doc: "the height and width sizes")
  attr(:text_size, :string, default: "md", doc: "the text size for initials, defaults to lg")
  attr(:class, :string, default: "", doc: "CSS class")
  attr(:name, :string, default: nil, doc: "name for placeholder initials")
  attr(:user, :any, default: nil, doc: "the current user struct")
  attr(:key, :string, default: nil, doc: "the current user session key")

  attr(:rest, :global)

  def group_avatar(assigns) do
    ~H"""
    <%= if src_blank?(@src) && (!@name || @name == "") do %>
      <img
        class={
          if @class == "",
            do: "inline-block #{@size} rounded-md bg-white dark:bg-gray-900",
            else: @class
        }
        src={~p"/images/logo.svg"}
        alt="Mosslet egg logo"
      />
    <% else %>
      <%= if src_nil?(@src) && @name do %>
        <span class={
          if @class == "",
            do:
              "inline-flex #{@size} items-center justify-center overflow-hidden rounded-md bg-white dark:bg-gray-900",
            else: "inline-flex #{@class} #{@size} items-center justify-center overflow-hidden"
        }>
          <span class={"text-#{@text_size} font-thin leading-none"}>
            {generate_initials(@name)}
          </span>
        </span>
      <% else %>
        <%= if @src == "" && @name do %>
          <span class={
            if @class == "",
              do:
                "inline-flex text-#{@size} items-center justify-center overflow-hidden rounded-md bg-white dark:bg-gray-900",
              else: "inline-flex #{@class} #{@size} items-center justify-center overflow-hidden"
          }>
            <.spinner size="md" class="text-primary-500" />
          </span>
        <% else %>
          <img
            class={
              if @class == "",
                do: "inline-block #{@size} rounded-full bg-white dark:bg-gray-900",
                else: @class
            }
            src={@src}
            alt={@alt}
          />
        <% end %>
      <% end %>
    <% end %>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def phx_icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def phx_icon(%{name: "fa-user-robot"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class={@class} fill="currentColor" viewBox="0 0 448 512">
        <path d="M17.99986,256H48V128H17.99986A17.9784,17.9784,0,0,0,0,146v92A17.97965,17.97965,0,0,0,17.99986,256Zm412-128H400V256h29.99985A17.97847,17.97847,0,0,0,448,238V146A17.97722,17.97722,0,0,0,429.99985,128ZM116,320H332a36.0356,36.0356,0,0,0,36-36V109a44.98411,44.98411,0,0,0-45-45H241.99985V18a18,18,0,1,0-36,0V64H125a44.98536,44.98536,0,0,0-45,45V284A36.03685,36.03685,0,0,0,116,320Zm188-48H272V240h32ZM288,128a32,32,0,1,1-32,32A31.99658,31.99658,0,0,1,288,128ZM208,240h32v32H208Zm-32,32H144V240h32ZM160,128a32,32,0,1,1-32,32A31.99658,31.99658,0,0,1,160,128ZM352,352H96A95.99975,95.99975,0,0,0,0,448v32a32.00033,32.00033,0,0,0,32,32h96V448a31.99908,31.99908,0,0,1,32-32H288a31.99908,31.99908,0,0,1,32,32v64h96a32.00033,32.00033,0,0,0,32-32V448A95.99975,95.99975,0,0,0,352,352ZM176,448a15.99954,15.99954,0,0,0-16,16v48h32V464A15.99954,15.99954,0,0,0,176,448Zm96,0a16,16,0,1,0,16,16A15.99954,15.99954,0,0,0,272,448Z" />
      </svg>
    </span>
    """
  end

  def phx_icon(%{name: "fa-function"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class={@class} fill="currentColor" viewBox="0 0 640 512">
        <path d="M288.73 320c0-52.34 16.96-103.22 48.01-144.95 5.17-6.94 4.45-16.54-2.15-22.14l-24.69-20.98c-7-5.95-17.83-5.09-23.38 2.23C246.09 187.42 224 252.78 224 320c0 67.23 22.09 132.59 62.52 185.84 5.56 7.32 16.38 8.18 23.38 2.23l24.69-20.99c6.59-5.61 7.31-15.2 2.15-22.14-31.06-41.71-48.01-92.6-48.01-144.94zM224 16c0-8.84-7.16-16-16-16h-48C102.56 0 56 46.56 56 104v64H16c-8.84 0-16 7.16-16 16v48c0 8.84 7.16 16 16 16h40v128c0 13.2-10.8 24-24 24H16c-8.84 0-16 7.16-16 16v48c0 8.84 7.16 16 16 16h16c57.44 0 104-46.56 104-104V248h40c8.84 0 16-7.16 16-16v-48c0-8.84-7.16-16-16-16h-40v-64c0-13.2 10.8-24 24-24h48c8.84 0 16-7.16 16-16V16zm353.48 118.16c-5.56-7.32-16.38-8.18-23.38-2.23l-24.69 20.98c-6.59 5.61-7.31 15.2-2.15 22.14 31.05 41.71 48.01 92.61 48.01 144.95 0 52.34-16.96 103.23-48.01 144.95-5.17 6.94-4.45 16.54 2.15 22.14l24.69 20.99c7 5.95 17.83 5.09 23.38-2.23C617.91 452.57 640 387.22 640 320c0-67.23-22.09-132.59-62.52-185.84zm-54.17 231.9L477.25 320l46.06-46.06c6.25-6.25 6.25-16.38 0-22.63l-22.62-22.62c-6.25-6.25-16.38-6.25-22.63 0L432 274.75l-46.06-46.06c-6.25-6.25-16.38-6.25-22.63 0l-22.62 22.62c-6.25 6.25-6.25 16.38 0 22.63L386.75 320l-46.06 46.06c-6.25 6.25-6.25 16.38 0 22.63l22.62 22.62c6.25 6.25 16.38 6.25 22.63 0L432 365.25l46.06 46.06c6.25 6.25 16.38 6.25 22.63 0l22.62-22.62c6.25-6.25 6.25-16.38 0-22.63z" />
      </svg>
    </span>
    """
  end

  def phx_icon(%{name: "fa-code-branch"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class={@class} fill="currentColor" viewBox="0 0 384 512">
        <path d="M384 144c0-44.2-35.8-80-80-80s-80 35.8-80 80c0 36.4 24.3 67.1 57.5 76.8-.6 16.1-4.2 28.5-11 36.9-15.4 19.2-49.3 22.4-85.2 25.7-28.2 2.6-57.4 5.4-81.3 16.9v-144c32.5-10.2 56-40.5 56-76.3 0-44.2-35.8-80-80-80S0 35.8 0 80c0 35.8 23.5 66.1 56 76.3v199.3C23.5 365.9 0 396.2 0 432c0 44.2 35.8 80 80 80s80-35.8 80-80c0-34-21.2-63.1-51.2-74.6 3.1-5.2 7.8-9.8 14.9-13.4 16.2-8.2 40.4-10.4 66.1-12.8 42.2-3.9 90-8.4 118.2-43.4 14-17.4 21.1-39.8 21.6-67.9 31.6-10.8 54.4-40.7 54.4-75.9zM80 64c8.8 0 16 7.2 16 16s-7.2 16-16 16-16-7.2-16-16 7.2-16 16-16zm0 384c-8.8 0-16-7.2-16-16s7.2-16 16-16 16 7.2 16 16-7.2 16-16 16zm224-320c8.8 0 16 7.2 16 16s-7.2 16-16 16-16-7.2-16-16 7.2-16 16-16z" />
      </svg>
    </span>
    """
  end

  def phx_icon(%{name: "fa-highlight"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class="fill-black dark:fill-white" viewBox="0 0 576 512">
        <path d="M315 315l158.4-215L444.1 70.6 229 229 315 315zm-187 5s0 0 0 0l0-71.7c0-15.3 7.2-29.6 19.5-38.6L420.6 8.4C428 2.9 437 0 446.2 0c11.4 0 22.4 4.5 30.5 12.6l54.8 54.8c8.1 8.1 12.6 19 12.6 30.5c0 9.2-2.9 18.2-8.4 25.6L334.4 396.5c-9 12.3-23.4 19.5-38.6 19.5L224 416l-25.4 25.4c-12.5 12.5-32.8 12.5-45.3 0l-50.7-50.7c-12.5-12.5-12.5-32.8 0-45.3L128 320zM7 466.3l63-63 70.6 70.6-31 31c-4.5 4.5-10.6 7-17 7L24 512c-13.3 0-24-10.7-24-24l0-4.7c0-6.4 2.5-12.5 7-17z" />
      </svg>
    </span>
    """
  end

  def user_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class="w-8 h-8"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"
      />
    </svg>
    """
  end

  def chat_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      class="w-6 h-6"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155"
      />
    </svg>
    """
  end

  attr :id, :string, default: nil, doc: "the html id for the delete icon"
  attr :phx_target, :any, default: nil, doc: "the target for the phx-click event"
  attr :value, :string, default: nil, doc: "the value for the phx-value-item_id event"
  attr :phx_click, :any, default: nil, doc: "the phx-click event to trigger on click"

  def delete_icon(assigns) do
    ~H"""
    <svg
      :if={@phx_click}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="red"
      class="w-6 h-6 float-right pl-2 cursor-pointer"
      style="display:none"
      id={@id}
      phx-click={@phx_click}
      phx-target={@phx_target}
      phx-value-item_id={@value}
      phx-data-confirm="Are you sure you want to delete this message?"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
      />
    </svg>
    """
  end

  # SETUP_TODO
  # This module relies on the following images. Replace these images with your logos.
  # We created a Figma file to easily create and import these assets: https://www.figma.com/community/file/1139155923924401853
  # /priv/static/images/logo_dark.svg
  # /priv/static/images/logo_light.svg
  # /priv/static/images/logo_icon_dark.svg
  # /priv/static/images/logo_icon_light.svg
  # /priv/static/images/favicon.png
  # /priv/static/images/open-graph.png

  @doc "Displays your full logo. "

  attr :class, :string, default: "h-10"
  attr :variant, :string, default: "both", values: ["dark", "light", "both"]

  def logo(assigns) do
    assigns = assign_new(assigns, :logo_file, fn -> "logo_#{assigns[:variant]}.svg" end)

    ~H"""
    <%= if Enum.member?(["light", "dark"], @variant) do %>
      <img class={@class} src={~p"/images/#{@logo_file}"} alt={Mosslet.config(:app_name)} />
    <% else %>
      <img
        class={@class <> " block dark:hidden"}
        src={~p"/images/logo_light.svg"}
        alt={Mosslet.config(:app_name)}
      />
      <img
        class={@class <> " hidden dark:block"}
        src={~p"/images/logo_dark.svg"}
        alt={Mosslet.config(:app_name)}
      />
    <% end %>
    """
  end

  @doc "Displays just the icon part of your logo"

  attr :class, :string, default: "h-9 w-9"
  attr :variant, :string, default: "both", values: ["dark", "light", "both"]

  def logo_icon(assigns) do
    assigns = assign_new(assigns, :logo_file, fn -> "logo_icon_#{assigns[:variant]}.svg" end)

    ~H"""
    <%= if Enum.member?(["light", "dark"], @variant) do %>
      <img class={@class} src={~p"/images/#{@logo_file}"} alt={Mosslet.config(:app_name)} />
    <% else %>
      <img
        class={@class <> " block dark:hidden"}
        src={~p"/images/logo_icon_dark.svg"}
        alt={Mosslet.config(:app_name)}
      />
      <img
        class={@class <> " hidden dark:block"}
        src={~p"/images/logo_icon_light.svg"}
        alt={Mosslet.config(:app_name)}
      />
    <% end %>
    """
  end

  def logo_for_emails(assigns) do
    ~H"""
    <img height="60" src={Mosslet.config(:logo_url_for_emails)} />
    """
  end

  def welcome_image_for_emails(assigns) do
    ~H"""
    <img width="570" src={~p"/images/email/welcome_screenshot.png"} />
    """
  end

  attr :current_user, :map, default: nil
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]

  def footer(assigns) do
    ~H"""
    <section id="footer">
      <container class="mx-auto max-w-full px-4 sm:px-6 lg:px-8">
        <div class="py-16">
          <.logo class="mx-auto h-16 w-auto" />
          <div class="mt-10 text-sm">
            <div class="-my-1 flex flex-col sm:flex-row items-center justify-center gap-x-6">
              <.list_menu_items
                li_class="inline-flex rounded-lg px-2 py-1 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-800 dark:hover:text-gray-100"
                a_class="text-gray-700 dark:text-gray-300 md:text-sm hover:text-gray-800 dark:hover:text-gray-200"
                menu_items={public_menu_footer_items(@current_user)}
              />
            </div>
          </div>
        </div>
        <div class="flex flex-col items-center border-t border-gray-400/10 dark:border-gray-400/20 py-10 sm:flex-row-reverse sm:justify-between">
          <div class="flex gap-x-6">
            <button>
              <.link
                id="mosslet-terms-link"
                navigate={~p"/terms#terms_and_conditions"}
                aria-label="MOSSLET Terms and Conditions"
                data-tippy-content="MOSSLET Terms and Conditions"
                phx-hook="TippyHook"
              >
                <.phx_icon
                  name="hero-document-text"
                  class="size-6 group-hover:fill-gray-700 group-hover:text-gray-300 dark:group-hover:fill-emerald-700"
                />
              </.link>
            </button>

            <.link
              id="mosslet-podcast-link"
              href="https://podcast.mosslet.com"
              class="group"
              target="_blank"
              rel="_no_opener"
              aria-label="MOSSLET Podcast"
              data-tippy-content="MOSSLET podcast"
              phx-hook="TippyHook"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="h-6 w-6  group-hover:fill-gray-700 dark:group-hover:fill-emerald-700"
                aria-hidden="true"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18.75a6 6 0 0 0 6-6v-1.5m-6 7.5a6 6 0 0 1-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 0 1-3-3V4.5a3 3 0 1 1 6 0v8.25a3 3 0 0 1-3 3Z"
                />
              </svg>
            </.link>
            <.link
              id="mosslet-github-link"
              href="https://github.com/moss-piglet/mosslet"
              class="group"
              aria-label="MOSSLET on GitHub"
              data-tippy-content="MOSSLET open source code on GitHub"
              phx-hook="TippyHook"
            >
              <svg
                class="h-6 w-6 fill-slate-500 dark:fill-slate-400 group-hover:fill-slate-700 dark:group-hover:fill-emerald-700"
                aria-hidden="true"
                viewBox="0 0 24 24"
              >
                <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" />
              </svg>
            </.link>
          </div>
          <div>
            <p class="mt-6 text-sm text-gray-500 dark:text-gray-400 sm:mt-0">
              Copyright &copy; 2023 Moss Piglet Corporation. A Public Benefit company. All rights
              reserved.
            </p>
            <div class="inline-flex items-center align-middle">
              <.link
                target="_blank"
                rel="noopener noreferrer"
                href="https://climate.stripe.com/0YsHsR"
                class="mt-2 text-sm text-gray-500 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 sm:mt-0"
              >
                1% of purchases contributed to Stripe Climate
                <img
                  src={~p"/images/landing_page/Stripe Climate Badge.svg"}
                  class="size-6 inline-flex"
                />
              </.link>
            </div>
          </div>
        </div>
      </container>
    </section>
    """
  end

  @doc """
  A kind of proxy layout allowing you to pass in a user. Layout components should have little knowledge about your application so this is a way you can pass in a user and it will build a lot of the attributes for you based off the user.

  Ideally you should modify this file a lot and not touch the actual layout components like "sidebar_layout" and "stacked_layout".
  If you're creating a new layout then duplicate "sidebar_layout" or "stacked_layout" and give it a new name. Then modify this file to allow your new layout. This way live views can keep using this component and simply switch the "type" attribute to your new layout.
  """
  attr :type, :string, default: "sidebar", values: ["sidebar", "stacked", "public"]
  attr :current_page, :atom, required: true
  attr :current_user, :map, default: nil
  attr :public_menu_items, :list
  attr :main_menu_items, :list
  attr :user_menu_items, :list
  attr :avatar_src, :string
  attr :current_user_name, :string
  attr :sidebar_title, :string, default: nil
  attr :home_path, :string
  attr :container_max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  attr :collapsible, :boolean, default: false
  attr :collapsed_only, :boolean, default: false
  attr :default_collapsed, :boolean, default: false
  attr :user, :any, doc: "the current user struct"
  attr :key, :string, doc: "the session key for the current user"
  attr :socket, :any, doc: "the socket for connection"
  slot :logo_icon
  slot :inner_block
  slot :top_right
  slot :logo

  def layout(assigns) do
    assigns =
      assigns
      |> assign_new(:public_menu_items, fn -> public_menu_items(assigns[:current_user]) end)
      |> assign_new(:public_menu_footer_items, fn ->
        public_menu_footer_items(assigns[:current_user])
      end)
      |> assign_new(:main_menu_items, fn -> main_menu_items(assigns[:current_user]) end)
      |> assign_new(:user_menu_items, fn -> user_menu_items(assigns[:current_user]) end)
      |> assign_new(:current_user_name, fn -> user_name(assigns[:current_user], assigns[:key]) end)
      |> assign_new(:avatar_src, fn -> user_avatar_url(assigns[:current_user]) end)
      |> assign_new(:home_path, fn -> home_path(assigns[:current_user]) end)

    ~H"""
    <%= case @type do %>
      <% "sidebar" -> %>
        <.sidebar_layout {assigns} collapsed_only={true}>
          <:logo>
            <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
          </:logo>
          <:logo_icon>
            <.logo_icon />
          </:logo_icon>
          <:top_right>
            <button
              :if={@current_user.confirmed_at}
              id="invite-connection-link"
              phx-hook="TippyHook"
              type="button"
              data-tippy-content="Invite people to join you on Mosslet!"
            >
              <.link
                navigate={~p"/app/users/connections/invite/new-invite"}
                class="inline-flex items-center text-sm text-background-500 dark:text-gray-400 hover:bg-background-100 dark:hover:bg-gray-700 focus:outline-none focus:ring-4 focus:ring-background-200 dark:focus:ring-gray-700 rounded-lg py-2.5 px-3"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="size-5 mr-1"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M6 12 3.269 3.125A59.769 59.769 0 0 1 21.485 12 59.768 59.768 0 0 1 3.27 20.875L5.999 12Zm0 0h7.5"
                  />
                </svg>
                New invite
              </.link>
            </button>

            <.color_scheme_switch />
          </:top_right>
          {render_slot(@inner_block)}
        </.sidebar_layout>
      <% "stacked" -> %>
        <.stacked_layout {assigns}>
          <:logo>
            <div class="flex items-center flex-shrink-0 w-24 h-full">
              <div class="hidden lg:block">
                <.logo class="h-8" />
              </div>
              <div class="block lg:hidden">
                <.logo class="w-auto h-8" />
              </div>
            </div>
          </:logo>
          <:top_right>
            <.color_scheme_switch />
          </:top_right>
          {render_slot(@inner_block)}
        </.stacked_layout>
      <% "public" -> %>
        <.mosslet_public_layout
          {assigns}
          twitter_url={Mosslet.config(:twitter_url)}
          github_url={Mosslet.config(:github_url)}
          discord_url={Mosslet.config(:discord_url)}
          header_class="inline-block px-2 py-1 text-sm text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-gray-50"
        >
          <:logo>
            <.logo class="h-14 w-auto" />
          </:logo>

          <:top_right>
            <.color_scheme_switch />
          </:top_right>
          {render_slot(@inner_block)}
        </.mosslet_public_layout>
    <% end %>
    """
  end

  # Shows the login buttons for all available providers. Can add a break "Or login with"
  attr :or_location, :string, default: "", values: ["top", "bottom", ""]
  attr :or_text, :string, default: "Or"
  attr :conn_or_socket, :any

  def auth_providers(assigns) do
    ~H"""
    <%= if auth_provider_loaded?("google") || auth_provider_loaded?("github") || auth_provider_loaded?("passwordless") do %>
      <%= if @or_location == "top" do %>
        <.or_break or_text={@or_text} />
      <% end %>

      <%= if @or_location == "bottom" do %>
        <.or_break or_text={@or_text} />
      <% end %>
    <% end %>
    """
  end

  @doc """
  Checks if a ueberauth provider has been enabled with the correct environment variables

  ## Examples

      iex> auth_provider_loaded?("google")
      iex> true
  """
  def auth_provider_loaded?(provider) do
    case provider do
      "google" ->
        get_in(Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth), [:client_id])

      "github" ->
        get_in(Application.get_env(:ueberauth, Ueberauth.Strategy.Github.OAuth), [:client_id])

      "passwordless" ->
        Mosslet.config(:passwordless_enabled)
    end
  end

  # Shows a line with some text in the middle of the line. eg "Or login with"
  attr :or_text, :string

  def or_break(assigns) do
    ~H"""
    <div class="relative my-5">
      <div class="absolute inset-0 flex items-center">
        <div class="w-full border-t border-gray-300 dark:border-gray-600"></div>
      </div>
      <div class="relative flex justify-center text-sm">
        <span class="px-2 text-gray-500 bg-white dark:bg-gray-800">
          {@or_text}
        </span>
      </div>
    </div>
    """
  end

  attr :li_class, :string, default: ""
  attr :a_class, :string, default: ""
  attr :menu_items, :list, default: [], doc: "list of maps with keys :method, :path, :label"

  def list_menu_items(assigns) do
    ~H"""
    <%= for menu_item <- @menu_items do %>
      <li class={@li_class}>
        <.link
          navigate={menu_item.path}
          class={@a_class}
          method={if menu_item[:method], do: menu_item[:method], else: nil}
        >
          {menu_item.label}
        </.link>
      </li>
    <% end %>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def phx_show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def phx_hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(MossletWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MossletWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Use for when you want to combine all form errors into one message (maybe to display in a flash)
  """
  def combine_changeset_error_messages(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    Enum.map_join(errors, "\n", fn {key, errors} ->
      "#{Phoenix.Naming.humanize(key)}: #{Enum.join(errors, ", ")}\n"
    end)
  end

  slot :title, required: true
  slot :right
  slot :links
  slot :description
  slot :inner_block, required: true

  @doc """
  Section heading with title and description.
  """
  def section_heading(assigns) do
    ~H"""
    <div class="px-4 py-5 sm:px-6">
      <div class="flex items-center">
        <div class="flex-grow">
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            <%= for title <- @title do %>
              {render_slot(title)}
            <% end %>
          </h3>
          <%= for description <- @description do %>
            <p class="text-sm text-gray-500">
              <div class="mt-1 max-w-2xl text-sm text-gray-500">
                {render_slot(description)}
              </div>
            </p>
          <% end %>

          <%= for inner_block <- @inner_block do %>
            <div class="mt-1 max-w-2xl text-sm text-gray-500">
              {render_slot(inner_block)}
            </div>
          <% end %>
        </div>
        <%= for right <- @right do %>
          {render_slot(right)}
        <% end %>
      </div>
      <%= for links <- @links do %>
        <div class="mt-2 text-sm">
          {render_slot(links)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Render a simple filter form input.
  """
  attr :rest, :global

  def simple_filter_form(assigns) do
    ~H"""
    <form phx-change="simple-filter" phx-submit="simple-filter" {@rest}>
      <input
        type="text"
        name="filter"
        id="filter"
        phx-debounce="500"
        class="shadow-sm focus:ring-primary-500 focus:border-brand-500 block w-full sm:text-sm border-gray-300 px-4 rounded-full"
        placeholder="Filter"
      />
    </form>
    """
  end

  @doc """
  Apply the filtering value from Simple Filter input form. This dynamically
  filters an in-memory list of maps. The value is partially matched with a
  case-insensitive search against each item in the list by that specified
  attribute.

      simple_filter_apply(Conversations.all_contexts(), value, :name

  """
  def simple_filter_apply(full_list, "", _match_attribute), do: full_list

  def simple_filter_apply(full_list, filter_value, match_attribute) do
    match_value = filter_value |> String.trim() |> String.downcase()

    Enum.filter(full_list, fn item ->
      item_val = Map.get(item, match_attribute) |> String.downcase()
      String.contains?(item_val, match_value)
    end)
  end

  ## Private

  defp src_blank?(src) do
    !src || src == ""
  end

  defp src_nil?(src) do
    !src
  end

  defp generate_initials(name) when is_binary(name) do
    word_array = String.split(name)

    if length(word_array) == 1 do
      List.first(word_array)
      |> String.slice(0..1)
      |> String.downcase()
    else
      if Enum.empty?(word_array) do
        ""
      else
        initial1 = String.first(List.first(word_array))
        initial2 = String.first(List.last(word_array))
        initial1 <> initial2
      end
    end
  end

  defp generate_initials(_) do
    ""
  end
end
