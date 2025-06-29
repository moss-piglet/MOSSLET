defmodule MossletWeb.MemoryLive.MemoryRemarks do
  use MossletWeb, :html
  import MossletWeb.CoreComponents

  def list_remarks(assigns) do
    ~H"""
    <div
      id="remarks"
      phx-update="stream"
      class="overflow-y-auto"
      style="height: calc(88vh - 15rem)"
      phx-hook="ScrollDown"
      data-scrolled-to-top={@scrolled_to_top}
    >
      <div id="infinite-scroll-marker" phx-hook="InfiniteScroll"></div>
      <div
        :for={{dom_id, remark} <- @remarks}
        id={dom_id}
        class="px-2 mt-2 hover:bg-emerald-100 hover:rounded-md remarks"
        phx-hook="HoverGroupMessage"
        data-toggle={JS.toggle(to: "#remark-#{remark.id}-buttons")}
      >
        <.remark_details
          remark={remark}
          current_user={@current_user}
          user_group_key={@user_group_key}
          group={@group}
          key={@key}
          user_group={@user_group}
        />
      </div>
    </div>
    """
  end

  def remark_details(assigns) do
    ~H"""
    <.remark_meta
      remark={@remark}
      current_user={@current_user}
      user_group={@user_group}
      group={@group}
      key={@key}
    />
    <.remark_content
      remark={@remark}
      current_user={@current_user}
      user_group_key={@user_group_key}
      group={@group}
      key={@key}
    />
    """
  end

  def remark_meta(assigns) do
    ~H"""
    <div class="relative mt-6 flex flex-col justify-between text-sm leading-6">
      <div class="py-2 inline-flex">
        <.avatar
          :if={@user_group.id != @remark.sender_id}
          src={
            get_user_avatar(
              get_uconn_for_users(
                get_user_from_user_group_id(@remark.sender_id),
                @current_user
              ),
              @key
            )
          }
          alt=""
          class="relative z-30 inline-block h-6 w-6 rounded-full ring-2 ring-white"
        />
        <.avatar
          :if={@user_group.id == @remark.sender_id}
          src={maybe_get_user_avatar(@current_user, @key)}
          alt=""
          class="relative z-30 inline-block h-6 w-6 rounded-full ring-2 ring-white"
        />

        <div class="pl-2 inline-flex text-[0.9rem] text-gray-900 font-medium">
          <span :if={@remark.sender.name} class="truncate w-1/4 sm:w-3/4 md:w-full">
            {initials(decr_item(@remark.sender.name, @current_user, @user_group.key, @key, @group))}

            <span class="text-emerald-600 text-xs">
              <.icon name="hero-finger-print" class="h-4 w-4" />{decr_item(
                @remark.sender.moniker,
                @current_user,
                @user_group.key,
                @key,
                @group
              )}
            </span>
          </span>
          <span :if={!@remark.sender.name} class="truncate w-1/4 sm:w-3/4 md:w-full">
            {maybe_decr_username_for_user_group(@remark.sender.user_id, @current_user, @key)}
          </span>
          <div class="absolute right-4 top-3 text-xs font-light text-gray-500">
            <.local_time_ago id={@remark.id <> "-created"} at={@remark.inserted_at} />
          </div>
          <.delete_icon
            :if={@user_group.role in [:owner, :admin, :moderator]}
            id={"remark-#{@remark.id}-buttons"}
            phx_click="delete_remark"
            value={@remark.id}
          />
        </div>
      </div>
    </div>
    """
  end

  def remark_content(assigns) do
    ~H"""
    <div class="-my-4 divide-y divide-zinc-100">
      <div class="flex gap-4 py-4 sm:gap-2">
        <div class="text-sm text-gray-500" style="margin-left: 3%;margin-top: -1%;">
          {decr_item(@remark.content, @current_user, @user_group_key, @key, @group)}
        </div>
      </div>
    </div>
    """
  end
end
