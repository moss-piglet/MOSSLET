defmodule MossletWeb.GroupLive.GroupMessages do
  use MossletWeb, :html
  alias MossletWeb.ChatComponents
  alias Mosslet.Groups

  @mention_token_regex ~r/@\[([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]/i

  def list_messages(assigns) do
    ~H"""
    <div
      id="messages-container"
      class="flex-1 overflow-y-auto min-h-0 px-3 sm:px-4 lg:px-6 py-4"
      phx-hook="ScrollDown"
      data-scrolled-to-top={@scrolled_to_top}
      style="scrollbar-width: thin; scrollbar-color: rgb(20 184 166 / 0.5) transparent;"
      tabindex="0"
      role="log"
      aria-label="Chat messages"
    >
      <div class="max-w-4xl mx-auto">
        <div id="infinite-scroll-marker" phx-hook="InfiniteScrollGroupMessage"></div>
        <div id="messages" phx-update="stream" class="space-y-1">
          <div :for={{dom_id, message} <- @messages} id={dom_id}>
            <.message_details
              message={message}
              current_scope={@current_scope}
              user_group_key={@user_group_key}
              group={@group}
              user_group={@user_group}
              messages_list={@messages_list}
              current_page={@current_page}
              viewer_sealed_org_key={@viewer_sealed_org_key}
              org_display_names={@org_display_names}
              org_avatars={@org_avatars}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :message, :map, required: true
  attr :current_scope, :map, required: true
  attr :user_group_key, :string, required: true
  attr :group, :map, required: true
  attr :user_group, :map, required: true
  attr :messages_list, :list, required: true
  attr :current_page, :atom, default: nil
  attr :viewer_sealed_org_key, :string, default: nil
  attr :org_display_names, :map, default: %{}
  attr :org_avatars, :map, default: %{}

  def message_details(assigns) do
    decrypted = Map.get(assigns.message, :decrypted, %{})

    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.message.sender_id),
        assigns.current_scope.user
      )

    is_self = assigns.user_group.id == assigns.message.sender_id
    is_connected = not is_nil(uconn)
    is_own_message = is_self
    browser_decrypt? = decrypted[:browser_decrypt?] || false

    # Avatar resolution: connection avatar > group avatar > fallback logo
    # For non-public groups, group avatar is encrypted — pass blob for browser decrypt.
    # For public groups, group avatar is server-decrypted into a path.
    group_avatar_path =
      if browser_decrypt? do
        # Group avatar_img will be decrypted browser-side; use default for SSR placeholder
        ~p"/images/groups/default.png"
      else
        case decrypted[:avatar_img] do
          img when is_binary(img) and img != "" -> ~p"/images/groups/#{img}"
          _ -> ~p"/images/groups/default.png"
        end
      end

    {avatar_src, encrypted_avatar} =
      cond do
        is_self ->
          {nil, nil}

        uconn ->
          case get_encrypted_avatar_data(uconn, assigns.current_scope.key) do
            nil -> {group_avatar_path, nil}
            data -> {nil, data}
          end

        true ->
          {group_avatar_path, nil}
      end

    sender_name =
      cond do
        is_self ->
          maybe_decr_username_for_user_group(
            assigns.message.sender.user_id,
            assigns.current_scope.user,
            assigns.current_scope.key
          )

        is_connected ->
          maybe_decr_username_for_user_group(
            assigns.message.sender.user_id,
            assigns.current_scope.user,
            assigns.current_scope.key
          )

        true ->
          nil
      end

    # Moniker: for non-public groups, nil placeholder (browser decrypts).
    # For public groups, server-decrypted value.
    moniker = decrypted[:moniker] || "member"

    # Org-scoped ZK display name (Task #283): for org-backed circles, surface an
    # org-mate's recognizable persona next to their per-circle moniker when the
    # viewer has no personal connection (so the moniker isn't the only handle).
    # Ciphertext only — the browser decrypts it with the viewer's sealed org_key.
    encrypted_org_display_name =
      if browser_decrypt? and not is_self and not is_connected do
        Map.get(assigns[:org_display_names] || %{}, assigns.message.sender.user_id)
      end

    # Org-scoped ZK display AVATAR (Task #277): companion to the org display
    # name above. For a non-connected org-mate, the browser decrypts their org
    # avatar (org_key-secretbox) and fills the header <img>; if they haven't set
    # one, it falls back to initials derived from their decrypted org name (never
    # the personal avatar — that stays sealed to conn_key, persona separation).
    encrypted_org_avatar =
      if browser_decrypt? and not is_self and not is_connected do
        Map.get(assigns[:org_avatars] || %{}, assigns.message.sender.user_id)
      end

    sealed_org_key = assigns[:viewer_sealed_org_key]

    # For non-public groups, content is nil (browser decrypts via hook).
    # For public groups, content is pre-decrypted by the server.
    raw_content = decrypted[:content]

    variant = MossletWeb.GroupLive.ChatSupport.mention_variant(assigns.current_page)

    {content, _can_check_mentions} =
      if browser_decrypt? do
        # Content will be decrypted and rendered by the DecryptGroupMessage hook
        {nil, false}
      else
        markdown_html = Mosslet.MarkdownRenderer.to_html(raw_content)
        rendered = render_mentions(markdown_html, assigns, is_own_message, variant)
        {rendered, true}
      end

    can_delete =
      assigns.user_group.role in [:owner, :admin, :moderator] || is_own_message

    is_grouped = Map.get(assigns.message, :is_grouped, false)
    show_date_separator = Map.get(assigns.message, :show_date_separator, false)
    message_datetime = assigns.message.inserted_at

    # Mention highlight is server-authoritative (mention records), set upstream in
    # ChatSupport for both the initial load and realtime paths. This works for
    # ZK circles where the @[id] token is sealed inside the ciphertext.
    is_new_mention = Map.get(assigns.message, :is_new_mention, false)
    is_mentioned = is_new_mention

    assigns =
      assigns
      |> assign(:avatar_src, avatar_src)
      |> assign(:encrypted_avatar, encrypted_avatar)
      |> assign(:sender_name, sender_name)
      |> assign(:moniker, moniker)
      |> assign(:encrypted_moniker, decrypted[:encrypted_moniker])
      |> assign(:encrypted_avatar_img, decrypted[:encrypted_avatar_img])
      |> assign(:content, content)
      |> assign(:can_delete, can_delete)
      |> assign(:is_own_message, is_own_message)
      |> assign(:is_grouped, is_grouped)
      |> assign(:show_date_separator, show_date_separator)
      |> assign(:message_datetime, message_datetime)
      |> assign(:is_mentioned, is_mentioned)
      |> assign(:is_new_mention, is_new_mention)
      |> assign(:browser_decrypt?, browser_decrypt?)
      |> assign(:encrypted_content, decrypted[:encrypted_content])
      |> assign(:sealed_group_key, decrypted[:sealed_group_key])
      |> assign(:current_user_group_id, assigns.user_group.id)
      |> assign(:mention_variant, variant)
      |> assign(:encrypted_org_display_name, encrypted_org_display_name)
      |> assign(:encrypted_org_avatar, encrypted_org_avatar)
      |> assign(:sealed_org_key, sealed_org_key)

    ~H"""
    <ChatComponents.liquid_chat_message
      id={@message.id}
      avatar_src={@avatar_src}
      encrypted_avatar_data={@encrypted_avatar}
      avatar_alt="circle member avatar"
      sender_name={@sender_name}
      moniker={@moniker}
      org_display_name_decrypt?={not is_nil(@encrypted_org_display_name)}
      role={@message.sender.role}
      timestamp={@message.inserted_at}
      is_own_message={@is_own_message}
      can_delete={@can_delete}
      on_delete="delete_message"
      is_grouped={@is_grouped}
      show_date_separator={@show_date_separator}
      message_datetime={@message_datetime}
      is_mentioned={@is_mentioned}
      is_new_mention={@is_new_mention}
    >
      <div
        :if={@browser_decrypt?}
        id={"decrypt-msg-#{@message.id}"}
        phx-hook="DecryptGroupMessage"
        data-encrypted-content={@encrypted_content}
        data-sealed-group-key={@sealed_group_key}
        data-encrypted-moniker={@encrypted_moniker}
        data-encrypted-avatar-img={@encrypted_avatar_img}
        data-encrypted-org-display-name={@encrypted_org_display_name}
        data-encrypted-org-avatar={@encrypted_org_avatar}
        data-sealed-org-key={@sealed_org_key}
        data-current-user-group-id={@current_user_group_id}
        data-is-own-message={to_string(@is_own_message)}
        data-mention-variant={@mention_variant}
      >
        <span class="text-slate-400 dark:text-slate-500 text-sm italic">Decrypting...</span>
      </div>
      <div :if={not @browser_decrypt?}>
        {@content |> Phoenix.HTML.raw()}
      </div>
    </ChatComponents.liquid_chat_message>
    """
  end

  defp render_mentions(content, assigns, is_own_message, variant) when is_binary(content) do
    Regex.replace(@mention_token_regex, content, fn _full, user_group_id ->
      render_mention_pill(user_group_id, assigns, is_own_message, variant)
    end)
  end

  defp render_mentions(content, _assigns, _is_own_message, _variant), do: content

  defp render_mention_pill(user_group_id, assigns, is_own_message, variant) do
    is_self = user_group_id == assigns.user_group.id

    case Groups.get_user_group(user_group_id) do
      nil ->
        ~s(<span class="#{mention_pill_class(variant, is_own_message, false)}"><span class="opacity-60">@</span>unknown</span>)

      mentioned_ug ->
        mentioned_user = get_user_from_user_group_id(user_group_id)
        uconn = get_uconn_for_users(mentioned_user, assigns.current_scope.user)
        is_connected = not is_nil(uconn)

        display_name =
          cond do
            is_self ->
              maybe_decr_username_for_user_group(
                mentioned_ug.user_id,
                assigns.current_scope.user,
                assigns.current_scope.key
              )

            is_connected ->
              maybe_decr_username_for_user_group(
                mentioned_ug.user_id,
                assigns.current_scope.user,
                assigns.current_scope.key
              )

            true ->
              decr_item(
                mentioned_ug.moniker,
                assigns.current_scope.user,
                assigns.user_group.key,
                assigns.current_scope.key,
                assigns.group
              )
          end

        ~s(<span class="#{mention_pill_class(variant, is_own_message, is_self)}"><span class="opacity-60">@</span>#{display_name}</span>)
    end
  end

  # Shared base shape — a real, visually distinct chip.
  defp mention_pill_base do
    "mention inline-flex items-baseline rounded-md px-1.5 py-0.5 font-medium leading-tight transition-colors"
  end

  # Inside an own-message bubble (teal gradient, white text) a light-on-color
  # pill is the only legible choice regardless of surface.
  defp mention_pill_class(_variant, true, is_self) do
    base = "#{mention_pill_base()} bg-white/20 text-white"
    if is_self, do: base <> " ring-1 ring-white/40 font-semibold", else: base
  end

  defp mention_pill_class(variant, false, is_self) do
    "#{mention_pill_base()} #{mention_pill_theme(variant, is_self)}"
  end

  defp mention_pill_theme("family", false),
    do: "bg-rose-100/70 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300"

  defp mention_pill_theme("family", true),
    do:
      "bg-rose-200/80 text-rose-800 ring-1 ring-rose-400/50 font-semibold dark:bg-rose-500/25 dark:text-rose-200 dark:ring-rose-400/40"

  defp mention_pill_theme("business", false),
    do: "bg-indigo-100/70 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-300"

  defp mention_pill_theme("business", true),
    do:
      "bg-indigo-200/80 text-indigo-800 ring-1 ring-indigo-400/50 font-semibold dark:bg-indigo-500/25 dark:text-indigo-200 dark:ring-indigo-400/40"

  defp mention_pill_theme(_personal, false),
    do: "bg-teal-100/70 text-teal-700 dark:bg-teal-500/15 dark:text-teal-300"

  defp mention_pill_theme(_personal, true),
    do:
      "bg-teal-200/80 text-teal-800 ring-1 ring-teal-400/50 font-semibold dark:bg-teal-500/25 dark:text-teal-200 dark:ring-teal-400/40"
end
