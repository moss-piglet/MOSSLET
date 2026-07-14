defmodule MossletWeb.VoiceNoteComponents do
  @moduledoc """
  UI components for E2EE voice notes (Task #383, docs/VOICE_NOTES_DESIGN.md).

  Two pieces, shared by the DM (`ConversationLive.Show`) and group
  (`GroupLive.GroupMessage.Form`) composers/streams:

    * `voice_note_composer/1` — the mic affordance + live recording panel
      (timer + amplitude bars + cancel/send), wired to the `VoiceNoteRecorder`
      hook. Capability-gated with honest copy when the mic is unavailable.
    * `voice_note_bubble/1` — the audio-player bubble in the message stream,
      wired to the `VoiceNotePlayer` hook (lazy request → unseal → decrypt →
      verify → play). No audio is fetched until the listener taps play.
  """
  use Phoenix.Component

  import MossletWeb.CoreComponents, only: [phx_icon: 1]

  @doc """
  The composer mic affordance. Tapping starts recording; a live panel shows the
  timer + amplitude bars with cancel (discard) and send (stop → encrypt → send)
  controls. The `VoiceNoteRecorder` hook toggles `data-recording` /
  `data-unsupported` which drive the visibility of these sub-elements.

  Assigns:
    * `:id` — DOM id (required)
    * `:cohort` — "conversation" | "group"
    * `:sealed_key` — sealed conversation_key or group_key (for the caption)
    * `:max_bytes` / `:max_duration_ms` — server caps (client defense-in-depth)
    * `:group_id` / `:sender_id` — group-only (optional)
    * `:phx_target` — optional LiveComponent target
  """
  attr :id, :string, required: true
  attr :cohort, :string, required: true
  attr :sealed_key, :string, default: nil
  attr :max_bytes, :integer, default: nil
  attr :max_duration_ms, :integer, default: nil
  attr :group_id, :string, default: nil
  attr :sender_id, :string, default: nil
  attr :phx_target, :any, default: nil

  def voice_note_composer(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="VoiceNoteRecorder"
      phx-target={@phx_target}
      data-recording="false"
      data-cohort={@cohort}
      data-sealed-key={@sealed_key}
      data-max-bytes={@max_bytes}
      data-max-duration-ms={@max_duration_ms}
      data-group-id={@group_id}
      data-sender-id={@sender_id}
      class="group/voice contents"
    >
      <%!-- Idle: mic button (hidden while recording or when unsupported) --%>
      <button
        type="button"
        data-voice-record
        title="Record a voice note"
        aria-label="Record a voice note"
        class={[
          "p-2 rounded-lg text-slate-500 dark:text-slate-400",
          "hover:text-teal-600 dark:hover:text-teal-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20",
          "transition-all duration-200 ease-out group/mic",
          "group-data-[recording=true]/voice:hidden group-data-[unsupported=true]/voice:hidden"
        ]}
      >
        <.phx_icon
          name="hero-microphone"
          class="h-4 w-4 transition-transform duration-200 group-hover/mic:scale-110"
        />
      </button>

      <%!-- Recording panel (revealed while recording) --%>
      <div class="hidden group-data-[recording=true]/voice:flex items-center gap-2 px-2 py-1.5 rounded-xl bg-rose-50/80 dark:bg-rose-900/20 border border-rose-200/60 dark:border-rose-800/40">
        <button
          type="button"
          data-voice-cancel
          title="Discard"
          aria-label="Discard voice note"
          class="p-1.5 rounded-lg text-slate-500 hover:text-rose-600 dark:text-slate-400 dark:hover:text-rose-400 transition-colors"
        >
          <.phx_icon name="hero-trash" class="h-4 w-4" />
        </button>

        <span class="flex items-center gap-1.5">
          <span class="w-2 h-2 rounded-full bg-rose-500 animate-pulse"></span>
          <span
            data-voice-timer
            class="text-xs font-medium tabular-nums text-rose-600 dark:text-rose-400"
          >
            0:00
          </span>
        </span>

        <div data-voice-bars class="flex items-end gap-0.5 h-5">
          <span
            :for={_ <- 1..14}
            data-voice-bar
            class="w-0.5 h-full origin-bottom rounded-full bg-teal-500/70 dark:bg-teal-400/70 transition-transform duration-75"
            style="transform: scaleY(0.2)"
          ></span>
        </div>

        <button
          type="button"
          data-voice-stop
          title="Send voice note"
          aria-label="Send voice note"
          class="inline-flex items-center justify-center h-8 w-8 rounded-lg bg-gradient-to-br from-teal-500 to-emerald-500 hover:from-teal-400 hover:to-emerald-400 text-white shadow-md active:scale-95 transition-all duration-200"
        >
          <.phx_icon name="hero-paper-airplane" class="h-4 w-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  The audio-player bubble in the message stream. Lazily fetches + decrypts the
  note on first play (via the `VoiceNotePlayer` hook). `sender?` tints controls
  to sit on the sender (gradient) vs. recipient (light) bubble.

  Assigns:
    * `:id` — DOM id (required)
    * `:voice_note_id` — the VoiceNote id (required)
    * `:sender?` — true on the current user's own bubble
  """
  attr :id, :string, required: true
  attr :voice_note_id, :string, required: true
  attr :sender?, :boolean, default: false

  def voice_note_bubble(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="VoiceNotePlayer"
      data-voice-note-id={@voice_note_id}
      data-state="idle"
      data-playing="false"
      class="flex items-center gap-2.5 min-w-[220px] py-0.5 group/vn"
    >
      <button
        type="button"
        data-voice-play
        aria-label="Play voice note"
        class={[
          "inline-flex items-center justify-center h-9 w-9 shrink-0 rounded-full shadow-sm active:scale-95 transition-all duration-200",
          if(@sender?,
            do: "bg-white/20 hover:bg-white/30 text-white",
            else: "bg-teal-500 hover:bg-teal-400 text-white dark:bg-teal-600 dark:hover:bg-teal-500"
          )
        ]}
      >
        <.phx_icon name="hero-play-solid" class="h-4 w-4 group-data-[playing=true]/vn:hidden" />
        <.phx_icon
          name="hero-pause-solid"
          class="h-4 w-4 hidden group-data-[playing=true]/vn:block"
        />
      </button>

      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-1.5">
          <.phx_icon
            name="hero-microphone"
            class={[
              "h-3.5 w-3.5",
              if(@sender?, do: "text-white/70", else: "text-teal-500 dark:text-teal-400")
            ]}
          />
          <span class={[
            "text-xs font-medium",
            if(@sender?, do: "text-white/80", else: "text-slate-600 dark:text-slate-300")
          ]}>
            Voice note
          </span>
          <.phx_icon
            name="hero-shield-check"
            data-voice-verified
            title="Integrity verified"
            class={[
              "h-3.5 w-3.5 hidden group-data-[verified=true]/vn:inline-block",
              if(@sender?, do: "text-white/80", else: "text-emerald-500 dark:text-emerald-400")
            ]}
          />
        </div>
        <input
          type="range"
          min="0"
          max="1000"
          value="0"
          data-voice-progress
          aria-label="Seek"
          class={[
            "mt-1 w-full h-1 cursor-pointer appearance-none rounded-full",
            if(@sender?,
              do: "bg-white/25 accent-white",
              else: "bg-slate-200 dark:bg-slate-600 accent-teal-500"
            )
          ]}
        />
      </div>

      <span
        data-voice-elapsed
        class={[
          "text-xs tabular-nums shrink-0",
          if(@sender?, do: "text-white/70", else: "text-slate-500 dark:text-slate-400")
        ]}
      >
        0:00
      </span>
    </div>
    """
  end
end
