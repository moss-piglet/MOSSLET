defmodule Mosslet.Safety do
  @moduledoc """
  Curated, area-aware safety & crisis resources for the public `/safety` page.

  This module is deliberately a **static, hand-curated directory plus a global
  fallback**, not a self-maintained worldwide hotline database. Shipping wrong
  crisis numbers is the worst kind of bug, so:

  - For the **United States** (our primary audience) we list a small set of
    national, 24/7 hotlines that **auto-route the caller to their local agency**
    (e.g. Childhelp). A ZIP/postal code is resolved to a US state purely for
    friendly confirmation and future per-state expansion — the numbers are
    national regardless.
  - For **everywhere else** we route people to maintained, localized global
    directories (Find A Helpline, Child Helpline International) and their local
    emergency number, rather than guessing per-country numbers we cannot keep
    accurate.

  Nothing here is personal data: the ZIP is processed in-memory in the LiveView
  to pick a region label and is never stored or sent to a third party.
  """

  @typedoc "A single help resource entry rendered as a card."
  @type resource :: %{
          name: String.t(),
          description: String.t(),
          phone: String.t() | nil,
          text: String.t() | nil,
          url: String.t(),
          icon: String.t(),
          gradient: String.t()
        }

  @doc """
  US national resources. Each is free, confidential, and 24/7 unless noted, and
  routes the caller to the appropriate local agency where relevant.
  """
  @spec us_resources() :: [resource()]
  def us_resources do
    [
      %{
        name: "988 Suicide & Crisis Lifeline",
        description:
          "Free, confidential support for anyone in distress — emotional crisis, suicidal thoughts, or just needing someone to talk to. Available 24/7.",
        phone: "988",
        text: "Text 988",
        url: "https://988lifeline.org",
        icon: "hero-lifebuoy",
        gradient: "from-teal-500 to-emerald-500"
      },
      %{
        name: "Childhelp National Child Abuse Hotline",
        description:
          "If you're being hurt, controlled, or made to feel unsafe by a parent or guardian, trained counselors can help — and connect you to the right local agency. 24/7.",
        phone: "1-800-422-4453",
        text: nil,
        url: "https://childhelphotline.org",
        icon: "hero-shield-check",
        gradient: "from-blue-500 to-cyan-500"
      },
      %{
        name: "National Domestic Violence Hotline",
        description:
          "Support for anyone experiencing coercion, control, or abuse in their household or relationships. Confidential, 24/7, in many languages.",
        phone: "1-800-799-7233",
        text: "Text START to 88788",
        url: "https://www.thehotline.org",
        icon: "hero-hand-raised",
        gradient: "from-purple-500 to-violet-500"
      },
      %{
        name: "Crisis Text Line",
        description:
          "Prefer texting? Reach a trained crisis counselor by text for any kind of crisis. Free and confidential, 24/7.",
        phone: nil,
        text: "Text HOME to 741741",
        url: "https://www.crisistextline.org",
        icon: "hero-chat-bubble-left-right",
        gradient: "from-amber-500 to-orange-500"
      },
      %{
        name: "NCMEC CyberTipline",
        description:
          "Report online exploitation, sextortion, or someone pressuring you to share images. Run by the National Center for Missing & Exploited Children.",
        phone: "1-800-843-5678",
        text: nil,
        url: "https://report.cybertip.org",
        icon: "hero-exclamation-triangle",
        gradient: "from-rose-500 to-pink-500"
      },
      %{
        name: "StopBullying.gov",
        description:
          "Official US government guidance on dealing with bullying and cyberbullying, including how to get help and report it.",
        phone: nil,
        text: nil,
        url: "https://www.stopbullying.gov",
        icon: "hero-academic-cap",
        gradient: "from-indigo-500 to-blue-500"
      }
    ]
  end

  @doc """
  Global resources used for any non-US country (and shown to everyone as a
  worldwide fallback). These directories localize results to the visitor's own
  country and are kept up to date by their operators.
  """
  @spec global_resources() :: [resource()]
  def global_resources do
    [
      %{
        name: "Find A Helpline",
        description:
          "Free, confidential support lines in over 130 countries. Pick your country to find verified crisis and support services near you.",
        phone: nil,
        text: nil,
        url: "https://findahelpline.com",
        icon: "hero-globe-alt",
        gradient: "from-teal-500 to-emerald-500"
      },
      %{
        name: "Child Helpline International",
        description:
          "A network of child helplines around the world. Find the helpline for your country if you're a young person who needs help or someone to talk to.",
        phone: nil,
        text: nil,
        url: "https://childhelplineinternational.org/helplines/",
        icon: "hero-heart",
        gradient: "from-blue-500 to-cyan-500"
      }
    ]
  end

  @doc """
  Countries offered in the area selector. The US is curated in depth; every
  other country routes to the maintained global directories above.

  Returns `[{label, code}]`. `"US"` is special-cased; all other codes share the
  global path, so we keep the list short and honest rather than implying
  per-country depth we don't have.
  """
  @spec countries() :: [{String.t(), String.t()}]
  def countries do
    [
      {"United States", "US"},
      {"Canada", "CA"},
      {"United Kingdom", "GB"},
      {"Ireland", "IE"},
      {"Australia", "AU"},
      {"New Zealand", "NZ"},
      {"Other / not listed", "OTHER"}
    ]
  end

  @doc """
  True when the given country code uses the curated US resource set.
  """
  @spec us?(String.t() | nil) :: boolean()
  def us?(code), do: code == "US"

  @doc """
  Resolve a US ZIP code to its state name, for friendly confirmation and future
  per-state expansion. The national hotlines apply regardless of the result.

  Returns `{:ok, state_name}` for a recognizable 5-digit (or ZIP+4) US ZIP,
  otherwise `:error`. Whitespace and a trailing `-1234` are tolerated.
  """
  @spec resolve_us_state(String.t() | nil) :: {:ok, String.t()} | :error
  def resolve_us_state(nil), do: :error

  def resolve_us_state(zip) when is_binary(zip) do
    digits =
      zip
      |> String.trim()
      |> String.replace(~r/[^0-9]/, "")

    if String.length(digits) >= 3 do
      prefix = digits |> String.slice(0, 3) |> String.to_integer()
      state_for_prefix(prefix)
    else
      :error
    end
  end

  # Standard USPS leading-3-digit ZIP prefix → state assignments. A handful of
  # tiny exceptions (e.g. 055 = MA) are intentionally folded into the dominant
  # range; the resolved state is cosmetic (the hotlines are national), so this
  # is "good enough and never wrong about the country."
  @prefix_ranges [
    {5, 5, "New York"},
    {6, 9, "Puerto Rico & U.S. Virgin Islands"},
    {10, 27, "Massachusetts"},
    {28, 29, "Rhode Island"},
    {30, 38, "New Hampshire"},
    {39, 49, "Maine"},
    {50, 59, "Vermont"},
    {60, 69, "Connecticut"},
    {70, 89, "New Jersey"},
    {100, 149, "New York"},
    {150, 196, "Pennsylvania"},
    {197, 199, "Delaware"},
    {200, 205, "District of Columbia"},
    {206, 219, "Maryland"},
    {220, 246, "Virginia"},
    {247, 268, "West Virginia"},
    {270, 289, "North Carolina"},
    {290, 299, "South Carolina"},
    {300, 319, "Georgia"},
    {320, 349, "Florida"},
    {350, 369, "Alabama"},
    {370, 385, "Tennessee"},
    {386, 397, "Mississippi"},
    {398, 399, "Georgia"},
    {400, 427, "Kentucky"},
    {430, 459, "Ohio"},
    {460, 479, "Indiana"},
    {480, 499, "Michigan"},
    {500, 528, "Iowa"},
    {530, 549, "Wisconsin"},
    {550, 567, "Minnesota"},
    {570, 577, "South Dakota"},
    {580, 588, "North Dakota"},
    {590, 599, "Montana"},
    {600, 629, "Illinois"},
    {630, 658, "Missouri"},
    {660, 679, "Kansas"},
    {680, 693, "Nebraska"},
    {700, 714, "Louisiana"},
    {716, 729, "Arkansas"},
    {730, 749, "Oklahoma"},
    {750, 799, "Texas"},
    {800, 816, "Colorado"},
    {820, 831, "Wyoming"},
    {832, 838, "Idaho"},
    {840, 847, "Utah"},
    {850, 865, "Arizona"},
    {870, 884, "New Mexico"},
    {885, 885, "Texas"},
    {889, 898, "Nevada"},
    {900, 961, "California"},
    {967, 968, "Hawaii"},
    {969, 969, "Guam & Pacific Territories"},
    {970, 979, "Oregon"},
    {980, 994, "Washington"},
    {995, 999, "Alaska"}
  ]

  defp state_for_prefix(prefix) do
    Enum.find_value(@prefix_ranges, :error, fn {lo, hi, state} ->
      if prefix >= lo and prefix <= hi, do: {:ok, state}
    end)
  end
end
