defmodule MossletWeb.PublicLive.Faq do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:faq}
      container_max_width={@max_width}
      socket={@socket}
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
              "Unlike traditional social networks that rely on advertising and data exploitation, MOSSLET is funded directly by our users. This means we don't spy on you, sell your data, or manipulate you with algorithms designed to capture your attention."
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
              "Yes! You have complete control over your data. You can delete your account at any time, and all your data will be permanently removed from our servers immediately and in real-time."
          },
          %{
            q: "Where is my data stored?",
            a:
              "Your encrypted data is stored on secure servers provided by Fly.io, protected with industry-standard security measures. All data is encrypted before storage and transmission."
          }
        ]
      },
      %{
        title: "AI Safety & Privacy",
        questions: [
          %{
            q: "How do AI safety checks work on MOSSLET?",
            a:
              "We use privacy-first AI to help keep our community healthy. Public posts are checked for both content and images, while non-public posts only have image safety checks — your private text stays between you and your connections. All checks happen in real-time without storing your content."
          },
          %{
            q: "Is my content used to train AI models?",
            a:
              "Absolutely not. Your content is never stored or used for AI training. We route requests through OpenRouter with all data retention and training options disabled. The AI processes your content, returns a result, and that's it — nothing is kept."
          },
          %{
            q: "Can the AI provider see who I am?",
            a:
              "No. When we send content for safety checks, no account information is included. The AI provider only sees that a request came from mosslet.com — they have no way to know whose content it is or link it to any user account."
          },
          %{
            q: "What happens to my content after an AI check?",
            a:
              "After the safety check completes, your content remains asymmetrically encrypted on our servers. The AI never sees your encrypted data — we only decrypt temporarily for the check, get the result, and your content stays protected. Nothing is logged or stored from the AI interaction."
          },
          %{
            q: "Why do you check images on private posts but not text?",
            a:
              "We believe in minimal intervention. Image safety checks help prevent harmful visual content from spreading, even in private contexts. But your private conversations and written thoughts are yours — we don't read them, and neither does AI. Public posts have full checks because they're visible to everyone."
          },
          %{
            q: "How do you detect AI-generated images?",
            a:
              "We use AI detection to identify generated imagery and display a clear badge when detected. This helps maintain authenticity in your connections — you'll always know if an image was created by AI. The detection follows the same privacy-first approach: no storage, no training, no account data sent."
          },
          %{
            q: "What is OpenRouter and why do you use it?",
            a:
              "OpenRouter is a privacy-focused AI routing service that lets us access AI capabilities while maintaining strict data protection. We've disabled all data retention and model training options. It acts as a secure intermediary that never stores your content or links requests to user identities."
          }
        ]
      },
      %{
        title: "Pricing & Access",
        questions: [
          %{
            q: "How much does MOSSLET cost?",
            a:
              "MOSSLET offers flexible pricing options: a monthly subscription, an annual plan at a discounted rate, or a one-time lifetime access payment. All plans include a free trial so you can try before you commit."
          },
          %{
            q: "Why do you charge a fee instead of being 'free'?",
            a:
              "Nothing is truly free. Other social networks make money by harvesting and selling your personal data, which can be worth $500-700+ per year. We believe in honest pricing - you pay us directly, so we work for you, not advertisers."
          },
          %{
            q: "What payment options do you offer?",
            a:
              "You can choose from monthly, yearly, or lifetime access. Monthly gives you flexibility, yearly offers a better rate, and lifetime means one payment for permanent access. We also support Affirm for splitting larger payments."
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
              "Not yet, but you can add MOSSLET to your phone's home screen directly from your mobile browser for a native app-like experience. Dedicated apps for mobile and desktop are in development."
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
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/faq/faq_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Everything you need to know about MOSSLET"
     )}
  end
end
