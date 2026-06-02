defmodule MossletWeb.MediaComponents do
  @moduledoc """
  Media components for uploads, galleries, and image handling.

  Extracted from `MossletWeb.DesignSystem` as part of the design system
  modularization (Phase 1).
  """
  use Phoenix.Component
  use MossletWeb, :verified_routes

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  import MossletWeb.Helpers,
    only: [
      photos?: 1,
      get_encrypted_avatar_data: 2,
      get_encrypted_banner_data: 2
    ]

  alias Phoenix.LiveView.JS

  # Helper function to humanize upload errors
  defp humanize_upload_error(:too_large), do: "File is too large (max 10MB)"
  defp humanize_upload_error(:too_many_files), do: "Too many files (max 10 photos)"

  defp humanize_upload_error(:not_accepted),
    do: "File type not supported (GIF, JPG, PNG, WEBP, HEIC/HEIF only)"

  defp humanize_upload_error(error), do: "Upload error: #{error}"

  # Helper function to humanize upload errors with additional argument
  defp humanize_upload_error(:too_large, _max_size), do: "File is too large (max 10MB)"

  defp humanize_upload_error(:too_many_files, max_entries),
    do: "Too many files (max #{max_entries} photos)"

  defp humanize_upload_error(:not_accepted, _rest),
    do: "File type not supported (GIF, JPG, PNG, WEBP, HEIC/HEIF only)"

  defp humanize_upload_error(error, _rest), do: "Upload error: #{error}"

  @doc """
  Liquid metal photo gallery component for timeline posts.
  Integrates with existing TrixContentPostHook and encrypted image system.
  """
  attr :post, :any, required: true
  attr :current_scope, :map, default: nil, doc: "the scope containing user and key (preferred)"
  attr :class, :any, default: ""

  def liquid_post_photo_gallery(assigns) do
    assigns = MossletWeb.DesignSystem.assign_scope_fields(assigns)
    image_count = length(assigns.post.image_urls)

    grid_class =
      cond do
        image_count == 1 -> "grid-cols-6"
        image_count == 2 -> "grid-cols-6"
        image_count <= 4 -> "grid-cols-6"
        image_count <= 6 -> "grid-cols-6 sm:grid-cols-8"
        true -> "grid-cols-6 sm:grid-cols-8 lg:grid-cols-10"
      end

    assigns = assign(assigns, :grid_class, grid_class)
    assigns = assign(assigns, :image_count, image_count)

    ~H"""
    <div
      :if={photos?(@post.image_urls)}
      id={"photo-gallery-#{@post.id}"}
      class={[
        "mt-3 overflow-hidden rounded-lg border border-slate-200/60 dark:border-slate-700/60",
        "bg-slate-50/50 dark:bg-slate-800/30",
        @class
      ]}
    >
      <div
        id={"post-body-#{@post.id}"}
        phx-hook="TrixContentPostHook"
        class="photos-container p-2"
        data-image-count={@image_count}
        data-grid-class={@grid_class}
      >
        <div class={"grid #{@grid_class} gap-1.5"}>
          <div
            :for={{_image_url, index} <- Enum.with_index(@post.image_urls)}
            class="group relative overflow-hidden rounded-md bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-800"
            style={"animation-delay: #{index * 100}ms"}
          >
            <div class="aspect-square flex items-center justify-center">
              <div class="relative">
                <div class="w-6 h-6 rounded-full bg-slate-200/80 dark:bg-slate-600/80 flex items-center justify-center">
                  <.phx_icon
                    name="hero-photo"
                    class="h-3 w-3 text-slate-400 dark:text-slate-500"
                  />
                </div>
                <div class="absolute inset-0 rounded-full border-2 border-transparent border-t-emerald-500/30 animate-spin opacity-0 group-[.photos-loading]:opacity-100 transition-opacity duration-300">
                </div>
              </div>
            </div>
            <div class="absolute bottom-1 right-1 px-1 py-0.5 rounded text-[10px] bg-black/30 text-white font-medium backdrop-blur-sm">
              {index + 1}/{@image_count}
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-between px-2.5 py-1.5">
        <div class="flex items-center gap-2">
          <div class="flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
            <.phx_icon name="hero-photo" class="h-3.5 w-3.5" />
            <span>{@image_count} {if @image_count == 1, do: "photo", else: "photos"}</span>
          </div>
          <span
            :if={@post.ai_generated}
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[10px] font-medium bg-violet-500/10 text-violet-600 dark:text-violet-400"
          >
            <.phx_icon name="hero-sparkles" class="h-2.5 w-2.5" /> AI
          </span>
        </div>

        <button
          id={"post-#{@post.id}-show-photos-#{@current_scope.user.id}"}
          class="group inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-all duration-200 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-500/20 active:scale-[0.97]"
          phx-click={
            JS.add_class("photos-loading", to: "#post-body-#{@post.id}")
            |> JS.dispatch("mosslet:show-post-photos-#{@post.id}",
              to: "#post-body-#{@post.id}",
              detail: %{post_id: @post.id, user_id: @current_scope.user.id}
            )
            |> JS.hide(to: "#post-#{@post.id}-show-photos-#{@current_scope.user.id}")
            |> JS.show(to: "#post-#{@post.id}-loading-indicator", display: "inline-flex")
          }
          phx-hook="TippyHook"
          data-tippy-content="Decrypt and display photos"
        >
          <.phx_icon name="hero-eye" class="h-3.5 w-3.5" />
          <span>View</span>
        </button>

        <div
          id={"post-#{@post.id}-loading-indicator"}
          style="display: none;"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400"
        >
          <svg
            class="animate-spin h-3 w-3 text-emerald-500"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
            </circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            >
            </path>
          </svg>
          <span>Decrypting...</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Enhanced photo upload preview with liquid metal styling for the composer.
  Shows real processing stages: receiving, validating, processing, uploading, ready.
  """
  attr :uploads, :any, required: true
  attr :upload_stages, :map, default: %{}
  attr :completed_uploads, :list, default: []
  attr :class, :any, default: ""

  def liquid_photo_upload_preview(assigns) do
    ~H"""
    <div
      :if={
        (@uploads && @uploads.photos && @uploads.photos.entries != []) ||
          @completed_uploads != []
      }
      class={[
        "mt-4 p-4 rounded-xl border border-slate-200/60 dark:border-slate-700/60",
        "bg-gradient-to-br from-emerald-50/30 to-teal-50/20 dark:from-emerald-900/10 dark:to-teal-900/5",
        @class
      ]}
    >
      <% total_count = length(@uploads.photos.entries) + length(@completed_uploads) %>
      <% entries_count = length(@uploads.photos.entries) %>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <.phx_icon
            name="hero-cloud-arrow-up"
            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
          />
          <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
            {total_count} {if total_count == 1, do: "photo", else: "photos"}
          </span>
        </div>

        <div class="text-xs font-medium">
          <%= cond do %>
            <% entries_count == 0 and @completed_uploads != [] -> %>
              <span class="text-emerald-600 dark:text-emerald-400">✓ Ready to post</span>
            <% all_ready?(@uploads.photos.entries, @upload_stages) and entries_count > 0 -> %>
              <span class="text-emerald-600 dark:text-emerald-400">✓ Ready to post</span>
            <% any_error?(@uploads.photos.entries, @upload_stages) -> %>
              <span class="text-red-500">
                {get_first_error_reason(@uploads.photos.entries, @upload_stages)}
              </span>
            <% entries_count > 0 -> %>
              <span class="text-amber-600 dark:text-amber-400">Processing...</span>
            <% true -> %>
              <span class="text-emerald-600 dark:text-emerald-400">✓ Ready to post</span>
          <% end %>
        </div>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
        <%!-- Show completed uploads first --%>
        <%= for upload <- @completed_uploads do %>
          <div class="relative group overflow-hidden rounded-lg border border-emerald-200/60 dark:border-emerald-700/60 bg-white dark:bg-slate-800">
            <%= if upload[:preview_data_url] do %>
              <img
                src={upload.preview_data_url}
                alt={upload[:alt_text] || "Completed upload preview #{upload.ref}"}
                class="w-full h-24 object-cover transition-all duration-200 group-hover:scale-105"
              />
            <% else %>
              <div class="w-full h-24 bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center">
                <.phx_icon name="hero-photo" class="h-8 w-8 text-emerald-500 dark:text-emerald-400" />
              </div>
            <% end %>

            <div class="absolute top-1 left-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
              <.phx_icon name="hero-check" class="h-3 w-3 text-white" />
            </div>

            <button
              type="button"
              id={"remove-completed-photo-#{upload.ref}"}
              phx-click="remove_completed_upload"
              phx-value-ref={upload.ref}
              aria-label="Remove photo"
              class="absolute top-1 right-1 z-10 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove photo"
            >
              <.phx_icon name="hero-x-mark" class="h-3 w-3" />
            </button>

            <div class="absolute bottom-7 left-1 right-1 z-10 flex items-center justify-between">
              <button
                type="button"
                id={"edit-alt-photo-#{upload.ref}"}
                phx-click="open_alt_text_modal"
                phx-value-ref={upload.ref}
                aria-label="Edit alt text"
                class={[
                  "px-1.5 py-0.5 rounded text-[10px] font-bold flex items-center gap-0.5",
                  "transition-all duration-200 hover:scale-105",
                  if(upload[:alt_text] && upload[:alt_text] != "",
                    do: "bg-emerald-500 text-white",
                    else: "bg-slate-800 text-white hover:bg-slate-700"
                  )
                ]}
                phx-hook="TippyHook"
                data-tippy-content={
                  if(upload[:alt_text] && upload[:alt_text] != "",
                    do: "Edit alt text: #{String.slice(upload[:alt_text] || "", 0..30)}...",
                    else: "Add alt text for accessibility"
                  )
                }
              >
                <.phx_icon
                  :if={!(upload[:alt_text] && upload[:alt_text] != "")}
                  name="hero-plus"
                  class="h-2.5 w-2.5"
                /> ALT
              </button>

              <button
                type="button"
                id={"edit-image-#{upload.ref}"}
                phx-click="open_image_edit_modal"
                phx-value-ref={upload.ref}
                aria-label="Edit image"
                class={[
                  "w-6 h-5 rounded flex items-center justify-center",
                  "transition-all duration-200 hover:scale-105",
                  if(upload[:crop] && upload[:crop] != %{},
                    do: "bg-sky-500 text-white",
                    else: "bg-slate-800 text-white hover:bg-slate-700"
                  )
                ]}
                phx-hook="TippyHook"
                data-tippy-content={
                  if(upload[:crop] && upload[:crop] != %{},
                    do: "Edit crop",
                    else: "Crop image"
                  )
                }
              >
                <.phx_icon name="hero-pencil" class="h-3 w-3" />
              </button>
            </div>

            <div class="absolute bottom-0 left-0 right-0 bg-black/50 px-2 py-1 text-xs text-white truncate">
              {upload.client_name}
            </div>
          </div>
        <% end %>

        <%!-- Show in-progress entries (excluding completed ones) --%>
        <% completed_refs = Enum.map(@completed_uploads, & &1.ref) %>
        <%= for entry <- @uploads.photos.entries, entry.ref not in completed_refs do %>
          <% stage_info = Map.get(@upload_stages, entry.ref, {:receiving, 0}) %>
          <div class="relative group overflow-hidden rounded-lg border border-emerald-200/60 dark:border-emerald-700/60 bg-white dark:bg-slate-800">
            <.live_img_preview
              entry={entry}
              alt={"Photo upload preview #{entry.ref}"}
              class="w-full h-24 object-cover transition-all duration-200 group-hover:scale-105"
            />

            <%= cond do %>
              <% is_entry_error?(stage_info) -> %>
                <div class="absolute inset-0 bg-red-500/90 flex items-center justify-center p-2">
                  <div class="text-center">
                    <.phx_icon
                      name="hero-exclamation-triangle"
                      class="h-5 w-5 text-white mx-auto mb-1"
                    />
                    <div class="text-xs text-white font-medium">
                      {format_error(stage_info)}
                    </div>
                  </div>
                </div>
              <% is_entry_ready?(stage_info) -> %>
                <div class="absolute top-1 left-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
                  <.phx_icon name="hero-check" class="h-3 w-3 text-white" />
                </div>
              <% true -> %>
                <div class="absolute inset-0 bg-gradient-to-t from-black/70 to-black/20 flex flex-col items-center justify-center">
                  <div class="text-center">
                    <div class="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin mb-2 mx-auto">
                    </div>
                    <div class="text-xs text-white font-medium mb-1">
                      {stage_label(stage_info)}
                    </div>
                    <div class="w-16 h-1 bg-white/30 rounded-full overflow-hidden mx-auto">
                      <div
                        class="h-full bg-emerald-400 transition-all duration-300"
                        style={"width: #{stage_progress(stage_info)}%"}
                      >
                      </div>
                    </div>
                  </div>
                </div>
            <% end %>

            <button
              type="button"
              id={"remove-photo-#{entry.ref}"}
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              aria-label="Remove photo"
              class="absolute top-1 right-1 z-10 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-100 sm:opacity-0 sm:group-hover:opacity-100 transition-all duration-200 hover:scale-110"
              phx-hook="TippyHook"
              data-tippy-content="Remove photo"
            >
              <.phx_icon name="hero-x-mark" class="h-3 w-3" />
            </button>

            <div
              :if={upload_errors(@uploads.photos, entry) != []}
              class="absolute inset-0 bg-red-500/90 flex items-center justify-center p-2"
            >
              <div class="text-center">
                <.phx_icon name="hero-exclamation-triangle" class="h-5 w-5 text-white mx-auto mb-1" />
                <div class="text-xs text-white font-medium">
                  <%= for error <- upload_errors(@uploads.photos, entry) do %>
                    <div>{humanize_upload_error(error, @uploads.photos.max_entries)}</div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div
        :if={upload_errors(@uploads.photos) != []}
        class="mt-3 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg"
      >
        <div class="flex items-start gap-2">
          <.phx_icon
            name="hero-exclamation-triangle"
            class="h-4 w-4 text-red-600 dark:text-red-400 mt-0.5 flex-shrink-0"
          />
          <div class="text-sm text-red-700 dark:text-red-300">
            <%= for error <- upload_errors(@uploads.photos) do %>
              <div>{humanize_upload_error(error, @uploads.photos.max_entries)}</div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp all_ready?(entries, upload_stages) do
    Enum.all?(entries, fn entry ->
      case Map.get(upload_stages, entry.ref) do
        {:ready, _} -> true
        _ -> false
      end
    end)
  end

  defp any_error?(entries, upload_stages) do
    Enum.any?(entries, fn entry ->
      case Map.get(upload_stages, entry.ref) do
        {:error, _} -> true
        _ -> false
      end
    end)
  end

  defp is_entry_ready?({:ready, _}), do: true
  defp is_entry_ready?(_), do: false

  defp is_entry_error?({:error, _}), do: true
  defp is_entry_error?(_), do: false

  defp get_first_error_reason(entries, upload_stages) do
    Enum.find_value(entries, "Error processing", fn entry ->
      case Map.get(upload_stages, entry.ref) do
        {:error, {:nsfw, details}} when is_map(details) ->
          categories = Map.get(details, :flagged_categories, [])

          if categories != [],
            do: "Content flagged: #{Enum.join(categories, ", ")}",
            else: "Content not allowed"

        {:error, {:nsfw, reason}} ->
          "#{reason}"

        {:error, reason} when is_binary(reason) ->
          reason

        {:error, _} ->
          "Upload failed"

        _ ->
          nil
      end
    end)
  end

  defp format_error({:error, {:nsfw, _}}), do: "Content not allowed"
  defp format_error({:error, reason}) when is_binary(reason), do: reason
  defp format_error({:error, _}), do: "Upload failed"
  defp format_error(_), do: ""

  defp stage_label({:receiving, _}), do: "Receiving..."
  defp stage_label({:validating, _}), do: "Checking..."
  defp stage_label({:processing, _}), do: "Processing..."
  defp stage_label({:uploading, _}), do: "Uploading..."
  defp stage_label(_), do: "Processing..."

  @doc """
  Modal for editing image alt text with accessibility-focused design.
  """
  attr :show, :boolean, default: false
  attr :upload, :map, default: nil
  attr :alt_text, :string, default: ""
  attr :on_close, JS, default: %JS{}
  attr :id, :string, default: "alt-text-modal"

  def liquid_alt_text_modal(assigns) do
    ~H"""
    <div
      :if={@show && @upload}
      id={@id}
      class="fixed inset-0 z-[70] flex items-center justify-center p-4"
      phx-window-keydown="close_alt_text_modal"
      phx-key="Escape"
    >
      <div
        class="fixed inset-0 bg-slate-900/60 dark:bg-slate-950/80 backdrop-blur-sm"
        phx-click="close_alt_text_modal"
      >
      </div>

      <div class="relative w-full max-w-lg max-h-[90vh] overflow-y-auto bg-white dark:bg-slate-800 rounded-2xl shadow-2xl border border-slate-200/60 dark:border-slate-700/60">
        <div class="absolute inset-0 bg-gradient-to-br from-teal-50/30 via-emerald-50/20 to-cyan-50/30 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 pointer-events-none">
        </div>

        <div class="relative p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-2">
              <.phx_icon
                name="hero-eye"
                class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
              />
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Image Description
              </h2>
            </div>
            <button
              type="button"
              phx-click="close_alt_text_modal"
              aria-label="Close"
              class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700/50 transition-all"
            >
              <.phx_icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>

          <div class="mb-4">
            <%= cond do %>
              <% @upload[:preview_data_url] -> %>
                <img
                  src={@upload.preview_data_url}
                  alt="Preview"
                  class="w-full max-h-40 object-contain rounded-lg bg-slate-100 dark:bg-slate-700/50"
                />
              <% @upload[:entry] -> %>
                <.live_img_preview
                  entry={@upload.entry}
                  class="w-full max-h-40 object-contain rounded-lg bg-slate-100 dark:bg-slate-700/50"
                />
              <% true -> %>
                <div class="w-full h-40 bg-slate-100 dark:bg-slate-700/50 rounded-lg flex items-center justify-center">
                  <.phx_icon name="hero-photo" class="h-12 w-12 text-slate-400" />
                </div>
            <% end %>
          </div>

          <form phx-submit="save_alt_text" class="space-y-4">
            <input type="hidden" name="ref" value={@upload[:ref]} />

            <div>
              <label
                for="alt-text-input"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
              >
                Alt text describes images for people who use readers, and helps provide context to everyone.
              </label>
              <textarea
                id="alt-text-input"
                name="alt_text"
                rows="3"
                maxlength="1000"
                placeholder="Add a description of the image..."
                class="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-400 resize-none transition-all"
                phx-hook="AutoFocus"
              ><%= @alt_text %></textarea>
              <p class="mt-1.5 text-xs text-slate-500 dark:text-slate-400">
                Good descriptions are concise and describe key visual elements. Max 1000 characters.
              </p>
            </div>

            <div class="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                phx-click="close_alt_text_modal"
                class="px-4 py-2.5 rounded-xl text-sm font-medium text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700/50 transition-all"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-5 py-2.5 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-teal-500 to-emerald-500 hover:from-teal-600 hover:to-emerald-600 shadow-lg shadow-emerald-500/25 hover:shadow-emerald-500/40 transition-all hover:scale-105 active:scale-95"
              >
                Save Description
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Modal for editing image with crop functionality.
  Allows users to drag a rectangle to select crop area like Bluesky.
  """
  attr :show, :boolean, default: false
  attr :upload, :map, default: nil
  attr :crop, :map, default: %{}
  attr :on_close, JS, default: %JS{}
  attr :id, :string, default: "image-edit-modal"

  def liquid_image_edit_modal(assigns) do
    ~H"""
    <div
      :if={@show && @upload}
      id={@id}
      class="fixed inset-0 z-[70] flex items-center justify-center p-4"
      phx-window-keydown="close_image_edit_modal"
      phx-key="Escape"
    >
      <div
        class="fixed inset-0 bg-slate-900/60 dark:bg-slate-950/80 backdrop-blur-sm"
        phx-click="close_image_edit_modal"
      >
      </div>

      <div class="relative w-full max-w-2xl max-h-[90vh] overflow-y-auto bg-white dark:bg-slate-800 rounded-2xl shadow-2xl border border-slate-200/60 dark:border-slate-700/60">
        <div class="absolute inset-0 bg-gradient-to-br from-sky-50/30 via-slate-50/20 to-indigo-50/30 dark:from-sky-900/10 dark:via-slate-900/5 dark:to-indigo-900/10 pointer-events-none">
        </div>

        <div class="relative p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-2">
              <.phx_icon
                name="hero-pencil-square"
                class="h-5 w-5 text-sky-600 dark:text-sky-400"
              />
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                Edit Image
              </h2>
            </div>
            <button
              type="button"
              phx-click="close_image_edit_modal"
              aria-label="Close"
              class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700/50 transition-all"
            >
              <.phx_icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>

          <div class="mb-4">
            <div
              id={"crop-container-#{@upload[:ref]}"}
              class="relative bg-slate-100 dark:bg-slate-700/50 rounded-lg overflow-hidden select-none"
              phx-hook="ImageCropHook"
              data-ref={@upload[:ref]}
              data-crop={Jason.encode!(@crop || %{})}
            >
              <%= cond do %>
                <% @upload[:original_preview_data_url] || @upload[:preview_data_url] -> %>
                  <img
                    id={"crop-image-#{@upload[:ref]}"}
                    src={@upload[:original_preview_data_url] || @upload.preview_data_url}
                    alt="Preview"
                    class="w-full max-h-[60vh] object-contain pointer-events-none"
                    draggable="false"
                  />
                  <div
                    id={"crop-overlay-#{@upload[:ref]}"}
                    class="absolute inset-0 pointer-events-none"
                  >
                  </div>
                <% @upload[:entry] -> %>
                  <.live_img_preview
                    entry={@upload.entry}
                    id={"crop-image-#{@upload[:ref]}"}
                    class="w-full max-h-[60vh] object-contain pointer-events-none"
                  />
                  <div
                    id={"crop-overlay-#{@upload[:ref]}"}
                    class="absolute inset-0 pointer-events-none"
                  >
                  </div>
                <% true -> %>
                  <div class="w-full h-60 flex items-center justify-center">
                    <.phx_icon name="hero-photo" class="h-12 w-12 text-slate-400" />
                  </div>
              <% end %>
            </div>
          </div>

          <p class="text-xs text-slate-500 dark:text-slate-400 mb-4">
            Drag to select the area you want to keep. Leave empty for full image.
          </p>

          <div class="flex items-center justify-between pt-2">
            <button
              type="button"
              id={"reset-crop-#{@upload[:ref]}"}
              phx-click="reset_crop"
              phx-value-ref={@upload[:ref]}
              class="px-4 py-2.5 rounded-xl text-sm font-medium text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700/50 transition-all flex items-center gap-2"
            >
              <.phx_icon name="hero-arrow-path" class="h-4 w-4" /> Reset
            </button>

            <div class="flex items-center gap-3">
              <button
                type="button"
                phx-click="close_image_edit_modal"
                class="px-4 py-2.5 rounded-xl text-sm font-medium text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700/50 transition-all"
              >
                Cancel
              </button>
              <button
                type="button"
                id={"save-crop-#{@upload[:ref]}"}
                class="px-5 py-2.5 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-sky-500 to-indigo-500 hover:from-sky-600 hover:to-indigo-600 shadow-lg shadow-sky-500/25 hover:shadow-sky-500/40 transition-all hover:scale-105 active:scale-95"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Liquid banner upload component with detailed progress feedback.
  Shows processing stages and helpful dimension tips for optimal banner display.
  """
  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil
  attr :current_banner_src, :string, default: nil
  attr :banner_loading, :any, default: nil
  attr :user, :map, required: true
  attr :encryption_key, :string, required: true
  attr :url, :string, default: nil
  attr :on_delete, :string, default: nil
  attr :class, :any, default: nil
  attr :alt_text, :string, default: nil
  attr :crop, :map, default: nil
  attr :preview_data_url, :string, default: nil

  attr :encrypted_banner_data, :map,
    default: nil,
    doc: "ZK mode: encrypted banner data for browser-side decryption"

  def liquid_banner_upload(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <div class="space-y-3">
        <div class="flex items-start gap-3 p-3 rounded-xl bg-purple-50/60 dark:bg-purple-900/20 border border-purple-200/60 dark:border-purple-700/40">
          <.phx_icon
            name="hero-light-bulb"
            class="h-5 w-5 text-purple-600 dark:text-purple-400 mt-0.5 shrink-0"
          />
          <div class="space-y-1">
            <p class="text-sm font-medium text-purple-800 dark:text-purple-200">
              Banner Image Tips
            </p>
            <ul class="text-xs text-purple-700/90 dark:text-purple-300/90 space-y-0.5">
              <li>
                • Recommended size: <span class="font-medium">1500×500 pixels</span> (3:1 ratio)
              </li>
              <li>• Minimum width: <span class="font-medium">1200px</span> for best quality</li>
              <li>• File types: JPEG, PNG, WebP, HEIC</li>
              <li>• Max file size: 10MB</li>
            </ul>
          </div>
        </div>

        <div
          phx-drop-target={@upload.ref}
          class="relative rounded-xl overflow-hidden border-2 border-dashed border-slate-300 dark:border-slate-600 transition-all duration-200 hover:border-purple-400 dark:hover:border-purple-500 phx-drop-target:border-purple-500 phx-drop-target:bg-purple-50 dark:phx-drop-target:bg-purple-900/20"
        >
          <%= cond do %>
            <% @banner_loading -> %>
              <div class="aspect-[3/1] flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
                <div class="text-center">
                  <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin mx-auto mb-2">
                  </div>
                  <p class="text-sm text-slate-500 dark:text-slate-400">Loading banner...</p>
                </div>
              </div>
            <% @encrypted_banner_data -> %>
              <div class="relative aspect-[3/1] bg-slate-100 dark:bg-slate-800">
                <img
                  id="current-banner-img"
                  phx-hook="DecryptAvatar"
                  data-encrypted-blob={@encrypted_banner_data[:encrypted_blob_b64]}
                  data-sealed-key={@encrypted_banner_data[:sealed_key]}
                  class="w-full h-full object-cover"
                  alt="Current banner"
                />
                <div class="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
                <button
                  :if={@on_delete}
                  type="button"
                  id="delete-banner-button"
                  phx-click={@on_delete}
                  data-confirm="Are you sure you want to remove your custom banner?"
                  class="absolute top-3 right-3 w-8 h-8 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-lg transition-all duration-200 hover:scale-110"
                  phx-hook="TippyHook"
                  data-tippy-content="Remove banner"
                  aria-label="Remove banner"
                >
                  <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
            <% @current_banner_src -> %>
              <div class="relative aspect-[3/1] bg-slate-100 dark:bg-slate-800">
                <img
                  src={@current_banner_src}
                  class="w-full h-full object-cover"
                  alt="Current banner"
                />
                <div class="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
                <button
                  :if={@on_delete}
                  type="button"
                  id="delete-banner-button"
                  phx-click={@on_delete}
                  data-confirm="Are you sure you want to remove your custom banner?"
                  class="absolute top-3 right-3 w-8 h-8 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-lg transition-all duration-200 hover:scale-110"
                  phx-hook="TippyHook"
                  data-tippy-content="Remove banner"
                  aria-label="Remove banner"
                >
                  <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
            <% true -> %>
              <div class="aspect-[3/1] flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
                <div class="text-center">
                  <.phx_icon
                    name="hero-photo"
                    class="h-10 w-10 text-slate-400 dark:text-slate-500 mx-auto mb-2"
                  />
                  <p class="text-sm text-slate-500 dark:text-slate-400">No custom banner uploaded</p>
                </div>
              </div>
          <% end %>
        </div>

        <%= if Enum.any?(@upload.entries) do %>
          <div class="space-y-3">
            <p class="text-sm font-medium text-slate-700 dark:text-slate-300">Preview</p>
            <%= for entry <- @upload.entries do %>
              <div
                id={"phx-preview-banner-#{entry.ref}"}
                class="relative rounded-xl overflow-hidden border-2 border-purple-400 dark:border-purple-500"
              >
                <div class="relative aspect-[3/1]">
                  <%= if @preview_data_url do %>
                    <img
                      src={@preview_data_url}
                      class="w-full h-full object-cover"
                      alt={@alt_text || "Banner preview"}
                    />
                  <% else %>
                    <.live_img_preview
                      entry={entry}
                      class="w-full h-full object-cover"
                      alt={@alt_text || "Banner preview"}
                    />
                  <% end %>
                  <div
                    :if={is_processing?(@upload_stage)}
                    class="absolute inset-0 bg-black/50 flex items-center justify-center"
                  >
                    <div class="w-8 h-8 border-3 border-white border-t-transparent rounded-full animate-spin">
                    </div>
                  </div>
                  <button
                    :if={!is_processing?(@upload_stage)}
                    type="button"
                    id={"cancel-banner-upload-#{entry.ref}"}
                    phx-click="cancel-banner-upload"
                    phx-value-ref={entry.ref}
                    class="absolute top-3 right-3 w-8 h-8 bg-slate-700/80 hover:bg-slate-700 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                    phx-hook="TippyHook"
                    data-tippy-content="Cancel"
                    aria-label="Cancel upload"
                  >
                    <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                  </button>
                  <div
                    :if={!is_processing?(@upload_stage)}
                    class="absolute bottom-3 left-3 right-3 z-10 flex items-center justify-between"
                  >
                    <button
                      type="button"
                      id={"edit-alt-banner-#{entry.ref}"}
                      phx-click="open_banner_alt_text_modal"
                      phx-value-ref={entry.ref}
                      aria-label="Edit alt text"
                      class={[
                        "px-2 py-1 rounded text-xs font-bold flex items-center gap-1",
                        "transition-all duration-200 hover:scale-105",
                        if(@alt_text && @alt_text != "",
                          do: "bg-emerald-500 text-white",
                          else: "bg-slate-800 text-white hover:bg-slate-700"
                        )
                      ]}
                      phx-hook="TippyHook"
                      data-tippy-content={
                        if(@alt_text && @alt_text != "",
                          do: "Edit alt text: #{String.slice(@alt_text || "", 0..30)}...",
                          else: "Add alt text for accessibility"
                        )
                      }
                    >
                      <.phx_icon
                        :if={!(@alt_text && @alt_text != "")}
                        name="hero-plus"
                        class="h-3 w-3"
                      /> ALT
                    </button>

                    <button
                      type="button"
                      id={"edit-banner-#{entry.ref}"}
                      phx-click="open_banner_edit_modal"
                      phx-value-ref={entry.ref}
                      aria-label="Edit image"
                      class={[
                        "w-8 h-6 rounded flex items-center justify-center",
                        "transition-all duration-200 hover:scale-105",
                        if(@crop && @crop != %{},
                          do: "bg-sky-500 text-white",
                          else: "bg-slate-800 text-white hover:bg-slate-700"
                        )
                      ]}
                      phx-hook="TippyHook"
                      data-tippy-content={
                        if(@crop && @crop != %{},
                          do: "Edit crop",
                          else: "Crop image"
                        )
                      }
                    >
                      <.phx_icon name="hero-pencil" class="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="flex items-center gap-4">
          <label
            for={@upload.ref}
            class={[
              "inline-flex items-center gap-2 px-4 py-2.5 rounded-xl cursor-pointer",
              "bg-purple-100 dark:bg-purple-900/40",
              "border border-purple-200/60 dark:border-purple-700/60",
              "hover:bg-purple-200/80 dark:hover:bg-purple-800/60",
              "transition-all duration-200 ease-out",
              "text-sm font-medium text-purple-700 dark:text-purple-200"
            ]}
          >
            <.phx_icon name="hero-arrow-up-tray" class="h-4 w-4" />
            <span>
              {if @current_banner_src || @encrypted_banner_data,
                do: "Replace banner",
                else: "Upload banner"}
            </span>
          </label>
          <.live_file_input upload={@upload} class="hidden" />
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {Enum.join(@upload.acceptable_exts, ", ")}
          </p>
        </div>
      </div>

      <%= if Enum.any?(@upload.entries) || is_processing?(@upload_stage) do %>
        <.liquid_banner_upload_progress
          upload={@upload}
          upload_stage={@upload_stage}
        />
      <% end %>

      <%= for entry <- @upload.entries do %>
        <%= for err <- upload_errors(@upload, entry) do %>
          <div class="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl">
            <div class="flex items-center gap-2 text-sm text-red-700 dark:text-red-300">
              <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
              <span>{humanize_upload_error(err, @upload.max_entries)}</span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil

  def liquid_banner_upload_progress(assigns) do
    stages = [
      {:receiving, "Receiving", "hero-arrow-down-tray"},
      {:converting, "Converting", "hero-arrows-right-left"},
      {:resizing, "Resizing", "hero-arrows-pointing-in"},
      {:checking, "Safety check", "hero-shield-check"},
      {:encrypting, "Encrypting", "hero-lock-closed"},
      {:uploading, "Uploading", "hero-cloud-arrow-up"}
    ]

    assigns = assign(assigns, :stages, stages)

    ~H"""
    <div class={[
      "p-4 rounded-xl border",
      "bg-gradient-to-br from-purple-50/80 to-purple-100/60 dark:from-purple-900/30 dark:to-purple-900/20",
      "border-purple-200/60 dark:border-purple-700/60"
    ]}>
      <div class="flex items-center gap-2 mb-4">
        <.phx_icon
          name="hero-cog-6-tooth"
          class="h-4 w-4 text-purple-600 dark:text-purple-400 animate-spin"
        />
        <span class="text-sm font-medium text-purple-700 dark:text-purple-300">
          Processing your banner
        </span>
      </div>

      <div class="space-y-2">
        <%= for {stage_key, stage_label, stage_icon} <- @stages do %>
          <% status = get_stage_status(@upload_stage, stage_key) %>
          <div class={[
            "flex items-center gap-3 px-3 py-2 rounded-lg transition-all duration-300",
            banner_stage_status_bg_class(status)
          ]}>
            <div class={[
              "w-6 h-6 rounded-full flex items-center justify-center transition-all duration-300",
              banner_stage_status_icon_class(status)
            ]}>
              <%= case status do %>
                <% :completed -> %>
                  <.phx_icon name="hero-check" class="h-3.5 w-3.5 text-white" />
                <% :active -> %>
                  <div class="w-3 h-3 border-2 border-purple-600 border-t-transparent rounded-full animate-spin">
                  </div>
                <% :pending -> %>
                  <.phx_icon name={stage_icon} class="h-3.5 w-3.5 text-slate-400 dark:text-slate-500" />
                <% :error -> %>
                  <.phx_icon name="hero-x-mark" class="h-3.5 w-3.5 text-white" />
              <% end %>
            </div>

            <span class={[
              "text-sm font-medium transition-all duration-300",
              banner_stage_status_text_class(status)
            ]}>
              {stage_label}
            </span>

            <%= if status == :active do %>
              <div class="ml-auto flex items-center gap-2">
                <div class="w-16 h-1.5 bg-purple-200 dark:bg-purple-800 rounded-full overflow-hidden">
                  <div class="h-full bg-purple-500 rounded-full animate-pulse w-2/3"></div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if is_upload_error?(@upload_stage) do %>
        <div class="mt-4 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
          <div class="flex items-center gap-2 text-sm text-red-700 dark:text-red-300">
            <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
            <span>{get_upload_error_message(@upload_stage)}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp banner_stage_status_bg_class(:completed), do: "bg-purple-50/80 dark:bg-purple-900/20"
  defp banner_stage_status_bg_class(:active), do: "bg-purple-100/80 dark:bg-purple-900/30"
  defp banner_stage_status_bg_class(:error), do: "bg-red-50/80 dark:bg-red-900/20"
  defp banner_stage_status_bg_class(:pending), do: "bg-transparent"

  defp banner_stage_status_icon_class(:completed), do: "bg-purple-500"
  defp banner_stage_status_icon_class(:active), do: "bg-purple-100 dark:bg-purple-900/50"
  defp banner_stage_status_icon_class(:error), do: "bg-red-500"
  defp banner_stage_status_icon_class(:pending), do: "bg-slate-100 dark:bg-slate-700"

  defp banner_stage_status_text_class(:completed), do: "text-purple-700 dark:text-purple-300"
  defp banner_stage_status_text_class(:active), do: "text-purple-700 dark:text-purple-300"
  defp banner_stage_status_text_class(:error), do: "text-red-700 dark:text-red-300"
  defp banner_stage_status_text_class(:pending), do: "text-slate-500 dark:text-slate-400"

  @doc """
  Journal book cover upload component with compact design.
  Shows a square preview area and upload progress for book covers.
  """
  attr :upload, :map, required: true
  attr :upload_stage, :any, default: nil
  attr :current_cover_src, :string, default: nil
  attr :cover_loading, :boolean, default: false
  attr :on_delete, :string, default: nil
  attr :class, :any, default: nil

  def liquid_journal_cover_upload(assigns) do
    ~H"""
    <div id="cover-upload-container" class={["space-y-3", @class]}>
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300">
        Cover Image (optional)
      </label>

      <div
        phx-drop-target={@upload.ref}
        class={[
          "relative rounded-xl overflow-hidden border-2 border-dashed transition-all duration-200 text-center",
          if(is_upload_complete?(@upload_stage),
            do: "border-emerald-400 dark:border-emerald-500",
            else:
              "border-slate-300 dark:border-slate-600 hover:border-emerald-400 dark:hover:border-emerald-500 phx-drop-target:border-emerald-500 phx-drop-target:bg-emerald-50 dark:phx-drop-target:bg-emerald-900/20"
          )
        ]}
      >
        <%= cond do %>
          <% @cover_loading -> %>
            <div class="aspect-[4/3] max-h-48 flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700">
              <div class="text-center">
                <div class="w-8 h-8 border-3 border-emerald-400 border-t-transparent rounded-full animate-spin mx-auto mb-2">
                </div>
                <p class="text-xs text-slate-500 dark:text-slate-400">Loading cover...</p>
              </div>
            </div>
          <% Enum.any?(@upload.entries) -> %>
            <% entry = List.first(@upload.entries) %>
            <div class="relative w-full aspect-[4/3] max-h-48 bg-slate-100 dark:bg-slate-800">
              <.live_img_preview
                entry={entry}
                class="w-full h-full object-cover"
                alt="Cover preview"
              />
              <div
                :if={entry.progress < 100}
                class="absolute inset-0 bg-black/60 flex flex-col items-center justify-center gap-2"
              >
                <div class="w-8 h-8 border-3 border-emerald-400 border-t-transparent rounded-full animate-spin">
                </div>
                <span class="text-xs text-white font-medium">
                  Uploading {entry.progress}%
                </span>
              </div>
              <div
                :if={entry.progress == 100 && is_processing?(@upload_stage)}
                class="absolute inset-0 bg-black/60 flex flex-col items-center justify-center gap-2"
              >
                <div class="w-8 h-8 border-3 border-emerald-400 border-t-transparent rounded-full animate-spin">
                </div>
                <span class="text-xs text-white font-medium">
                  {cover_stage_label(@upload_stage)}
                </span>
              </div>
              <div
                :if={is_upload_complete?(@upload_stage)}
                class="absolute bottom-2 left-2 flex items-center gap-1.5 px-2 py-1 bg-emerald-500 text-white text-xs font-medium rounded-full shadow-md"
              >
                <.phx_icon name="hero-check" class="h-3.5 w-3.5" />
                <span>Uploaded</span>
              </div>
              <button
                :if={is_upload_complete?(@upload_stage)}
                type="button"
                phx-click="remove_cover"
                class="absolute top-2 right-2 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                aria-label="Remove cover"
              >
                <.phx_icon name="hero-trash" class="h-4 w-4" />
              </button>
              <button
                :if={
                  !is_processing?(@upload_stage) && !is_upload_complete?(@upload_stage) &&
                    entry.progress == 100
                }
                type="button"
                phx-click="cancel_cover_upload"
                phx-value-ref={entry.ref}
                class="absolute top-2 right-2 w-7 h-7 bg-slate-700/80 hover:bg-slate-700 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                aria-label="Cancel upload"
              >
                <.phx_icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
          <% @current_cover_src -> %>
            <div class="relative w-full aspect-[4/3] max-h-48 bg-slate-100 dark:bg-slate-800">
              <img
                src={@current_cover_src}
                class="w-full h-full object-cover"
                alt="Current cover"
              />
              <button
                :if={@on_delete}
                type="button"
                phx-click={@on_delete}
                data-confirm="Are you sure you want to remove this cover image?"
                class="absolute top-2 right-2 w-7 h-7 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center shadow-md transition-all duration-200 hover:scale-110"
                aria-label="Remove cover"
              >
                <.phx_icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
          <% true -> %>
            <label
              for={@upload.ref}
              class="w-full aspect-[4/3] max-h-48 flex items-center justify-center bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-700 cursor-pointer"
            >
              <div class="text-center px-4">
                <.phx_icon
                  name="hero-photo"
                  class="h-8 w-8 text-slate-400 dark:text-slate-500 mx-auto mb-2"
                />
                <p class="text-sm text-emerald-600 dark:text-emerald-400 font-medium">
                  Upload cover
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  or drag and drop
                </p>
              </div>
            </label>
        <% end %>
      </div>

      <.live_file_input upload={@upload} class="hidden" />

      <%= if is_upload_error?(@upload_stage) do %>
        <div class="p-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
          <div class="flex items-center gap-2 text-xs text-red-700 dark:text-red-300">
            <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
            <span>{get_upload_error_message(@upload_stage)}</span>
          </div>
        </div>
      <% end %>

      <%= for entry <- @upload.entries do %>
        <%= for err <- upload_errors(@upload, entry) do %>
          <div class="p-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
            <div class="flex items-center gap-2 text-xs text-red-700 dark:text-red-300">
              <.phx_icon name="hero-exclamation-triangle" class="h-4 w-4 flex-shrink-0" />
              <span>{humanize_upload_error(err)}</span>
            </div>
          </div>
        <% end %>
      <% end %>

      <p class="text-xs text-slate-500 dark:text-slate-400">
        JPEG, PNG, WebP, or HEIC • Max 5MB
      </p>
    </div>
    """
  end

  defp cover_stage_label({:receiving, _}), do: "Uploading..."
  defp cover_stage_label({:checking, _}), do: "Checking..."
  defp cover_stage_label({:processing, _}), do: "Processing..."
  defp cover_stage_label({:encrypting, _}), do: "Encrypting..."
  defp cover_stage_label({:uploading, _}), do: "Saving..."
  defp cover_stage_label({:ready, _}), do: "Done!"
  defp cover_stage_label(_), do: "Processing..."

  defp is_processing?(nil), do: false
  defp is_processing?({:ready, _}), do: false
  defp is_processing?({:error, _}), do: false
  defp is_processing?(_), do: true

  defp is_upload_complete?({:ready, _}), do: true
  defp is_upload_complete?(_), do: false

  defp is_upload_error?({:error, _}), do: true
  defp is_upload_error?(_), do: false

  defp get_upload_error_message({:error, {:nsfw, msg}}), do: msg
  defp get_upload_error_message({:error, msg}) when is_binary(msg), do: msg
  defp get_upload_error_message({:error, _}), do: "Upload failed. Please try again."
  defp get_upload_error_message(_), do: ""

  defp get_stage_status(nil, _stage_key), do: :pending
  defp get_stage_status({:error, _}, _stage_key), do: :error

  defp get_stage_status({current_stage, _progress}, stage_key) do
    stage_order = [:receiving, :converting, :resizing, :checking, :encrypting, :uploading, :ready]
    current_idx = Enum.find_index(stage_order, &(&1 == current_stage)) || 0
    stage_idx = Enum.find_index(stage_order, &(&1 == stage_key)) || 0

    cond do
      current_stage == :ready -> :completed
      stage_idx < current_idx -> :completed
      stage_idx == current_idx -> :active
      true -> :pending
    end
  end

  defp stage_progress({_stage, progress}) when is_integer(progress), do: progress
  defp stage_progress(_), do: 0

  @doc """
  Website URL preview card component with loading state.

  ## Examples

      <.website_url_preview
        preview={@website_url_preview}
        loading={@website_url_preview_loading}
        url={@decrypted_website_url}
        label="My Website"
      />
  """
  attr :preview, :map, default: nil, doc: "The preview map with image, title, description keys"
  attr :loading, :boolean, default: false, doc: "Whether the preview is currently loading"
  attr :url, :string, required: true, doc: "The decrypted website URL"
  attr :label, :string, default: "Website", doc: "Label shown above the preview"

  def website_url_preview(assigns) do
    ~H"""
    <div :if={@url && @url != ""} class="flex items-start gap-3">
      <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30">
        <.phx_icon name="hero-globe-alt" class="size-5 text-violet-600 dark:text-violet-400" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm text-slate-500 dark:text-slate-400">{@label}</p>

        <a
          :if={@preview && @preview["image"]}
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="block group mt-2"
        >
          <div class="flex gap-3 p-2 rounded-xl border border-violet-200/60 dark:border-violet-700/40 bg-gradient-to-br from-violet-50/50 to-purple-50/50 dark:from-violet-900/10 dark:to-purple-900/10 transition-all duration-300 hover:shadow-md hover:shadow-violet-500/10 hover:border-violet-300 dark:hover:border-violet-600">
            <div class="w-20 h-14 shrink-0 overflow-hidden rounded-lg">
              <img
                src={@preview["image"]}
                alt={@preview["title"] || "Website preview"}
                class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
              />
            </div>
            <div class="flex-1 min-w-0 py-0.5">
              <p
                :if={@preview["title"]}
                class="font-medium text-sm text-slate-900 dark:text-white line-clamp-1 group-hover:text-violet-600 dark:group-hover:text-violet-400 transition-colors"
              >
                {@preview["title"]}
              </p>
              <p
                :if={@preview["description"]}
                class="text-xs text-slate-500 dark:text-slate-400 line-clamp-2 mt-0.5"
              >
                {@preview["description"]}
              </p>
            </div>
          </div>
        </a>

        <div
          :if={@loading}
          class="flex items-center gap-3 p-2 mt-2 rounded-xl border border-violet-200/60 dark:border-violet-700/40 bg-gradient-to-br from-violet-50/50 to-purple-50/50 dark:from-violet-900/10 dark:to-purple-900/10"
        >
          <div class="w-20 h-14 shrink-0 rounded-lg bg-violet-100 dark:bg-violet-900/30 animate-pulse">
          </div>
          <div class="flex-1 space-y-2">
            <div class="h-4 w-3/4 rounded bg-violet-100 dark:bg-violet-900/30 animate-pulse"></div>
            <div class="h-3 w-full rounded bg-violet-100 dark:bg-violet-900/30 animate-pulse"></div>
          </div>
        </div>

        <a
          :if={(!@preview || !@preview["image"]) && !@loading}
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="text-slate-900 dark:text-white hover:text-violet-600 dark:hover:text-violet-400 transition-colors truncate block"
        >
          {@url}
        </a>
      </div>
    </div>
    """
  end

  @doc """
  Zero-knowledge avatar image component.

  Renders an `<img>` that decrypts the avatar client-side using the DecryptAvatar
  hook. The server sends only the encrypted blob and the sealed conn_key — the
  browser unseals the key and decrypts the image via WASM.

  Falls back to a placeholder icon while decryption is pending or when no
  encrypted avatar data is available (ETS miss or no avatar).
  """
  attr :user, :any, required: true, doc: "User or UserConnection struct"
  attr :key, :string, required: true, doc: "session key"
  attr :id, :string, required: true, doc: "unique DOM id"
  attr :class, :string, default: "", doc: "CSS classes"
  attr :alt, :string, default: "", doc: "alt text"
  attr :placeholder_class, :string, default: "", doc: "CSS classes for the placeholder fallback"

  def zk_avatar_image(assigns) do
    encrypted_data = get_encrypted_avatar_data(assigns[:user], assigns[:key])

    assigns =
      assign(assigns, :encrypted_data, encrypted_data)
      |> assign(:has_data?, not is_nil(encrypted_data))

    ~H"""
    <div class="relative inline-flex">
      <div
        :if={!@has_data?}
        class={[
          "inline-flex items-center justify-center bg-slate-200 dark:bg-slate-700",
          @placeholder_class
        ]}
      >
        <.phx_icon name="hero-user" class="w-1/2 h-1/2 text-slate-400 dark:text-slate-500" />
      </div>
      <img
        :if={@has_data?}
        id={@id}
        phx-hook="DecryptAvatar"
        data-encrypted-blob={@encrypted_data[:encrypted_blob_b64]}
        data-sealed-key={@encrypted_data[:sealed_key]}
        class={[@class]}
        alt={@alt}
        loading="lazy"
      />
    </div>
    """
  end

  @doc """
  Zero-knowledge banner image component.

  Same pattern as zk_avatar_image but for banner images (3:1 aspect ratio).
  The browser decrypts the banner client-side via DecryptAvatar hook.
  """
  attr :user, :any, required: true, doc: "User struct"
  attr :key, :string, required: true, doc: "session key"
  attr :id, :string, required: true, doc: "unique DOM id"
  attr :class, :string, default: "", doc: "CSS classes"
  attr :alt, :string, default: "Banner image"

  attr :encrypted_data, :map,
    default: nil,
    doc: "override encrypted data (e.g. from async result)"

  def zk_banner_image(assigns) do
    encrypted_data =
      assigns[:encrypted_data] || get_encrypted_banner_data(assigns[:user], assigns[:key])

    assigns =
      assign(assigns, :encrypted_data, encrypted_data)
      |> assign(:has_data?, not is_nil(encrypted_data))

    ~H"""
    <img
      :if={@has_data?}
      id={@id}
      phx-hook="DecryptAvatar"
      data-encrypted-blob={@encrypted_data[:encrypted_blob_b64]}
      data-sealed-key={@encrypted_data[:sealed_key]}
      class={["w-full h-full object-cover", @class]}
      alt={@alt}
    />
    """
  end
end
