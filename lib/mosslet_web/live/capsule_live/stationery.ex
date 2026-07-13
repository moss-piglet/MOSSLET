defmodule MossletWeb.CapsuleLive.Stationery do
  @moduledoc """
  Presentation helpers for time-capsule "stationery" — the cosmetic letter
  themes. Purely visual; no content ever flows through here.

  Each theme returns a map of Tailwind class strings for the letter paper,
  the envelope, and accents, so the compose / mailbox / reader surfaces share
  one consistent, calm aesthetic within the design system.
  """

  @default "classic"

  @themes %{
    "classic" => %{
      label: "Classic",
      swatch: "bg-gradient-to-br from-amber-50 to-orange-50",
      paper:
        "bg-gradient-to-br from-amber-50 to-orange-50/60 dark:from-amber-950/40 dark:to-orange-950/30 text-slate-800 dark:text-amber-50",
      envelope:
        "bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/40 dark:to-orange-900/30",
      accent: "text-amber-700 dark:text-amber-300",
      ring: "ring-amber-300 dark:ring-amber-700"
    },
    "tangerine" => %{
      label: "Tangerine",
      swatch: "bg-gradient-to-br from-orange-200 to-amber-200",
      paper:
        "bg-gradient-to-br from-orange-50 to-amber-50/60 dark:from-orange-950/40 dark:to-amber-950/30 text-slate-800 dark:text-orange-50",
      envelope:
        "bg-gradient-to-br from-orange-100 to-amber-100 dark:from-orange-900/40 dark:to-amber-900/30",
      accent: "text-orange-700 dark:text-orange-300",
      ring: "ring-orange-300 dark:ring-orange-700"
    },
    "sunset" => %{
      label: "Sunset",
      swatch: "bg-gradient-to-br from-orange-300 to-rose-300",
      paper:
        "bg-gradient-to-br from-orange-50 to-rose-50/60 dark:from-orange-950/40 dark:to-rose-950/30 text-slate-800 dark:text-orange-50",
      envelope:
        "bg-gradient-to-br from-orange-200 to-rose-200 dark:from-orange-900/40 dark:to-rose-900/30",
      accent: "text-rose-700 dark:text-orange-300",
      ring: "ring-orange-300 dark:ring-rose-700"
    },
    "linen" => %{
      label: "Linen",
      swatch: "bg-gradient-to-br from-stone-50 to-neutral-100",
      paper:
        "bg-gradient-to-br from-stone-50 to-neutral-100/70 dark:from-stone-900/50 dark:to-neutral-900/40 text-slate-800 dark:text-stone-100",
      envelope:
        "bg-gradient-to-br from-stone-100 to-neutral-200 dark:from-stone-800/50 dark:to-neutral-800/40",
      accent: "text-stone-600 dark:text-stone-300",
      ring: "ring-stone-300 dark:ring-stone-700"
    },
    "dusk" => %{
      label: "Dusk",
      swatch: "bg-gradient-to-br from-violet-100 to-fuchsia-100",
      paper:
        "bg-gradient-to-br from-violet-50 to-fuchsia-50/60 dark:from-violet-950/40 dark:to-fuchsia-950/30 text-slate-800 dark:text-violet-50",
      envelope:
        "bg-gradient-to-br from-violet-100 to-fuchsia-100 dark:from-violet-900/40 dark:to-fuchsia-900/30",
      accent: "text-violet-700 dark:text-violet-300",
      ring: "ring-violet-300 dark:ring-violet-700"
    },
    "lavender" => %{
      label: "Lavender",
      swatch: "bg-gradient-to-br from-purple-100 to-indigo-100",
      paper:
        "bg-gradient-to-br from-purple-50 to-indigo-50/60 dark:from-purple-950/40 dark:to-indigo-950/30 text-slate-800 dark:text-purple-50",
      envelope:
        "bg-gradient-to-br from-purple-100 to-indigo-100 dark:from-purple-900/40 dark:to-indigo-900/30",
      accent: "text-purple-700 dark:text-purple-300",
      ring: "ring-purple-300 dark:ring-purple-700"
    },
    "meadow" => %{
      label: "Meadow",
      swatch: "bg-gradient-to-br from-emerald-100 to-lime-100",
      paper:
        "bg-gradient-to-br from-emerald-50 to-lime-50/60 dark:from-emerald-950/40 dark:to-lime-950/30 text-slate-800 dark:text-emerald-50",
      envelope:
        "bg-gradient-to-br from-emerald-100 to-lime-100 dark:from-emerald-900/40 dark:to-lime-900/30",
      accent: "text-emerald-700 dark:text-emerald-300",
      ring: "ring-emerald-300 dark:ring-emerald-700"
    },
    "sage" => %{
      label: "Sage",
      swatch: "bg-gradient-to-br from-green-100 to-teal-100",
      paper:
        "bg-gradient-to-br from-green-50 to-teal-50/60 dark:from-green-950/40 dark:to-teal-950/30 text-slate-800 dark:text-green-50",
      envelope:
        "bg-gradient-to-br from-green-100 to-teal-100 dark:from-green-900/40 dark:to-teal-900/30",
      accent: "text-green-700 dark:text-green-300",
      ring: "ring-green-300 dark:ring-green-700"
    },
    "tide" => %{
      label: "Tide",
      swatch: "bg-gradient-to-br from-sky-100 to-cyan-100",
      paper:
        "bg-gradient-to-br from-sky-50 to-cyan-50/60 dark:from-sky-950/40 dark:to-cyan-950/30 text-slate-800 dark:text-sky-50",
      envelope:
        "bg-gradient-to-br from-sky-100 to-cyan-100 dark:from-sky-900/40 dark:to-cyan-900/30",
      accent: "text-sky-700 dark:text-sky-300",
      ring: "ring-sky-300 dark:ring-sky-700"
    },
    "rose" => %{
      label: "Rose",
      swatch: "bg-gradient-to-br from-rose-100 to-pink-100",
      paper:
        "bg-gradient-to-br from-rose-50 to-pink-50/60 dark:from-rose-950/40 dark:to-pink-950/30 text-slate-800 dark:text-rose-50",
      envelope:
        "bg-gradient-to-br from-rose-100 to-pink-100 dark:from-rose-900/40 dark:to-pink-900/30",
      accent: "text-rose-700 dark:text-rose-300",
      ring: "ring-rose-300 dark:ring-rose-700"
    },
    "parchment" => %{
      label: "Parchment",
      swatch: "bg-gradient-to-br from-yellow-50 to-amber-100",
      paper:
        "bg-gradient-to-br from-yellow-50 to-amber-100/60 dark:from-yellow-950/40 dark:to-amber-950/30 text-slate-800 dark:text-yellow-50",
      envelope:
        "bg-gradient-to-br from-yellow-100 to-amber-200 dark:from-yellow-900/40 dark:to-amber-900/30",
      accent: "text-yellow-700 dark:text-yellow-300",
      ring: "ring-yellow-300 dark:ring-yellow-700"
    },
    "midnight" => %{
      label: "Midnight",
      swatch: "bg-gradient-to-br from-slate-200 to-indigo-200",
      paper:
        "bg-gradient-to-br from-slate-100 to-indigo-100/60 dark:from-slate-900/70 dark:to-indigo-950/50 text-slate-800 dark:text-indigo-50",
      envelope:
        "bg-gradient-to-br from-slate-200 to-indigo-200 dark:from-slate-800/60 dark:to-indigo-900/50",
      accent: "text-indigo-700 dark:text-indigo-300",
      ring: "ring-indigo-300 dark:ring-indigo-700"
    }
  }

  def default, do: @default

  def all, do: Mosslet.Capsules.Capsule.stationeries()

  def theme(name) when is_binary(name), do: Map.get(@themes, name, @themes[@default])
  def theme(_), do: @themes[@default]

  def label(name), do: theme(name).label
end
