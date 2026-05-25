defmodule MossletWeb.PublicLive.Blog.Blog17 do
  @moduledoc false
  use MossletWeb, :live_view
  alias MossletWeb.PublicLive.Blog.Components

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:blog}
      container_max_width={@max_width}
    >
      <Components.blog_article
        date="May 25, 2026"
        title="We Can't Read Your Data. Here's How."
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          When we launched Conversations back in March, we made a promise: your messages would be encrypted before they ever left your device, and our servers would never see the plaintext. That was true for messaging. Today, it's true for everything.
        </p>
        <p>
          Every post you write. Every journal entry. Every image you upload. Every profile field, group name, connection detail, and bookmark note. All of it is now encrypted and decrypted entirely in your browser. Our servers handle only encrypted blobs that are meaningless without your key.
        </p>
        <p>
          This isn't a feature toggle or a premium tier. It's the architecture. It's how MOSSLET works now, for everyone.
        </p>

        <hr />
        <h2 id="what-changed">
          <a href="#what-changed">
            What changed
          </a>
        </h2>
        <p>
          When we first built MOSSLET, encryption happened on our server. Your data was encrypted before storage, but the server saw the plaintext briefly during the process. That was always the plan for phase one — get the encryption right, then move it to the browser where the server can't see it at all.
        </p>
        <p>
          Over the past several months, we've systematically migrated every encrypted operation from the server to your browser. The cryptographic primitives are the same — we built an open-source Rust library called
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/metamorphic-crypto"
          >
            metamorphic-crypto
          </a>
          that compiles to both WebAssembly (for your browser) and a native module (for our server). The same auditable Rust code runs everywhere. We originally built it to power the zero-knowledge encryption architecture in <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://metamorphic.app"
          >Metamorphic</a>, our encrypted habit tracker, and now it powers MOSSLET too.
        </p>
        <p>
          To help with the migration from server-side to browser-side encryption, we also built <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/metamorphic_crypto"
          >metamorphic_crypto</a>, an open-source Elixir NIF wrapper around the same Rust crate. This gave our server the same cryptographic operations as the browser during the transition — ensuring wire-format compatibility every step of the way.
        </p>
        <p>
          When you log in, your browser derives a key from your password using Argon2id, unlocks your private key, and from that point on handles all encryption and decryption locally. The raw password never touches browser storage — only the derived key. And if you close your browser, an encrypted key cache means you won't have to re-enter your password on the next visit.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl bg-slate-100 dark:bg-slate-800">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <div class="flex items-center justify-center p-12 text-slate-400 dark:text-slate-500">
              <span class="text-sm italic">image placeholder</span>
            </div>
          </div>
        </div>

        <hr />
        <h2 id="post-quantum">
          <a href="#post-quantum">
            Protected against future threats
          </a>
        </h2>
        <p>
          Every key on MOSSLET is now wrapped with hybrid post-quantum encryption: ML-KEM-1024 combined with X25519. That's NIST FIPS 203, Category 5 — the highest security level in the standard.
        </p>
        <p>
          What does that mean in practice? If a sufficiently powerful quantum computer is ever built, it could break classical public-key encryption like RSA and standard elliptic curves. ML-KEM is designed to resist that. And because we use a hybrid scheme — combining the post-quantum algorithm with a classical one — both would need to be broken simultaneously. Even if ML-KEM turns out to have a weakness, your data is still protected by X25519. Even if X25519 falls to a quantum attack, ML-KEM still holds.
        </p>
        <p>
          Existing users don't need to do anything. When you next log in, your browser automatically generates a new post-quantum key pair and re-wraps your existing keys. The underlying symmetric keys and your data don't change — only the wrapping layer gets upgraded.
        </p>

        <hr />
        <h2 id="client-side-safety">
          <a href="#client-side-safety">
            Safety without surveillance
          </a>
        </h2>
        <p>
          One question we heard a lot during development: if the server can't see the content, how do you keep the platform safe?
        </p>
        <p>
          For non-public content, image safety checks now run directly in your browser. A lightweight AI model loads once and runs locally — your images are never sent to our servers or any external service. If it flags something, the upload is blocked before it ever leaves your device. If the model fails to load or has a problem, uploads proceed — we default to letting you post rather than blocking you silently.
        </p>
        <p>
          Public posts are different. Because they're visible to anyone — including unauthenticated visitors, search engines, and Bluesky federation — they use server-side encryption. This is the one intentional exception: the server needs to read public content to serve it. Public posts get server-side content and image moderation as well.
        </p>

        <hr />
        <h2 id="what-it-covers">
          <a href="#what-it-covers">
            Everything that's now zero-knowledge
          </a>
        </h2>
        <ul>
          <li>
            <strong>Posts</strong>
            — body, images, content warnings, URL previews, usernames, fav lists, repost lists, share notes, image alt texts, bookmark notes
          </li>
          <li>
            <strong>Replies</strong>
            — body, usernames, fav lists (all encrypted with the parent post key)
          </li>
          <li>
            <strong>Conversations</strong> — message content and images (zero-knowledge since day one)
          </li>
          <li>
            <strong>Journal</strong> — entry titles, bodies, moods, and AI-generated insights
          </li>
          <li>
            <strong>Groups</strong> — group names, descriptions, and member details
          </li>
          <li>
            <strong>Profiles</strong>
            — username, email, name, about, website, alternate email, status messages
          </li>
          <li>
            <strong>Images</strong>
            — avatars, banners, and all uploaded photos (encrypted in your browser before upload)
          </li>
          <li>
            <strong>Connections</strong> — labels, block reasons, and all shared profile fields
          </li>
        </ul>
        <p>
          The only exceptions are public posts (which need server access for rendering and federation) and operational data (like Stripe billing identifiers that the server needs to call payment APIs).
        </p>

        <hr />
        <h2 id="recovery">
          <a href="#recovery">
            What about account recovery?
          </a>
        </h2>
        <p>
          Zero-knowledge encryption means we truly cannot reset your password. If you lose it and haven't prepared, your data is gone. That's not a bug — it's the guarantee.
        </p>
        <p>
          That's why we built recovery keys. In your settings, you can generate a one-time recovery key — a code you write down and store somewhere safe. If you ever forget your password, the recovery key lets you decrypt your private key and set a new password. The server stores only an Argon2 hash of the recovery key; we can't use it ourselves. After you use it, it's consumed — you'll need to generate a new one.
        </p>
        <p>
          We strongly recommend setting this up. Think of it like a spare key to your house — you hope you never need it, but you'll be glad it exists.
        </p>

        <hr />
        <h2 id="verify-it">
          <a href="#verify-it">
            Don't take our word for it
          </a>
        </h2>
        <p>
          MOSSLET is <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/MOSSLET"
          >open source</a>. The Rust encryption library is <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/metamorphic-crypto"
          >open source</a>. The Elixir NIF wrapper is <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/metamorphic_crypto"
          >open source</a>. You can read the Rust code, compile the WASM yourself, and verify that the same code running in your browser is the same code running on our server.
        </p>
        <p>
          If you're a developer and want to build something similar, we published a
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/metamorphic_crypto/blob/main/docs/zero-knowledge-guide.md"
          >
            zero-knowledge encryption guide
          </a>
          that walks through the full architecture — from key derivation and client-side encryption to progressive post-quantum migration. It's the same approach we used in
          <a target="_blank" rel="noopener noreferrer" href="https://metamorphic.app">Metamorphic</a>
          and now in MOSSLET.
        </p>
        <p>
          We think that's the right standard. When someone tells you your data is private, you should be able to prove it — not with a privacy policy, but with math and code.
        </p>
        <p>
          This milestone represents months of careful, systematic work across dozens of components. And it matters because the rest of the industry is moving in the opposite direction. Meta is removing encryption from Instagram DMs. Smart doorbells are building surveillance networks for insurers and law enforcement. Dating apps are scanning camera rolls with AI.
        </p>
        <p>
          We believe people deserve better. A place where the architecture itself protects you, not a promise from a company that could change its mind next quarter.
        </p>
        <p>
          That's what MOSSLET is now. We're glad you're here.
        </p>
      </Components.blog_article>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(
       :page_title,
       "Blog | We Can't Read Your Data. Here's How."
     )
     |> assign_new(:meta_description, fn ->
       "Every post, message, journal entry, and image on MOSSLET is now encrypted and decrypted entirely in your browser. With post-quantum protection (ML-KEM-1024, NIST Cat-5), your data is safe today and against future quantum computers. Our servers genuinely cannot read your content."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/may_25_2026_zkpq.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Zero-knowledge post-quantum encryption architecture illustration")}
  end
end
