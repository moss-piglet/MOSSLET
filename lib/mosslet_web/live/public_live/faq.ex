defmodule MossletWeb.PublicLive.Faq do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:faq}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <.liquid_faq_simple
        title="Frequently Asked Questions"
        subtitle="Everything you need to know about MOSSLET"
        description="Our privacy-first social network prioritizes your data security and human dignity. Find answers to common questions below."
        sections={@faq_sections}
      />
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    faq_sections = [
      %{
        title: "About MOSSLET",
        questions: [
          %{
            q: "What is MOSSLET?",
            a:
              "MOSSLET is a privacy-first social network designed to protect your privacy and human dignity from surveillance and the attention economy. We prioritize data protection while creating a safe space for meaningful social interactions."
          },
          %{
            q: "How is MOSSLET different from other social networks?",
            a:
              "Unlike traditional social networks that rely on advertising and data exploitation, MOSSLET uses a one-time payment model. This means we don't spy on you, sell your data, or manipulate you with algorithms designed to capture your attention."
          },
          %{
            q: "Who can use MOSSLET?",
            a:
              "MOSSLET is designed for anyone who values their privacy and wants meaningful social connections without surveillance. Our platform welcomes users who prefer quality interactions over endless scrolling."
          }
        ]
      },
      %{
        title: "Privacy & Security",
        questions: [
          %{
            q: "How does MOSSLET protect my privacy?",
            a:
              "MOSSLET employs end-to-end encryption to ensure your data remains private and secure. Only you and your intended recipients can access your messages and information, keeping your interactions confidential."
          },
          %{
            q: "What data does MOSSLET collect?",
            a:
              "We collect only the minimal data necessary to provide our service: your email (for account access), encrypted messages and posts you create, and basic account settings. We never track your browsing habits or sell your information."
          },
          %{
            q: "Can I delete my account and data?",
            a:
              "Yes! You have complete control over your data. You can delete your account at any time, and all your data will be permanently removed from our servers within 7 days."
          },
          %{
            q: "Where is my data stored?",
            a:
              "Your encrypted data is stored on secure servers provided by Fly.io, protected with industry-standard security measures. All data is encrypted before storage and transmission."
          }
        ]
      },
      %{
        title: "Pricing & Access",
        questions: [
          %{
            q: "How much does MOSSLET cost?",
            a:
              "MOSSLET uses a simple one-time payment model. During our beta phase, lifetime access costs $59. This single payment gives you permanent access to all current and future features."
          },
          %{
            q: "Why do you charge a fee instead of being 'free'?",
            a:
              "Nothing is truly free. Other social networks make money by harvesting and selling your personal data, which can be worth $500-700+ per year. We believe in honest pricing - you pay us directly, so we work for you, not advertisers."
          },
          %{
            q: "Are there any recurring fees or subscriptions?",
            a:
              "No! One payment, lifetime access. We don't believe in subscription fatigue or holding your data hostage with monthly fees."
          },
          %{
            q: "What if I'm not satisfied?",
            a:
              "We're confident you'll love MOSSLET, but if you're not satisfied within 30 days of purchase, we offer a full refund, no questions asked."
          }
        ]
      },
      %{
        title: "Features & Usage",
        questions: [
          %{
            q: "What features does MOSSLET include?",
            a:
              "MOSSLET includes private messaging, group conversations, photo sharing (Memories), friend connections, and a clean, ad-free interface. We're continuously adding features based on user feedback."
          },
          %{
            q: "Is there a mobile app?",
            a:
              "Not yet, but you can add MOSSLET to your phone's home screen directly from your mobile browser for a native app-like experience. A dedicated mobile app is in development."
          },
          %{
            q: "Can I make public posts?",
            a:
              "Currently, all posts on MOSSLET are private and shared only with your chosen connections. We're considering public posting features for future releases based on user demand."
          },
          %{
            q: "How do I connect with friends?",
            a:
              "You can send friend requests through our private invitation system. This ensures that only people you actually know can connect with you, maintaining the quality and safety of your network."
          }
        ]
      },
      %{
        title: "Technical Support",
        questions: [
          %{
            q: "What if I forget my password?",
            a:
              "You can enable our optional password recovery feature in your settings. If disabled for maximum security, we cannot recover your account - your privacy is that protected! We recommend using a password manager."
          },
          %{
            q: "Is my data encrypted?",
            a:
              "Yes! Your personal data is encrypted with your password-derived key, meaning only you can access it. We then add an additional layer of encryption before storing it on our servers."
          },
          %{
            q: "How do I get help or report issues?",
            a:
              "Contact our human support team at support@mosslet.com. We're real people who actually want to help, not bots or outsourced customer service."
          },
          %{
            q: "Do you have a privacy policy?",
            a:
              "Yes! You can read our comprehensive privacy policy and terms of service, written in plain English. We believe in transparency about how we handle your data."
          }
        ]
      }
    ]

    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "FAQ - Frequently Asked Questions")
     |> assign(:faq_sections, faq_sections)
     |> assign_new(:meta_description, fn ->
       "Frequently asked questions about MOSSLET, the privacy-first social network. Learn about our security, pricing, features, and how we protect your data without selling it to advertisers."
     end)}
  end
end
