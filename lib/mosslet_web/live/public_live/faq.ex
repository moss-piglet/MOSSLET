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
        description="A zero-knowledge, post-quantum encrypted social network that keeps your data private by encrypting everything in your browser. Find answers to common questions below."
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
              "MOSSLET uses zero-knowledge encryption — your data is encrypted and decrypted entirely in your browser using our open-source Rust cryptographic library compiled to WebAssembly. Our servers store only encrypted data that we genuinely cannot read. Only you and your intended recipients can access your content."
          },
          %{
            q: "What does 'zero-knowledge' mean?",
            a:
              "Zero-knowledge means our servers never see your data in plaintext. All encryption and decryption happens in your browser. Even if our database were breached, attackers would find only encrypted blobs — useless without your password-derived key."
          },
          %{
            q: "What is post-quantum encryption?",
            a:
              "Post-quantum encryption protects your data against future quantum computers that could break today's standard encryption. MOSSLET uses ML-KEM-1024 (NIST Cat-5, the highest security level) combined with classical X25519, so your data is safe both now and in the future."
          },
          %{
            q: "What data does MOSSLET collect?",
            a:
              "We store only encrypted blobs and blind-index hashes needed for lookups (like finding your account by email). We never track your browsing habits or sell your information. Your plaintext email is used only transiently for sending emails — only the encrypted version and a one-way hash are stored."
          },
          %{
            q: "Can I delete my account and data?",
            a:
              "Yes! You have complete control over your data. You can delete your account at any time, and all your data will be permanently removed from our servers immediately and in real-time."
          },
          %{
            q: "Where is my data stored?",
            a:
              "Your encrypted data is stored on secure servers provided by Fly.io, protected by a private WireGuard network. All data has two layers of encryption: zero-knowledge encryption from your browser plus AES-256-GCM at-rest encryption in the database."
          },
          %{
            q: "Is my data encrypted?",
            a:
              "Yes! Your data is encrypted in your browser before it ever reaches our servers, using the same open-source Rust code that runs on both your browser (via WebAssembly) and our server (as a native module). On top of that, all stored data is wrapped in a second layer of AES-256-GCM encryption. Key distribution uses hybrid post-quantum key encapsulation (ML-KEM-1024 + X25519)."
          }
        ]
      },
      %{
        title: "AI Safety & Privacy",
        questions: [
          %{
            q: "How do AI safety checks work on MOSSLET?",
            a:
              "For non-public content, image safety checks run entirely in your browser using a lightweight AI model — your private images are never sent to our servers or any external service. Public posts have both content and image checks server-side using our own models. This ensures community safety while preserving zero-knowledge privacy for your personal content."
          },
          %{
            q: "Is my content used to train AI models?",
            a:
              "Absolutely not. Your content is never stored or used for AI training. For public content that goes through server-side checks, we route requests through OpenRouter with all data retention and training options disabled. The AI processes your content, returns a result, and that's it — nothing is kept."
          },
          %{
            q: "Can the AI provider see who I am?",
            a:
              "No. For non-public content, the AI model runs locally in your browser — no external service is involved at all. For public content checks routed through OpenRouter, no account information is included. The AI provider only sees that a request came from OpenRouter — they have no way to know whose content it is."
          },
          %{
            q: "What happens to my content after an AI check?",
            a:
              "For non-public content, the check happens entirely in your browser — your data never leaves your device. For public posts, the check runs server-side on our own infrastructure, the result is stored, and no content is retained from the AI interaction."
          },
          %{
            q: "Why do you check images on private posts but not text?",
            a:
              "We believe in minimal intervention. Image safety checks for private content run in your browser to help prevent harmful visual content — your images never leave your device during this process. But your private conversations and written thoughts are yours — we don't read them, and neither does AI. Public posts have full checks because they're visible to everyone."
          },
          %{
            q: "How do you detect AI-generated images?",
            a:
              "We use AI detection to identify generated imagery and display a clear badge when detected. This helps maintain authenticity in your connections — you'll always know if an image was created by AI. The detection follows the same privacy-first approach: no storage, no training, no account data sent."
          },
          %{
            q: "What is OpenRouter and why do you use it?",
            a:
              "OpenRouter is a privacy-focused AI routing service that we use for public content checks only. We've disabled all data retention and model training options. For non-public content, AI checks run locally in your browser — OpenRouter is never involved."
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
              "You can choose from monthly, yearly, or lifetime access. Monthly gives you flexibility, yearly offers a better rate, and lifetime means one payment for permanent access. We also support Affirm for splitting lifetime payments."
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
              "MOSSLET includes private and public posting, direct messaging, group conversations (Circles), photo sharing, friend connections, an encrypted journal, Bluesky integration, and a clean, ad-free interface. We're continuously adding features based on user feedback."
          },
          %{
            q: "Is there a mobile app?",
            a:
              "Not yet, but you can add MOSSLET to your phone's home screen directly from your mobile browser for a native app-like experience. Dedicated apps for mobile and desktop are in development."
          },
          %{
            q: "Can I make public posts?",
            a:
              "Yes! You can create public posts visible to everyone, or share privately with your connections, specific groups, or specific people. Public posts can also be cross-posted to Bluesky."
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
              "You can set up a recovery key in your settings — a one-time code that lets you reset your password without losing access to your encrypted data. If you haven't set up a recovery key and forget your password, your data cannot be recovered by design (zero-knowledge). We recommend using a password manager and setting up your recovery key."
          },
          %{
            q: "Is my data encrypted?",
            a:
              "Yes! Your data is encrypted in your browser before it ever reaches our servers — that's what zero-knowledge means. We then add a second layer of AES-256-GCM encryption at rest. Key distribution uses hybrid post-quantum encryption (ML-KEM-1024, NIST Cat-5) to protect against future quantum computers."
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
