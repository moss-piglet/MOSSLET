defmodule MossletWeb.PublicLive.Blog.Blog10 do
  @moduledoc false
  use MossletWeb, :live_view
  alias MossletWeb.PublicLive.Blog.Components

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:blog}
      container_max_width={@max_width}
      key={@key}
    >
      <Components.blog_article
        date="December 8, 2025"
        title="How We Built Surveillance-Resistant Social Media"
        author_name="Mark"
        author_image={~p"/images/about/mark_photo.jpg"}
        author_link={~p"/"}
        author_link_text="MOSSLET"
        class=""
      >
        <p>
          I've been asked a few times now to write about how MOSSLET actually works under the hood. We're <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/MOSSLET"
          >open source</a>, so anyone can read the code, but code isn't documentation — and most people don't read Elixir. So here's the technical story of how we built a social network that can't spy on its own people.
        </p>

        <p>
          This isn't a whitepaper. It's an honest explanation of what we built, why we built it this way, and what the tradeoffs are. If you're a security researcher, developer, or just someone who wants to understand what "privacy-first" means in practice, this is for you.
        </p>

        <hr />
        <h2 id="the-threat-model">
          <a href="#the-threat-model">
            The threat model
          </a>
        </h2>
        <p>
          Before explaining our architecture, it helps to understand what we're protecting against. Our threat model assumes:
        </p>
        <ul>
          <li>
            <strong>Surveillance capitalism:</strong>
            The business model where your data is the oil and your future behavior the product. We have no ads, no tracking, no data sales.
          </li>
          <li>
            <strong>Database breaches:</strong>
            If an attacker gets our database, they should get encrypted noise, not your personal information.
          </li>
          <li>
            <strong>Server compromise:</strong>
            Even if someone gains access to our servers, they shouldn't be able to read your data without your password.
          </li>
          <li>
            <strong>Insider threats:</strong>
            We designed the system so that not even we — the people who run MOSSLET — can access your encrypted content.
          </li>
        </ul>

        <p>
          This is what "zero-knowledge architecture" means in practice: we literally don't have the knowledge required to decrypt your data.
        </p>

        <div class="my-8">
          <div class="relative overflow-hidden rounded-xl">
            <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
            </div>
            <img
              src={~p"/images/blog/dec_8_2025_hsrsm.jpg"}
              class="w-full"
              alt="Surveillance-resistant architecture illustration"
            />
          </div>
          <figcaption class="flex justify-end text-sm text-slate-500 dark:text-slate-400 mt-2">
            artwork by
            <.link
              target="_blank"
              rel="noopener noreferrer"
              href="https://unsplash.com/@riswanr_/illustrations"
              class="ml-1"
            >
              Riswan Ratta
            </.link>
          </figcaption>
        </div>

        <hr />
        <h2 id="the-encryption-architecture">
          <a href="#the-encryption-architecture">
            The encryption architecture
          </a>
        </h2>
        <p>
          MOSSLET uses a hybrid asymmetric + symmetric encryption model built on <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/jlouis/enacl"
          >enacl</a> (Erlang bindings to NaCl/libsodium). Here's how it works:
        </p>

        <h3>Password-derived keys</h3>
        <p>
          When you create an account, your password is used to derive an encryption key using Argon2id (the same algorithm that hashes your password, but with a different salt and purpose). This key is temporarily stored in your encrypted browser session for the duration of your login — it's never stored permanently on our servers. When your session expires, you simply re-enter your password to unlock it again. (We wrote more about
          <a href="/blog/articles/09">how our unlock sessions work</a>
          if you're curious about the UX.)
        </p>

        <h3>Public-key cryptography</h3>
        <p>
          Each person gets a cryptographic keypair (X25519 via NaCl's box_keypair). Your private key is encrypted with your password-derived key before storage. This means:
        </p>
        <ul>
          <li>
            Your encrypted private key exists on our servers, but we can't decrypt it without your password
          </li>
          <li>
            When you log in, your password unlocks your private key for the duration of your session
          </li>
          <li>
            If you change your password, we re-encrypt your private key with the new key — your data stays intact
          </li>
        </ul>

        <h3>Per-object encryption keys</h3>
        <p>
          Here's where it gets interesting. Each piece of content — every post, every shared profile, every circle — gets its own unique encryption key. When you create a post:
        </p>
        <ol>
          <li>A random key is generated just for that post</li>
          <li>Your content is encrypted with that key</li>
          <li>The post key is then encrypted to the public key of each person who should see it</li>
        </ol>
        <p>
          This is called "envelope encryption" and it has a critical security benefit: if one key is compromised, only that one post is exposed. The blast radius is limited.
        </p>

        <div class="my-8 overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900">
          <div class="bg-gradient-to-r from-emerald-600 to-teal-600 dark:from-emerald-700 dark:to-teal-700 px-4 sm:px-6 py-4">
            <h3 class="text-white font-semibold text-lg">
              How Post Encryption Works
            </h3>
            <p class="text-emerald-100 text-sm mt-1">
              Each post gets its own key, shared only with recipients
            </p>
          </div>
          <div class="p-4 sm:p-6">
            <div class="flex flex-col sm:flex-row sm:flex-wrap sm:justify-center items-center gap-3 text-sm">
              <div class="w-full sm:w-auto px-4 py-3 bg-amber-100 dark:bg-amber-900/30 rounded-lg text-center border border-amber-200 dark:border-amber-800">
                <div class="font-mono text-amber-800 dark:text-amber-300 text-xs">1. GENERATE</div>
                <div class="font-semibold text-amber-900 dark:text-amber-200 mt-1">
                  Random Post Key
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg text-center border border-blue-200 dark:border-blue-800">
                <div class="font-mono text-blue-800 dark:text-blue-300 text-xs">2. ENCRYPT</div>
                <div class="font-semibold text-blue-900 dark:text-blue-200 mt-1">
                  Content + Images
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-purple-100 dark:bg-purple-900/30 rounded-lg text-center border border-purple-200 dark:border-purple-800">
                <div class="font-mono text-purple-800 dark:text-purple-300 text-xs">3. WRAP</div>
                <div class="font-semibold text-purple-900 dark:text-purple-200 mt-1">
                  Key → Recipients
                </div>
              </div>
              <div class="hidden sm:block text-slate-400 dark:text-slate-500">→</div>
              <div class="sm:hidden text-slate-400 dark:text-slate-500">↓</div>
              <div class="w-full sm:w-auto px-4 py-3 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg text-center border border-emerald-200 dark:border-emerald-800">
                <div class="font-mono text-emerald-800 dark:text-emerald-300 text-xs">4. STORE</div>
                <div class="font-semibold text-emerald-900 dark:text-emerald-200 mt-1">
                  Encrypted Blob
                </div>
              </div>
            </div>
            <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700">
              <p class="text-xs text-slate-500 dark:text-slate-400">
                <strong class="text-slate-700 dark:text-slate-300">Step 3 detail:</strong>
                The post key is encrypted separately for each recipient using their public key. Only they can decrypt it with their private key.
              </p>
            </div>
          </div>
        </div>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            The Three-Layer Architecture
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-3">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-700 dark:text-emerald-400 font-bold">1.</span>
              <span>
                <strong>Personal data:</strong>
                Your personal info encrypted with your personal key (only you can decrypt)
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-700 dark:text-emerald-400 font-bold">2.</span>
              <span>
                <strong>Connection data:</strong>
                Profile info you share with friends, encrypted with a connection key they can access
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-700 dark:text-emerald-400 font-bold">3.</span>
              <span>
                <strong>Content data:</strong>
                Posts, images, messages — each with unique keys distributed to recipients
              </span>
            </div>
          </div>
        </div>

        <h3>Double encryption at rest</h3>
        <p>
          All of the above encryption (using enacl) happens before data reaches our database. But we add a second layer: every sensitive field in our database is also wrapped with symmetric encryption using <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/danielberkompas/cloak"
          >Cloak</a>. Non-sensitive functional data (like booleans for feature flags) isn't double-encrypted—there's no point encrypting a "true/false" value that reveals nothing about you.
        </p>
        <p>
          This adds another layer of protection against database-level attacks. Our use of AES-256-GCM for the symmetric encryption layer provides strong resistance against potential future quantum computing threats.
        </p>
        <p>
          Any data we need to search against (like usernames or email addresses) is stored as a keyed hash, not plaintext. We can look you up, but we can't read what we're looking up.
        </p>

        <h3>Encrypted images</h3>
        <p>
          Your photos don't get special treatment — they get the same encryption as everything else. When you upload an image, the entire binary data is encrypted with your post's unique key before it ever touches our object storage. The encrypted blob is stored in private buckets accessible only via time-limited signed URLs.
        </p>
        <p>
          This means even if someone gained access to our storage infrastructure, they'd find encrypted noise. The actual image data can only be reconstructed by someone who has the post key — which means you and the people you've shared with.
        </p>

        <hr />
        <h2 id="how-sharing-works">
          <a href="#how-sharing-works">
            How sharing works
          </a>
        </h2>
        <p>
          When you share a post with someone, here's what happens:
        </p>
        <ol>
          <li>We take the post's unique encryption key</li>
          <li>We encrypt that key using the recipient's public key (so only they can decrypt it)</li>
          <li>We store this encrypted key in a "user_post" record linking them to your post</li>
        </ol>
        <p>
          When your friend opens the post:
        </p>
        <ol>
          <li>Their session key (derived from their password) decrypts the post key</li>
          <li>The post content is then decrypted using that key</li>
          <li>
            They see your content — the decrypted data exists only in memory for that request, never stored or logged
          </li>
        </ol>
        <p>
          Without your friend's password, that decryption can't happen — not even by us. The encrypted bytes sit in our database, unreadable, until someone with the right key requests them.
        </p>
        <p>
          This same pattern applies to everything: circles, connections, shared profile data. Each context has a key, and access is granted by encrypting that key to the recipient's public key.
        </p>

        <hr />
        <h2 id="the-password-recovery-tradeoff">
          <a href="#the-password-recovery-tradeoff">
            The password recovery tradeoff
          </a>
        </h2>
        <p>
          Here's an honest limitation: if you forget your password, we can't help you recover your data. This is by design — if we could reset your password and restore your data, that would mean we have access to your encryption keys, which defeats the entire purpose.
        </p>
        <p>
          However, we give people a choice. Once you're signed in, you can enable a "forgot password recovery" mode. This stores a copy of your session key encrypted symmetrically (with a key we control), allowing us to help you recover access if you get locked out.
        </p>
        <p>
          We're transparent about the tradeoff: enabling this feature means we could theoretically access your data. Most people don't enable it. Those who do understand they're trading some security for convenience. If you turn it off, we immediately delete the stored recovery key.
        </p>

        <p>
          We think this is a handy feature for most people, or anyone who is worried about losing/forgetting their password, and you can verify our code to be sure it's protected and used only for your account recovery. And should you change your mind, or your threat level increase, then you can simply switch your account back and erase this encrypted copy immediately and permanently.
        </p>

        <hr />
        <h2 id="defense-in-depth">
          <a href="#defense-in-depth">
            Defense in depth
          </a>
        </h2>
        <p>
          Encryption is the foundation, but we layer other protections on top:
        </p>

        <div class="my-8 p-6 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700">
          <h3 class="text-emerald-600 dark:text-emerald-400 font-bold mb-3">
            Security Layers
          </h3>
          <div class="text-sm text-slate-700 dark:text-slate-300 space-y-2">
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>A+ Content Security Policy:</strong>
                We scored A+ on Mozilla Observatory — our CSP prevents XSS attacks and data exfiltration
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>Encrypted sessions & cookies:</strong>
                All session data is encrypted, not just signed
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>Argon2id password hashing:</strong>
                The gold standard for password storage — slow, memory-hard, resistant to GPU attacks
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>WireGuard mesh network:</strong>
                We run on distributed infrastructure with encrypted internal traffic
              </span>
            </div>
            <div class="flex items-start space-x-2">
              <span class="text-emerald-500 font-bold">✓</span>
              <span>
                <strong>Rate limiting & honeypots:</strong>
                Automated protection against attacks and credential stuffing
              </span>
            </div>
          </div>
        </div>

        <hr />
        <h2 id="content-safety-without-surveillance">
          <a href="#content-safety-without-surveillance">
            Content safety without surveillance
          </a>
        </h2>
        <p>
          We do scan uploaded images for safety — but in a way that respects your privacy. Before an image is encrypted and stored, we run it through a local, pre-trained ML model to detect not-safe-for-work content. This happens entirely on our servers with no external API calls, no cloud services, and critically: we don't store, log, or train on any of your data. The image either passes and gets encrypted, or it doesn't. Either way, we learn nothing about you.
        </p>
        <p>
          This is how content moderation should work: protecting the community while protecting your privacy. No surveillance required.
        </p>

        <hr />
        <h2 id="the-tech-stack">
          <a href="#the-tech-stack">
            The tech stack
          </a>
        </h2>
        <p>
          We built MOSSLET with
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://elixir-lang.org/"
          >
            Elixir
          </a>
          and <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://www.phoenixframework.org/"
          >Phoenix LiveView</a>. This might seem like an unusual choice for a social network, but it's deliberate:
        </p>
        <ul>
          <li>
            <strong>Fault tolerance:</strong>
            The BEAM (Erlang VM) was built for telecom systems that can't go down. If one process crashes, others keep running.
          </li>
          <li>
            <strong>Real-time without complexity:</strong>
            LiveView gives us real-time updates over WebSockets without the complexity of a separate JavaScript frontend. Less code means fewer bugs and a smaller attack surface.
          </li>
          <li>
            <strong>No JavaScript framework:</strong>
            Our encryption happens server-side in Elixir. We don't trust arbitrary JavaScript from dozens of npm packages with your encryption keys.
          </li>
        </ul>
        <p>
          We deploy on
          <a
            target="_blank"
            rel="noopener noreferrer"
            href="https://fly.io/"
          >
            Fly.io
          </a>
          — edge computing on bare metal, WireGuard-encrypted internal networking, no hyperscaler baggage. Our data stays in infrastructure we understand.
        </p>

        <hr />
        <h2 id="honest-limitations">
          <a href="#honest-limitations">
            Honest limitations
          </a>
        </h2>
        <p>
          No system is perfect. Here's what we're honest about:
        </p>
        <ul>
          <li>
            <strong>Server-side trust model:</strong>
            Your encryption and decryption happens on our servers, not in your browser. We chose this approach because it allows us to use battle-tested cryptographic libraries (via <a
              target="_blank"
              rel="noopener noreferrer"
              href="https://github.com/jlouis/enacl"
            >enacl</a>) and maintain the simplicity and security of Phoenix LiveView, rather than trusting arbitrary JavaScript dependencies in the browser. This means you're trusting us to run the code we say we're running, and to not log or exfiltrate decrypted content during the brief moment it exists in memory. Our open source code lets you verify what we claim to run, but you can't verify what's actually running on our servers in real-time. This is a fundamental limitation of any digital service.
          </li>
          <li>
            <strong>Metadata visibility:</strong>
            We can see when requests are made to our servers and that database records exist. We can't see who's online (presence is encrypted and user-controlled), but activity patterns like "something happened at this timestamp" are visible to us. We don't log or analyze these patterns — it's simply the operational nature of digital systems.
          </li>
          <li>
            <strong>No MITM protection for key exchange:</strong>
            When you connect with someone, we facilitate the public key exchange. A sophisticated attacker with server access could theoretically substitute keys. This is hard to solve on the web without an independent verification channel. We're actively exploring solutions that don't come with their own privacy tradeoffs.
          </li>
        </ul>
        <p>
          We're not claiming to be <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://signal.org"
          >Signal</a> or to have solved all problems in secure communication. We're claiming to be dramatically better than surveillance-based social networks, and we're being honest about where the gaps are.
        </p>

        <hr />
        <h2 id="your-data-your-control">
          <a href="#your-data-your-control">
            Your data, your control
          </a>
        </h2>
        <p>
          Privacy isn't just about encryption — it's about control. When you delete something on MOSSLET, it's gone. Not "hidden from your view while we keep it for analytics." Not "scheduled for deletion in 30 days." Gone. Deletions propagate in real-time across our distributed infrastructure.
        </p>
        <p>
          When you delete a connection on MOSSLET, they lose access to everything you've shared with them—not just from your view, but from theirs too. The encrypted keys that gave them access are deleted along with any shared content.
        </p>
        <p>
          This is the right to be forgotten, implemented as a technical reality rather than a policy checkbox.
        </p>

        <hr />
        <h2 id="why-this-matters">
          <a href="#why-this-matters">
            Why this matters
          </a>
        </h2>
        <p>
          Most "privacy-focused" platforms use encryption as marketing. They might encrypt data "at rest" with keys they control, or encrypt your connection to their servers while keeping everything readable inside. That's not privacy — that's security theater.
        </p>
        <p>
          We built MOSSLET so that even if we wanted to read your data (we don't), even if we were compelled by a government (we'd fight it), even if an attacker compromised our servers — we, and they, still couldn't access your encrypted content without your password.
        </p>
        <p>
          This is what surveillance-resistant actually means. Not a policy promise. Not a terms of service. It's a cryptographic reality. A privacy-first architecture, and business model, by design.
        </p>

        <hr />
        <h2 id="verify-it-yourself">
          <a href="#verify-it-yourself">
            Verify it yourself
          </a>
        </h2>
        <p>
          MOSSLET is <a
            phx-no-format
            target="_blank"
            rel="noopener noreferrer"
            href="https://github.com/moss-piglet/MOSSLET"
          >open source</a>. Our encryption implementation is in the codebase for anyone to audit. If you're a security researcher or cryptographer, we'd genuinely appreciate your review. Find something? Let us know.
        </p>
        <p>
          For everyone else: you don't need to read the code to benefit from it. The architecture protects you whether you understand it or not. And it's there if you ever want to verify our claims.
        </p>
        <p>
          Ready to try social media that respects your privacy by design?
          <a href="/auth/register">
            Join MOSSLET
          </a>
          and experience what it feels like when the technology is actually on your side.
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
       "Blog | How We Built Surveillance-Resistant Social Media"
     )
     |> assign_new(:meta_description, fn ->
       "A technical deep-dive into MOSSLET's encryption architecture: password-derived keys, per-object encryption, public-key cryptography with enacl, and defense-in-depth security. How we built a social network that can't spy on its own people."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/blog/dec_8_2025_hsrsm.jpg")
     |> assign(:og_image_type, "image/jpeg")
     |> assign(:og_image_alt, "Peaceful hiker in the sunset-colored woods illustration")}
  end
end
