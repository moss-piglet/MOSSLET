defmodule MossletWeb.PublicLive.Download do
  @moduledoc """
  Download page for MOSSLET desktop and mobile apps.
  Auto-detects platform and offers appropriate download.
  """
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @version "0.17.0"

  defp base_download_url do
    bucket = System.get_env("RELEASES_BUCKET", "mosslet-releases")
    host = System.get_env("AWS_HOST", "fly.storage.tigris.dev")
    "https://#{bucket}.#{host}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:download}
      container_max_width={@max_width}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
          <div class="relative isolate">
            <div class="absolute inset-0 -z-10 overflow-hidden" aria-hidden="true">
              <div class="absolute left-1/2 top-0 -translate-x-1/2 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[40rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="mx-auto max-w-7xl px-6 pb-24 pt-24 sm:pt-32 lg:px-8">
              <div class="mx-auto max-w-2xl text-center">
                <h1 class="text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Download MOSSLET
                </h1>
                <p class="mt-6 text-lg text-slate-600 dark:text-slate-400">
                  Get the native app. Your data stays private with zero-knowledge encryption on your device.
                </p>
              </div>

              <div
                id="platform-detector"
                phx-hook="PlatformDetector"
                class="mt-16 mx-auto max-w-4xl"
              >
                <div class="rounded-2xl bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm border border-slate-200 dark:border-slate-700 p-8 shadow-xl">
                  <div class="text-center mb-8">
                    <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-teal-50 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 text-sm font-medium">
                      <.phx_icon name="hero-arrow-down-tray" class="h-4 w-4" />
                      <span>
                        Recommended for
                        <span id="detected-platform-name">
                          {platform_display_name(@detected_platform)}
                        </span>
                      </span>
                    </div>
                  </div>

                  <div class="flex flex-col sm:flex-row gap-4 justify-center">
                    <.primary_download_button platform={@detected_platform} version={@version} />
                  </div>

                  <p class="mt-4 text-center text-sm text-slate-500 dark:text-slate-400">
                    Version {@version} •
                    <.link
                      href="https://github.com/moss-piglet/MOSSLET/releases"
                      target="_blank"
                      class="underline hover:text-teal-600"
                    >
                      Release notes
                    </.link>
                  </p>
                </div>
              </div>

              <div class="mt-16 mx-auto max-w-4xl">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-6 text-center">
                  All Platforms
                </h2>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <.platform_card
                    platform="macos"
                    icon="hero-computer-desktop"
                    title="macOS"
                    subtitle="Intel & Apple Silicon"
                    version={@version}
                    formats={[%{label: "Download DMG", ext: "dmg", size: "~85 MB"}]}
                  />

                  <.platform_card_coming_soon
                    icon="hero-window"
                    title="Windows"
                    subtitle="Windows 10+"
                  />

                  <.platform_card
                    platform="linux"
                    icon="hero-command-line"
                    title="Linux"
                    subtitle="x86_64"
                    version={@version}
                    formats={[%{label: "Download AppImage", ext: "AppImage", size: "~95 MB"}]}
                  />
                </div>
              </div>

              <div class="mt-16 mx-auto max-w-4xl">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-6 text-center">
                  Mobile Apps
                </h2>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-2xl mx-auto">
                  <.mobile_store_card
                    platform="ios"
                    title="iOS App"
                    subtitle="iPhone & iPad"
                    store_url="https://apps.apple.com/app/mosslet"
                    badge_src={~p"/images/download/app-store-badge.svg"}
                    badge_alt="Download on the App Store"
                  />

                  <.mobile_store_card
                    platform="android"
                    title="Android App"
                    subtitle="Android 7.0+"
                    store_url="https://play.google.com/store/apps/details?id=com.mosslet.app"
                    badge_src={~p"/images/download/google-play-badge.png"}
                    badge_alt="Get it on Google Play"
                  />
                </div>

                <p class="mt-6 text-center text-sm text-slate-500 dark:text-slate-400">
                  Mobile apps coming soon! In the meantime, use MOSSLET on the web at
                  <.link navigate="/auth/register" class="text-teal-600 hover:underline">
                    mosslet.com
                  </.link>
                </p>
              </div>

              <div class="mt-20 mx-auto max-w-3xl">
                <.liquid_card padding="lg">
                  <:title>
                    <div class="flex items-center gap-2">
                      <.phx_icon name="hero-shield-check" class="h-5 w-5 text-teal-500" />
                      <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        Zero-Knowledge Privacy
                      </span>
                    </div>
                  </:title>
                  <div class="space-y-4 text-slate-600 dark:text-slate-400">
                    <p>
                      Our desktop and mobile apps provide <strong class="text-slate-900 dark:text-white">true zero-knowledge encryption</strong>.
                      All encryption and decryption happens on your device — our servers never see your unencrypted data.
                    </p>
                    <ul class="space-y-2">
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="h-5 w-5 text-teal-500 mt-0.5 flex-shrink-0"
                        />
                        <span>Your private key never leaves your device</span>
                      </li>
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="h-5 w-5 text-teal-500 mt-0.5 flex-shrink-0"
                        />
                        <span>Data is encrypted before it reaches our servers</span>
                      </li>
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="h-5 w-5 text-teal-500 mt-0.5 flex-shrink-0"
                        />
                        <span>Works offline with local encrypted cache</span>
                      </li>
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="h-5 w-5 text-teal-500 mt-0.5 flex-shrink-0"
                        />
                        <span>Open-source encryption libraries (NaCl/libsodium)</span>
                      </li>
                    </ul>
                  </div>
                </.liquid_card>
              </div>

              <div class="mt-16 mx-auto max-w-2xl text-center">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
                  Prefer the web?
                </h2>
                <p class="text-slate-600 dark:text-slate-400 mb-6">
                  MOSSLET works great in your browser too. No download required.
                </p>
                <.liquid_button
                  navigate="/auth/register"
                  color="teal"
                  variant="secondary"
                  icon="hero-globe-alt"
                >
                  Use Web Version
                </.liquid_button>
              </div>
            </div>
          </div>
        </div>

        <div class="pb-24"></div>
      </div>
    </.layout>
    """
  end

  attr :platform, :string, required: true
  attr :version, :string, required: true

  defp primary_download_button(%{platform: "macos"} = assigns) do
    ~H"""
    <.liquid_button
      href={download_url("macos", @version, "dmg")}
      color="teal"
      variant="primary"
      icon="hero-arrow-down-tray"
      size="lg"
    >
      Download for macOS
    </.liquid_button>
    """
  end

  defp primary_download_button(%{platform: "windows"} = assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-2">
      <.liquid_button color="slate" variant="secondary" icon="hero-clock" size="lg" disabled>
        Windows Coming Soon
      </.liquid_button>
      <span class="text-sm text-slate-500 dark:text-slate-400">
        Use the
        <.link navigate="/auth/register" class="text-teal-600 hover:underline">web version</.link>
        for now
      </span>
    </div>
    """
  end

  defp primary_download_button(%{platform: "linux"} = assigns) do
    ~H"""
    <.liquid_button
      href={download_url("linux", @version, "AppImage")}
      color="teal"
      variant="primary"
      icon="hero-arrow-down-tray"
      size="lg"
    >
      Download for Linux
    </.liquid_button>
    """
  end

  defp primary_download_button(assigns) do
    ~H"""
    <.liquid_button
      navigate="/auth/register"
      color="teal"
      variant="primary"
      icon="hero-globe-alt"
      size="lg"
    >
      Use Web Version
    </.liquid_button>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true

  defp platform_card_coming_soon(assigns) do
    ~H"""
    <div class="rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm border border-slate-200 dark:border-slate-700 p-6 opacity-60">
      <div class="flex items-center gap-3 mb-4">
        <div class="p-2 rounded-lg bg-slate-100 dark:bg-slate-700">
          <.phx_icon name={@icon} class="h-6 w-6 text-slate-600 dark:text-slate-300" />
        </div>
        <div>
          <h3 class="font-semibold text-slate-900 dark:text-white">{@title}</h3>
          <p class="text-sm text-slate-500 dark:text-slate-400">{@subtitle}</p>
        </div>
      </div>

      <div class="flex items-center justify-center p-3 rounded-lg bg-amber-50 dark:bg-amber-900/20">
        <span class="inline-flex items-center gap-2 text-sm font-medium text-amber-700 dark:text-amber-300">
          <.phx_icon name="hero-clock" class="h-4 w-4" /> Coming Soon
        </span>
      </div>
    </div>
    """
  end

  attr :platform, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :version, :string, required: true
  attr :formats, :list, required: true

  defp platform_card(assigns) do
    ~H"""
    <div class="rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm border border-slate-200 dark:border-slate-700 p-6 hover:border-teal-300 dark:hover:border-teal-700 transition-colors">
      <div class="flex items-center gap-3 mb-4">
        <div class="p-2 rounded-lg bg-slate-100 dark:bg-slate-700">
          <.phx_icon name={@icon} class="h-6 w-6 text-slate-600 dark:text-slate-300" />
        </div>
        <div>
          <h3 class="font-semibold text-slate-900 dark:text-white">{@title}</h3>
          <p class="text-sm text-slate-500 dark:text-slate-400">{@subtitle}</p>
        </div>
      </div>

      <div class="space-y-2">
        <%= for format <- @formats do %>
          <.link
            href={download_url(@platform, @version, format.ext)}
            class="flex items-center justify-between p-3 rounded-lg bg-slate-50 dark:bg-slate-700/50 hover:bg-teal-50 dark:hover:bg-teal-900/20 transition-colors group"
          >
            <span class="text-sm font-medium text-slate-700 dark:text-slate-300 group-hover:text-teal-700 dark:group-hover:text-teal-300">
              {format.label}
            </span>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {format.size}
            </span>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  attr :platform, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :store_url, :string, required: true
  attr :badge_src, :string, required: true
  attr :badge_alt, :string, required: true

  defp mobile_store_card(assigns) do
    ~H"""
    <div class="rounded-xl bg-white/60 dark:bg-slate-800/60 backdrop-blur-sm border border-slate-200 dark:border-slate-700 p-6 text-center opacity-60">
      <h3 class="font-semibold text-slate-900 dark:text-white">{@title}</h3>
      <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">{@subtitle}</p>
      <div class="inline-block px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 text-xs font-medium">
        Coming Soon
      </div>
    </div>
    """
  end

  defp download_url(platform, version, ext) do
    base = base_download_url()

    case {platform, ext} do
      {"macos", "dmg"} ->
        "#{base}/v#{version}/Mosslet-#{version}-macos.dmg"

      {"windows", "exe"} ->
        "#{base}/v#{version}/Mosslet-#{version}-windows-setup.exe"

      {"linux", "AppImage"} ->
        "#{base}/v#{version}/Mosslet-#{version}-x86_64.AppImage"

      _ ->
        "#"
    end
  end

  defp platform_display_name("macos"), do: "macOS"
  defp platform_display_name("windows"), do: "Windows"
  defp platform_display_name("linux"), do: "Linux"
  defp platform_display_name("ios"), do: "iOS"
  defp platform_display_name("android"), do: "Android"
  defp platform_display_name(_), do: "your device"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:max_width, "full")
     |> assign(:page_title, "Download")
     |> assign(:version, @version)
     |> assign(:detected_platform, "unknown")
     |> assign(
       :meta_description,
       "Download MOSSLET for macOS, Windows, Linux, iOS, and Android. True zero-knowledge encryption keeps your data private."
     )}
  end

  @impl true
  def handle_event("platform_detected", %{"platform" => platform}, socket) do
    {:noreply, assign(socket, :detected_platform, platform)}
  end
end
