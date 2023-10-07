defmodule MetamorphicWeb.CoreComponents do
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
  use MetamorphicWeb, :verified_routes

  alias Phoenix.LiveView.JS
  import MetamorphicWeb.Gettext

  @doc """
  Renders the local time for a struct with
  the relative formatting.
  """
  attr :at, :any, required: true
  attr :id, :any, required: true

  def local_time_ago(assigns) do
    ~H"""
    <time phx-hook="LocalTimeAgo" id={"time-#{@id}"} class="hidden"><%= @at %></time>
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
    <time phx-hook="LocalTimeFull" id={"time-#{@id}"} class="hidden"><%= @at %></time>
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
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
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
        <:link navigate={~p"/profile/settings"}Settings</:link>
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
    attr :navigate, :string
    attr :href, :string
    attr :phx_click, :any
    attr :method, :any
    attr :data_confirm, :any
  end

  def dropdown(assigns) do
    ~H"""
    <!-- User account dropdown -->
    <div class={if !@connection?, do: "px-3 mt-6 relative inline-block text-left"}>
      <div>
        <button
          id={@id}
          type="button"
          class={"group w-full rounded-md px-3.5 py-2 text-sm text-left focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-brand-100 focus:ring-brand-500" <> @button_class}
          phx-click={show_dropdown("##{@id}-dropdown")}
          phx-hook="Menu"
          data-active-class="bg-gray-100"
          aria-haspopup="true"
        >
          <div :if={@connection?} class="flex flex-col group text-center items-center">
            <%= render_slot(@connection_block) %>
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
                <span class="text-gray-900 text-sm font-medium truncate">
                  <%= render_slot(@title) %>
                </span>
                <span class="text-gray-500 text-sm truncate"><%= render_slot(@subtitle) %></span>
              </span>
            </span>
            <svg
              :if={@svg_arrows}
              class="flex-shrink-0 h-5 w-5 text-gray-400 group-hover:text-gray-500"
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
        class="hidden z-10 mx-3 origin-top absolute right-0 left-0 mt-1 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 divide-y divide-gray-200"
        role="menu"
        aria-labelledby={@id}
      >
        <div class="py-1" role="none">
          <%= for link <- @link do %>
            <.link
              tabindex="-1"
              role="menuitem"
              class="block px-4 py-2 text-sm text-gray-700 hover:bg-brand-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-brand-100 focus:ring-brand-500"
              phx-click={link.phx_click}
              data-confirm={link.data_confirm}
              {link}
            >
              <%= render_slot(link) %>
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

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error, :success], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-brand-50 text-brand-800 ring-brand-500 fill-brand-900",
        @kind == :success && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-pink-50 text-pink-900 shadow-md ring-pink-500 fill-pink-900"
      ]}
      {@rest}
      phx-hook="Flash"
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :success} name="hero-check-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} title="Info!" flash={@flash} />
    <.flash kind={:success} title="Success!" flash={@flash} />
    <.flash kind={:error} title="Error!" flash={@flash} />
    <.flash
      id="client-error"
      kind={:error}
      title="We can't find the internet"
      phx-disconnected={show(".phx-client-error #client-error")}
      phx-connected={hide("#client-error")}
      hidden
    >
      Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>

    <.flash
      id="server-error"
      kind={:error}
      title="Something went wrong!"
      phx-disconnected={show(".phx-server-error #server-error")}
      phx-connected={hide("#server-error")}
      hidden
    >
      Hang in there while we get back on track
      <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
    </.flash>
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
      <div class={if @apply_classes?, do: @class, else: "mt-10 space-y-8 bg-white"}>
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          <%= render_slot(action, f) %>
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

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-brand-700 hover:bg-brand-600 py-2 px-3",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
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
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step ticks)

  slot :inner_block
  slot :description_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div phx-feedback-for={@name}>
      <div class="relative flex items-start pb-4 pt-3.5">
        <div class="min-w-0 flex-1 text-sm leading-6">
          <label class="font-semibold text-zinc-900"><%= @label %></label>
          <div :if={@description?} id={@id <> "_description"} class="text-zinc-500">
            <%= render_slot(@description_block) %>
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
            class="h-4 w-4 rounded border-brand-300 text-brand-700 focus:ring-brand-500"
            {@rest}
          />
        </div>
        <.error :for={msg <- @errors}><%= msg %></.error>
      </div>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <div :if={@description?} id={@id <> "_description"} class="mt-2 text-sm leading-6 text-zinc-600">
        <%= render_slot(@description_block) %>
      </div>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
      <.help :if={@help} text={@help} class="mt-1" />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={
          if @apply_classes?,
            do: [
              "#{@classes} min-h-[6rem]",
              @errors == [] && "border-zinc-300 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ],
            else: [
              "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
              "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
              @errors == [] && "border-zinc-300 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]
        }
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
      <.help :if={@help} text={@help} class="mt-2" />
    </div>
    """
  end

  def input(%{type: "range"} = assigns) do
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
      <.label :if={@label} for={@id} required={@required}><%= @label %></.label>
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
      <.error :for={msg <- @errors}><%= msg %></.error>
      <.help :if={@help} text={@help} class="mt-2" />
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <div :if={@description?} id={@id <> "_description"} class="mt-2 text-sm leading-6 text-zinc-600">
        <%= render_slot(@description_block) %>
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
              "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
              "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
              @errors == [] && "border-zinc-300 focus:border-zinc-400",
              @errors != [] && "border-rose-400 focus:border-rose-400"
            ]
        }
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
      <.help :if={@help} text={@help} class="mt-2" />
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      <%= render_slot(@inner_block) %>
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
    <p class={["text-gray-500", @class]}><%= @text %></p>
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
          <%= render_slot(@inner_block) %>
        </h1>
        <p :if={@subtitle != []} class="mt-2 text-sm leading-6 text-zinc-600">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="flex-none"><%= render_slot(@actions) %></div>
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

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-y-auto px-4 sm:overflow-visible sm:px-0">
      <table class="w-[40rem] mt-11 sm:w-full">
        <thead class="text-sm text-left leading-6 text-zinc-500">
          <tr>
            <th :for={col <- @col} class="p-0 pr-6 pb-4 font-normal"><%= col[:label] %></th>
            <th class="relative p-0 pb-4"><span class="sr-only"><%= gettext("Actions") %></span></th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="relative divide-y divide-zinc-100 border-t border-zinc-200 text-sm leading-6 text-zinc-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="group hover:bg-zinc-50">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={["relative p-0", @row_click && "hover:cursor-pointer"]}
            >
              <div class="block py-4 pr-6">
                <span class="absolute -inset-y-px right-0 -left-4 group-hover:bg-zinc-50 sm:rounded-l-xl" />
                <span class={["relative", i == 0 && "font-semibold text-zinc-900"]}>
                  <%= render_slot(col, @row_item.(row)) %>
                </span>
              </div>
            </td>
            <td :if={@action != []} class="relative w-14 p-0">
              <div class="relative whitespace-nowrap py-4 text-right text-sm font-medium">
                <span class="absolute -inset-y-px -right-4 left-0 group-hover:bg-zinc-50 sm:rounded-r-xl" />
                <span
                  :for={action <- @action}
                  class="relative ml-4 font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
                >
                  <%= render_slot(action, @row_item.(row)) %>
                </span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
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
          <dt class="w-1/4 flex-none text-zinc-500"><%= item.title %></dt>
          <dd class="text-zinc-700"><%= render_slot(item) %></dd>
        </div>
      </dl>
    </div>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-16">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" />
        <%= render_slot(@inner_block) %>
      </.link>
    </div>
    """
  end

  attr :navigate, :any, required: true
  attr :nav_title, :string, required: true
  slot :inner_block, required: true

  def info_banner(assigns) do
    ~H"""
    <div class="rounded-md bg-brand-50 p-4 mt-8">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg
            class="h-5 w-5 text-brand-400"
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
          <p class="text-sm text-brand-700"><%= render_slot(@inner_block) %></p>
          <p class="mt-3 text-sm md:ml-6 md:mt-0">
            <.link
              navigate={@navigate}
              class="whitespace-nowrap font-medium text-brand-700 hover:text-brand-600"
            >
              <%= @nav_title %>
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

  def avatar(assigns) do
    ~H"""
    <%= if src_blank?(@src) && (!@name || @name == "") do %>
      <img
        class={if @class == "", do: "inline-block #{@size} rounded-md bg-zinc-100", else: @class}
        src={~p"/images/logo.svg"}
        alt="Metamorphic egg logo"
      />
    <% else %>
      <%= if src_blank?(@src) && @name do %>
        <span class={
          if @class == "",
            do:
              "inline-flex #{@size} items-center justify-center overflow-hidden rounded-md bg-zinc-100",
            else: "inline-flex #{@class} #{@size} items-center justify-center overflow-hidden"
        }>
          <span class={"text-#{@text_size} font-thin leading-none"}>
            <%= generate_initials(@name) %>
          </span>
        </span>
      <% else %>
        <img
          class={if @class == "", do: "inline-block #{@size} rounded-full bg-zinc-100", else: @class}
          src={@src}
          alt={@alt}
        />
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

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  def icon(%{name: "fa-user-robot"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class={@class} fill="currentColor" viewBox="0 0 448 512">
        <path d="M17.99986,256H48V128H17.99986A17.9784,17.9784,0,0,0,0,146v92A17.97965,17.97965,0,0,0,17.99986,256Zm412-128H400V256h29.99985A17.97847,17.97847,0,0,0,448,238V146A17.97722,17.97722,0,0,0,429.99985,128ZM116,320H332a36.0356,36.0356,0,0,0,36-36V109a44.98411,44.98411,0,0,0-45-45H241.99985V18a18,18,0,1,0-36,0V64H125a44.98536,44.98536,0,0,0-45,45V284A36.03685,36.03685,0,0,0,116,320Zm188-48H272V240h32ZM288,128a32,32,0,1,1-32,32A31.99658,31.99658,0,0,1,288,128ZM208,240h32v32H208Zm-32,32H144V240h32ZM160,128a32,32,0,1,1-32,32A31.99658,31.99658,0,0,1,160,128ZM352,352H96A95.99975,95.99975,0,0,0,0,448v32a32.00033,32.00033,0,0,0,32,32h96V448a31.99908,31.99908,0,0,1,32-32H288a31.99908,31.99908,0,0,1,32,32v64h96a32.00033,32.00033,0,0,0,32-32V448A95.99975,95.99975,0,0,0,352,352ZM176,448a15.99954,15.99954,0,0,0-16,16v48h32V464A15.99954,15.99954,0,0,0,176,448Zm96,0a16,16,0,1,0,16,16A15.99954,15.99954,0,0,0,272,448Z" />
      </svg>
    </span>
    """
  end

  def icon(%{name: "fa-function"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class={@class} fill="currentColor" viewBox="0 0 640 512">
        <path d="M288.73 320c0-52.34 16.96-103.22 48.01-144.95 5.17-6.94 4.45-16.54-2.15-22.14l-24.69-20.98c-7-5.95-17.83-5.09-23.38 2.23C246.09 187.42 224 252.78 224 320c0 67.23 22.09 132.59 62.52 185.84 5.56 7.32 16.38 8.18 23.38 2.23l24.69-20.99c6.59-5.61 7.31-15.2 2.15-22.14-31.06-41.71-48.01-92.6-48.01-144.94zM224 16c0-8.84-7.16-16-16-16h-48C102.56 0 56 46.56 56 104v64H16c-8.84 0-16 7.16-16 16v48c0 8.84 7.16 16 16 16h40v128c0 13.2-10.8 24-24 24H16c-8.84 0-16 7.16-16 16v48c0 8.84 7.16 16 16 16h16c57.44 0 104-46.56 104-104V248h40c8.84 0 16-7.16 16-16v-48c0-8.84-7.16-16-16-16h-40v-64c0-13.2 10.8-24 24-24h48c8.84 0 16-7.16 16-16V16zm353.48 118.16c-5.56-7.32-16.38-8.18-23.38-2.23l-24.69 20.98c-6.59 5.61-7.31 15.2-2.15 22.14 31.05 41.71 48.01 92.61 48.01 144.95 0 52.34-16.96 103.23-48.01 144.95-5.17 6.94-4.45 16.54 2.15 22.14l24.69 20.99c7 5.95 17.83 5.09 23.38-2.23C617.91 452.57 640 387.22 640 320c0-67.23-22.09-132.59-62.52-185.84zm-54.17 231.9L477.25 320l46.06-46.06c6.25-6.25 6.25-16.38 0-22.63l-22.62-22.62c-6.25-6.25-16.38-6.25-22.63 0L432 274.75l-46.06-46.06c-6.25-6.25-16.38-6.25-22.63 0l-22.62 22.62c-6.25 6.25-6.25 16.38 0 22.63L386.75 320l-46.06 46.06c-6.25 6.25-6.25 16.38 0 22.63l22.62 22.62c6.25 6.25 16.38 6.25 22.63 0L432 365.25l46.06 46.06c6.25 6.25 16.38 6.25 22.63 0l22.62-22.62c6.25-6.25 6.25-16.38 0-22.63z" />
      </svg>
    </span>
    """
  end

  def icon(%{name: "fa-code-branch"} = assigns) do
    ~H"""
    <span class="align-middle">
      <svg xmlns="http://www.w3.org/2000/svg" class={@class} fill="currentColor" viewBox="0 0 384 512">
        <path d="M384 144c0-44.2-35.8-80-80-80s-80 35.8-80 80c0 36.4 24.3 67.1 57.5 76.8-.6 16.1-4.2 28.5-11 36.9-15.4 19.2-49.3 22.4-85.2 25.7-28.2 2.6-57.4 5.4-81.3 16.9v-144c32.5-10.2 56-40.5 56-76.3 0-44.2-35.8-80-80-80S0 35.8 0 80c0 35.8 23.5 66.1 56 76.3v199.3C23.5 365.9 0 396.2 0 432c0 44.2 35.8 80 80 80s80-35.8 80-80c0-34-21.2-63.1-51.2-74.6 3.1-5.2 7.8-9.8 14.9-13.4 16.2-8.2 40.4-10.4 66.1-12.8 42.2-3.9 90-8.4 118.2-43.4 14-17.4 21.1-39.8 21.6-67.9 31.6-10.8 54.4-40.7 54.4-75.9zM80 64c8.8 0 16 7.2 16 16s-7.2 16-16 16-16-7.2-16-16 7.2-16 16-16zm0 384c-8.8 0-16-7.2-16-16s7.2-16 16-16 16 7.2 16 16-7.2 16-16 16zm224-320c8.8 0 16 7.2 16 16s-7.2 16-16 16-16-7.2-16-16 7.2-16 16-16z" />
      </svg>
    </span>
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

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
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

  def hide_modal(js \\ %JS{}, id) do
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
      Gettext.dngettext(MetamorphicWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MetamorphicWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Render the raw content as markdown. Returns HTML rendered text.
  """
  def render_markdown(nil), do: Phoenix.HTML.raw(nil)

  def render_markdown(text) when is_binary(text) do
    # NOTE: This allows explicit HTML to come through.
    #   - Don't allow this with user input.
    text |> Earmark.as_html!(escape: false) |> Phoenix.HTML.raw()
  end

  @doc """
  Render a markdown containing web component.
  """
  attr :text, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def markdown(%{text: nil} = assigns), do: ~H""

  def markdown(assigns) do
    ~H"""
    <div class={["prose dark:prose-invert", @class]} {@rest}><%= render_markdown(@text) %></div>
    """
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
              <%= render_slot(title) %>
            <% end %>
          </h3>
          <%= for description <- @description do %>
            <p class="text-sm text-gray-500">
              <div class="mt-1 max-w-2xl text-sm text-gray-500">
                <%= render_slot(description) %>
              </div>
            </p>
          <% end %>

          <%= for inner_block <- @inner_block do %>
            <div class="mt-1 max-w-2xl text-sm text-gray-500">
              <%= render_slot(inner_block) %>
            </div>
          <% end %>
        </div>
        <%= for right <- @right do %>
          <%= render_slot(right) %>
        <% end %>
      </div>
      <%= for links <- @links do %>
        <div class="mt-2 text-sm">
          <%= render_slot(links) %>
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
        class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 px-4 rounded-full"
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
        String.downcase(initial1 <> initial2)
      end
    end
  end

  defp generate_initials(_) do
    ""
  end
end
