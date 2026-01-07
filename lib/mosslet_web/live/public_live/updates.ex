defmodule MossletWeb.PublicLive.Updates do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Updates")
     |> assign_new(:meta_description, fn ->
       "Stay up to date with the latest features, improvements, and updates to MOSSLET. See what's new in your favorite, privacy-first social network."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/updates/updates_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "MOSSLET Updates - See what's new"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:updates}
      container_max_width={@max_width}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
          <div class="relative isolate">
            <div
              class="absolute inset-0 -z-10 overflow-hidden"
              aria-hidden="true"
            >
              <div class="absolute left-1/2 top-0 -translate-x-1/2 lg:translate-x-6 xl:translate-x-12 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-16 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl text-center">
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    What's New
                  </h1>

                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Follow along as we build a privacy-first way to connect with friends and family. No ads, no algorithms, just people. Here's what we've been working on.
                  </p>

                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mx-auto max-w-4xl px-6 lg:px-8 pb-32">
            <div class="relative">
              <div class="absolute left-4 sm:left-6 top-0 bottom-0 w-px bg-gradient-to-b from-teal-400 via-emerald-400 to-cyan-400/20 dark:from-teal-500/60 dark:via-emerald-500/40 dark:to-cyan-500/10">
              </div>

              <div class="space-y-12">
                <.changelog_entry
                  version="0.11.0"
                  date="January 2026"
                  tag="Latest"
                  tag_color="emerald"
                >
                  <:title>Discover & RSS Feed 🌿</:title>
                  <:description>
                    Explore public posts from the community and subscribe via RSS — plus GIF support and UI polish throughout.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-globe-alt" color="emerald">
                      Discover page — browse public posts from the MOSSLET community
                    </.changelog_item>
                    <.changelog_item icon="hero-rss" color="amber">
                      RSS feed — subscribe to public posts in your favorite feed reader
                    </.changelog_item>
                    <.changelog_item icon="hero-gif" color="purple">
                      GIF support — upload and share animated images in your posts
                    </.changelog_item>
                    <.changelog_item icon="hero-photo" color="blue">
                      Image upload improvements — better handling and format support
                    </.changelog_item>
                    <.changelog_item icon="hero-device-phone-mobile" color="teal">
                      Mobile polish — improved password inputs, tooltips, and image viewing
                    </.changelog_item>
                    <.changelog_item icon="hero-sparkles" color="cyan">
                      UI refinements — updated user dropdown, circle UI, and more
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.10.0"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Referral Program & New Pricing 💸</:title>
                  <:description>
                    Get paid for sharing MOSSLET with friends and family. Real money, not points — plus a refreshed pricing structure with more options.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-banknotes" color="emerald">
                      Referral program — earn 30% recurring on subscriptions and 35% on lifetime purchases (beta rates)
                    </.changelog_item>
                    <.changelog_item icon="hero-gift" color="amber">
                      Friend discount — your referrals get 20% off their first payment
                    </.changelog_item>
                    <.changelog_item icon="hero-credit-card" color="blue">
                      Direct payouts via Stripe — real cash to your bank, not confusing points
                    </.changelog_item>
                    <.changelog_item icon="hero-shield-check" color="purple">
                      Privacy-first referrals — encrypted tracking with no creepy pixels or third-party data sharing
                    </.changelog_item>
                    <.changelog_item icon="hero-currency-dollar" color="teal">
                      New pricing tiers — monthly, annual, and lifetime options to fit your needs
                    </.changelog_item>
                    <.changelog_item icon="hero-sparkles" color="rose">
                      Beta bonus — lock in higher commission rates by joining during beta
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.8"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Smart Sharing & Beautiful Redesign ✈️</:title>
                  <:description>
                    A refined sharing experience with elegant new sidebar indicators, improved visibility controls, and thoughtful content warnings — all wrapped in our most beautiful post design yet.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-paper-airplane" color="emerald">
                      New share icon — the paper airplane makes sharing feel more personal and intentional
                    </.changelog_item>
                    <.changelog_item icon="hero-bars-3-center-left" color="teal">
                      Smart sidebar indicators — elegant color-coded bars show visibility and sharing status at a glance
                    </.changelog_item>
                    <.changelog_item icon="hero-user-minus" color="rose">
                      Remove shared users — easily revoke access from anyone you've shared a post with
                    </.changelog_item>
                    <.changelog_item icon="hero-user-plus" color="blue">
                      Add more recipients — share posts with additional connections anytime from the visibility overlay
                    </.changelog_item>
                    <.changelog_item icon="hero-hand-raised" color="cyan">
                      Content warnings — authors can add thoughtful warnings to help readers prepare for sensitive topics
                    </.changelog_item>
                    <.changelog_item icon="hero-eye" color="purple">
                      Hide content bar — after revealing warned content, a subtle bar lets you hide it again
                    </.changelog_item>
                    <.changelog_item icon="hero-squares-2x2" color="amber">
                      Smart post layout — cleaner design that surfaces the right information at the right time
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.7"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Intentional Sharing & Polished UI 🦖</:title>
                  <:description>
                    A thoughtful revamp focused on mental health and privacy-first design. The accessibility dino has been hard at work making everything feel more intentional.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-face-smile" color="amber">
                      Accessible emoji picker — the a11y dino 🦖 brought a fully keyboard-navigable emoji picker
                    </.changelog_item>
                    <.changelog_item icon="hero-arrow-path-rounded-square" color="purple">
                      Repost revamp — redesigned sharing flow that encourages intentional, thoughtful sharing over reflexive reposting
                    </.changelog_item>
                    <.changelog_item icon="hero-bolt" color="cyan">
                      Real-time timeline improvements — smoother live updates with better UI/UX feedback
                    </.changelog_item>
                    <.changelog_item icon="hero-bookmark-square" color="teal">
                      Sticky navigation — timeline nav stays put as you scroll for easier access
                    </.changelog_item>
                    <.changelog_item icon="hero-user-group" color="blue">
                      "Shared with" enhancements — clearer visibility into who sees your posts, reinforcing privacy-first design
                    </.changelog_item>
                    <.changelog_item icon="hero-heart" color="rose">
                      Mental health-first design — thoughtful friction points that encourage mindful engagement
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.61"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Better Image Uploads 📸</:title>
                  <:description>
                    Enhanced image upload experience with broader format support, real-time progress feedback, and improved performance.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-photo" color="teal">
                      Expanded format support — upload HEIC, WebP, and more, we convert them automatically
                    </.changelog_item>
                    <.changelog_item icon="hero-arrow-path" color="blue">
                      Real-time progress feedback — see exactly what's happening during upload and conversion
                    </.changelog_item>
                    <.changelog_item icon="hero-bolt" color="amber">
                      Improved performance — faster uploads and optimized image processing
                    </.changelog_item>
                    <.changelog_item icon="hero-shield-check" color="emerald">
                      Enhanced security — safer image handling and validation
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.6"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Bot Defense & Collapsible Sidebar 🐜</:title>
                  <:description>
                    Improved security with bot defense, a cleaner sidebar experience, and uniformed page headers throughout the app.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-bug-ant" color="rose">
                      Bot defense system to protect against automated spam and abuse
                    </.changelog_item>
                    <.changelog_item icon="hero-arrows-pointing-in" color="teal">
                      Collapsible sidebar — click to collapse for more screen space, expands on hover
                    </.changelog_item>
                    <.changelog_item icon="hero-bars-3" color="purple">
                      Uniformed page headers across all app sections for a consistent experience
                    </.changelog_item>
                    <.changelog_item icon="hero-shield-check" color="blue">
                      Enhanced moderation UI for better content management
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.51"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Circles & Better Messaging ⭕</:title>
                  <:description>
                    Groups are now Circles — a more personal way to connect. Plus, chat improvements that make conversations feel more natural.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-circle-stack" color="teal">
                      Groups renamed to Circles throughout the app for a warmer, more personal feel
                    </.changelog_item>
                    <.changelog_item icon="hero-calendar-days" color="purple">
                      Smart date separators — see "Today", "Yesterday", day names for recent messages, and full dates for older ones
                    </.changelog_item>
                    <.changelog_item icon="hero-chat-bubble-left-right" color="blue">
                      Message grouping — consecutive messages from the same person within 5 minutes are grouped together
                    </.changelog_item>
                    <.changelog_item icon="hero-bolt" color="amber">
                      Live updates preserve grouping context as new messages arrive
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.5"
                  date="December 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Accessibility First 🦖</:title>
                  <:description>
                    We've made accessibility a first-class feature across MOSSLET. The accessibility dino has been busy making sure everyone can enjoy a calm, private social experience.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-eye" color="purple">
                      Proper heading hierarchy and semantic HTML across all pages
                    </.changelog_item>
                    <.changelog_item icon="hero-cursor-arrow-rays" color="teal">
                      Enhanced keyboard navigation and focus management
                    </.changelog_item>
                    <.changelog_item icon="hero-megaphone" color="blue">
                      Improved screen reader support with ARIA labels and live regions
                    </.changelog_item>
                    <.changelog_item icon="hero-sun" color="amber">
                      Better color contrast and visual accessibility in both light and dark modes
                    </.changelog_item>
                    <.changelog_item icon="hero-device-phone-mobile" color="cyan">
                      Accessible forms, buttons, and interactive elements throughout
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.41"
                  date="November 2025"
                  tag="Feature"
                  tag_color="amber"
                >
                  <:title>UX Improvements & Load More Replies</:title>
                  <:description>
                    Smoother navigation and deeper conversations — timeline tabs now auto-center on selection, and you can load more replies to explore full discussions.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-arrows-right-left" color="teal">
                      Timeline tabs auto-center when selected on mobile for easier navigation
                    </.changelog_item>
                    <.changelog_item icon="hero-chat-bubble-left-right" color="purple">
                      Load more replies to dive deeper into conversations
                    </.changelog_item>
                    <.changelog_item icon="hero-device-phone-mobile" color="blue">
                      Improved mobile tab scrolling with smooth animations
                    </.changelog_item>
                    <.changelog_item icon="hero-sparkles" color="amber">
                      Refined unread count badges that never get clipped
                    </.changelog_item>
                  </:items>
                </.changelog_entry>
                <.changelog_entry
                  version="0.9.4"
                  date="November 2025"
                  tag="Feature"
                  tag_color="amber"
                >
                  <:title>Profile Privacy & Rich Link Previews</:title>
                  <:description>
                    Share your contact info safely and make your posts more engaging with automatic link previews.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-envelope" color="emerald">
                      Alternate email address — share contact info without exposing your account email
                    </.changelog_item>
                    <.changelog_item icon="hero-link" color="blue">
                      Rich URL previews in posts with automatic image, title, and description
                    </.changelog_item>
                    <.changelog_item icon="hero-globe-alt" color="purple">
                      Website link on profiles with beautiful preview cards
                    </.changelog_item>
                    <.changelog_item icon="hero-bolt" color="cyan">
                      Intelligent caching for faster link preview loading
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.9.0"
                  date="November 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Unlock Sessions & Profile Enhancements</:title>
                  <:description>
                    Stay logged in securely and share more about yourself with enhanced profiles.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-lock-open" color="teal">
                      Unlock Sessions — like a password manager for your account, your data stays encrypted until you unlock it
                    </.changelog_item>
                    <.changelog_item icon="hero-user-circle" color="purple">
                      Public profile viewing for sharing your profile with anyone
                    </.changelog_item>
                    <.changelog_item icon="hero-photo" color="amber">
                      New banner image picker with beautiful preset options
                    </.changelog_item>
                    <.changelog_item icon="hero-shield-check" color="rose">
                      Rate limiting on sensitive actions for enhanced security
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.8.0"
                  date="November 2025"
                  tag="Feature"
                  tag_color="purple"
                >
                  <:title>Calm Email Notifications</:title>
                  <:description>
                    Stay connected without the overwhelm — gentle, privacy-first email digests.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-envelope" color="blue">
                      Daily email digest with a calm summary of activity from your connections
                    </.changelog_item>
                    <.changelog_item icon="hero-clock" color="amber">
                      Maximum one email per day — we respect your inbox
                    </.changelog_item>
                    <.changelog_item icon="hero-user-group" color="emerald">
                      "Shared with you" indicator showing who can see each post
                    </.changelog_item>
                    <.changelog_item icon="hero-arrow-path" color="cyan">
                      Improved reply counts including nested conversations
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.7.0"
                  date="November 2025"
                  tag="Feature"
                  tag_color="amber"
                >
                  <:title>Timeline Performance & Live Status</:title>
                  <:description>
                    A faster, smarter timeline with real-time presence.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-bolt" color="cyan">
                      Major performance improvements for timeline loading
                    </.changelog_item>
                    <.changelog_item icon="hero-signal" color="emerald">
                      Privacy-first live status — only visible to connections you choose, never to us
                    </.changelog_item>
                    <.changelog_item icon="hero-arrow-path" color="blue">
                      Faster repost and reply stream performance
                    </.changelog_item>
                    <.changelog_item icon="hero-sparkles" color="purple">
                      Updated marketing site with demo video
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.6.0"
                  date="July 2025"
                  tag="Feature"
                  tag_color="blue"
                >
                  <:title>Wellbeing Features</:title>
                  <:description>
                    Tools to help you maintain a healthy relationship with social sharing.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-heart" color="rose">
                      "All caught up" indicator to help you disconnect
                    </.changelog_item>
                    <.changelog_item icon="hero-funnel" color="amber">
                      Content wellbeing filters to customize your feed
                    </.changelog_item>
                    <.changelog_item icon="hero-bookmark" color="purple">
                      Private bookmarks for saving posts
                    </.changelog_item>
                    <.changelog_item icon="hero-eye" color="teal">
                      Read/unread status for easier catch-up
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.changelog_entry
                  version="0.5.0"
                  date="June 2025"
                  tag="Rebrand"
                  tag_color="teal"
                >
                  <:title>Welcome to MOSSLET</:title>
                  <:description>
                    A fresh start — Metamorphic becomes MOSSLET with a refined vision for calm, private social sharing.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-home" color="emerald">
                      Clean, calm timeline for connecting with loved ones
                    </.changelog_item>
                    <.changelog_item icon="hero-lock-closed" color="purple">
                      End-to-end encryption for your private moments
                    </.changelog_item>
                    <.changelog_item icon="hero-photo" color="blue">
                      Secure photo sharing with privacy controls
                    </.changelog_item>
                    <.changelog_item icon="hero-bell" color="amber">
                      Gentle notifications that respect your time
                    </.changelog_item>
                    <.changelog_item icon="hero-user" color="cyan">
                      Simple profiles focused on genuine connection
                    </.changelog_item>
                  </:items>
                </.changelog_entry>

                <.time_gap_indicator years="3+" />

                <.changelog_entry
                  version="0.1.0"
                  date="February 2022"
                  tag="Origin"
                  tag_color="purple"
                >
                  <:title>Metamorphic is Born</:title>
                  <:description>
                    The original vision that would evolve into MOSSLET — privacy-first social sharing.
                  </:description>
                  <:items>
                    <.changelog_item icon="hero-sparkles" color="purple">
                      Initial concept and prototype development
                    </.changelog_item>
                    <.changelog_item icon="hero-shield-check" color="teal">
                      Privacy-by-design architecture foundations
                    </.changelog_item>
                    <.changelog_item icon="hero-heart" color="rose">
                      Core philosophy: technology that respects people
                    </.changelog_item>
                  </:items>
                </.changelog_entry>
              </div>
            </div>

            <.liquid_container max_width="xl" class="mt-24">
              <div class="mx-auto max-w-2xl">
                <.liquid_card
                  padding="lg"
                  class="text-center bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/10 dark:to-cyan-900/15 border-teal-200/60 dark:border-emerald-700/30"
                >
                  <:title>
                    <span class="text-xl font-bold tracking-tight sm:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                      Want to shape what comes next?
                    </span>
                  </:title>
                  <p class="mt-4 text-base leading-7 text-slate-700 dark:text-slate-300">
                    We build MOSSLET based on what you tell us. Have an idea or feature request? We'd love to hear from you.
                  </p>

                  <div class="mt-8 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-4">
                    <.liquid_button
                      href="mailto:support@mosslet.com"
                      size="md"
                      icon="hero-envelope"
                      color="teal"
                      variant="primary"
                    >
                      Share Your Ideas
                    </.liquid_button>
                    <.liquid_button
                      navigate="/features"
                      variant="secondary"
                      color="blue"
                      icon="hero-sparkles"
                      size="md"
                    >
                      Explore Features
                    </.liquid_button>
                  </div>
                </.liquid_card>
              </div>
            </.liquid_container>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  attr :version, :string, required: true
  attr :date, :string, required: true
  attr :tag, :string, default: nil
  attr :tag_color, :string, default: "teal"
  slot :title, required: true
  slot :description
  slot :items

  defp changelog_entry(assigns) do
    ~H"""
    <div class="relative pl-10 sm:pl-14">
      <div class={[
        "absolute left-0 sm:left-2 top-0 flex h-8 w-8 sm:h-10 sm:w-10 items-center justify-center rounded-full",
        "bg-gradient-to-br from-white via-slate-50 to-white dark:from-slate-800 dark:via-slate-700 dark:to-slate-800",
        "border border-slate-200/60 dark:border-slate-600/60",
        "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
        "ring-4 ring-white dark:ring-slate-900"
      ]}>
        <div class="h-2.5 w-2.5 sm:h-3 sm:w-3 rounded-full bg-gradient-to-r from-teal-500 to-emerald-500">
        </div>
      </div>

      <.liquid_card
        padding="lg"
        class="group hover:shadow-xl transition-all duration-300 ease-out"
      >
        <div class="flex flex-wrap items-center gap-3 mb-4">
          <span class="text-sm font-semibold text-slate-500 dark:text-slate-400">
            v{@version}
          </span>
          <span class="text-slate-300 dark:text-slate-600">•</span>
          <span class="text-sm text-slate-500 dark:text-slate-400">
            {@date}
          </span>
          <.changelog_tag :if={@tag} color={@tag_color}>{@tag}</.changelog_tag>
        </div>

        <:title>
          <span class="text-xl sm:text-2xl font-bold bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
            {render_slot(@title)}
          </span>
        </:title>

        <p :if={@description != []} class="mt-3 text-slate-600 dark:text-slate-400 leading-relaxed">
          {render_slot(@description)}
        </p>

        <ul :if={@items != []} class="mt-6 space-y-3">
          {render_slot(@items)}
        </ul>
      </.liquid_card>
    </div>
    """
  end

  attr :color, :string, default: "teal"
  slot :inner_block, required: true

  defp changelog_tag(assigns) do
    color_classes = %{
      "teal" =>
        "bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 border-teal-200/60 dark:border-teal-700/40",
      "emerald" =>
        "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300 border-emerald-200/60 dark:border-emerald-700/40",
      "blue" =>
        "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 border-blue-200/60 dark:border-blue-700/40",
      "amber" =>
        "bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 border-amber-200/60 dark:border-amber-700/40",
      "rose" =>
        "bg-rose-100 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300 border-rose-200/60 dark:border-rose-700/40",
      "purple" =>
        "bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 border-purple-200/60 dark:border-purple-700/40"
    }

    assigns =
      assign(assigns, :color_class, Map.get(color_classes, assigns.color, color_classes["teal"]))

    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border",
      @color_class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :icon, :string, required: true
  attr :color, :string, default: "teal"
  slot :inner_block, required: true

  defp changelog_item(assigns) do
    icon_colors = %{
      "teal" => "text-teal-600 dark:text-teal-400",
      "emerald" => "text-emerald-600 dark:text-emerald-400",
      "blue" => "text-blue-600 dark:text-blue-400",
      "cyan" => "text-cyan-600 dark:text-cyan-400",
      "amber" => "text-amber-600 dark:text-amber-400",
      "rose" => "text-rose-600 dark:text-rose-400",
      "purple" => "text-purple-600 dark:text-purple-400",
      "indigo" => "text-indigo-600 dark:text-indigo-400"
    }

    assigns =
      assign(assigns, :icon_color, Map.get(icon_colors, assigns.color, icon_colors["teal"]))

    ~H"""
    <li class="flex items-start gap-3 group/item">
      <div class={[
        "flex h-6 w-6 shrink-0 items-center justify-center rounded-lg mt-0.5",
        "bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100",
        "dark:from-slate-700 dark:via-slate-600 dark:to-slate-700",
        "group-hover/item:from-teal-100 group-hover/item:via-emerald-50 group-hover/item:to-cyan-100",
        "dark:group-hover/item:from-teal-900/30 dark:group-hover/item:via-emerald-900/25 dark:group-hover/item:to-cyan-900/30",
        "transition-all duration-200 ease-out"
      ]}>
        <.phx_icon name={@icon} class={["h-3.5 w-3.5", @icon_color]} />
      </div>
      <span class="text-slate-700 dark:text-slate-300 leading-relaxed">
        {render_slot(@inner_block)}
      </span>
    </li>
    """
  end

  attr :years, :string, required: true

  defp time_gap_indicator(assigns) do
    ~H"""
    <div class="relative pl-10 sm:pl-14 py-8">
      <div class="absolute left-4 sm:left-6 top-0 bottom-0 w-px">
        <div class="h-full w-full bg-gradient-to-b from-cyan-400/40 via-transparent to-purple-400/40 dark:from-cyan-500/30 dark:via-transparent dark:to-purple-500/30">
        </div>
      </div>

      <div class="absolute left-0 sm:left-2 top-1/2 -translate-y-1/2 flex flex-col items-center gap-2">
        <div class="h-2 w-2 rounded-full bg-gradient-to-r from-teal-400 to-emerald-400 animate-pulse">
        </div>
        <div class="h-2 w-2 rounded-full bg-gradient-to-r from-emerald-400 to-cyan-400 animate-pulse [animation-delay:200ms]">
        </div>
        <div class="h-2 w-2 rounded-full bg-gradient-to-r from-cyan-400 to-purple-400 animate-pulse [animation-delay:400ms]">
        </div>
      </div>

      <div class="flex items-center justify-center">
        <div class="inline-flex items-center gap-3 px-6 py-3 rounded-full bg-gradient-to-r from-slate-50 via-white to-slate-50 dark:from-slate-800/80 dark:via-slate-700/60 dark:to-slate-800/80 border border-slate-200/60 dark:border-slate-600/40 shadow-sm">
          <span class="text-sm font-medium text-slate-500 dark:text-slate-400">
            {@years} years of building
          </span>
          <div class="flex gap-1">
            <div class="h-1.5 w-1.5 rounded-full bg-gradient-to-r from-teal-400 to-emerald-400"></div>
            <div class="h-1.5 w-1.5 rounded-full bg-gradient-to-r from-emerald-400 to-cyan-400"></div>
            <div class="h-1.5 w-1.5 rounded-full bg-gradient-to-r from-cyan-400 to-purple-400"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
