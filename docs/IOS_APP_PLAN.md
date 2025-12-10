# MOSSLET iOS App Development Plan

> **Status:** Planning Phase  
> **Last Updated:** 2025-12-09 (December 9)  
> **Blocking Dependency:** LiveView Native 0.4.x with LiveView 1.1+ support (PR pending)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Decisions](#architecture-decisions)
3. [Phase 1: Apple Billing Provider](#phase-1-apple-billing-provider)
4. [Phase 2: LiveView Native Setup](#phase-2-liveview-native-setup)
5. [Phase 3: Native Templates Audit](#phase-3-native-templates-audit)
6. [Phase 4: iOS App Build & Submission](#phase-4-ios-app-build--submission)

---

## Overview

### Goals

- Ship a native iOS app using LiveView Native (SwiftUI)
- Support Apple In-App Purchases alongside existing Stripe payments
- Maintain encryption architecture (enacl stays server-side, works as-is)
- Achieve feature parity for core user flows

### Tech Stack

- **Server:** Phoenix 1.8 + LiveView 1.1+
- **iOS Client:** LiveView Native SwiftUI 0.4.x
- **Payments:** Stripe (web) + Apple StoreKit 2 / App Store Server API v2 (iOS)
- **Encryption:** enacl (NaCl/libsodium) - server-side only, no changes needed

---

## Architecture Decisions

### Encryption (enacl)

- [x] **Decision:** No changes needed
- **Rationale:** All encryption happens server-side. The iOS app sends/receives encrypted payloads over the LiveView websocket. User keys are derived from passwords and managed on the server.

### Payments

- [ ] **Decision:** Implement dual-provider support
- **Rationale:** Apple requires IAP for digital goods purchased in-app. We'll:
  1. Allow web checkout (Stripe) - no Apple fee
  2. Allow in-app checkout (Apple IAP) - 30%/15% fee but better conversion
  3. Use existing `Mosslet.Billing.Providers.Behaviour` abstraction

---

## Phase 1: Apple Billing Provider

### 1.1 Apple Developer Setup

- [ ] Ensure Apple Developer Program membership is active ($99/year)
- [ ] Create App ID in Apple Developer Portal
- [ ] Configure In-App Purchase products in App Store Connect
  - [ ] Create product: `com.mosslet.lifetime` (Non-Consumable, one-time purchase)
  - [ ] Set pricing tier matching Stripe pricing
  - [ ] Add localizations
- [ ] Generate App Store Server API credentials
  - [ ] Create API Key in App Store Connect (Users & Access → Keys → In-App Purchase)
  - [ ] Download private key (.p8 file)
  - [ ] Note: Key ID, Issuer ID, Bundle ID

### 1.2 Server-Side Implementation

#### 1.2.1 Create Apple Provider Behaviour

- [ ] Create `lib/mosslet/billing/providers/apple/provider_behaviour.ex`

```elixir
defmodule Mosslet.Billing.Providers.Apple.ProviderBehaviour do
  @moduledoc """
  Behaviour for Apple App Store Server API interactions.
  Allows mocking in tests.
  """

  @callback verify_transaction(binary()) :: {:ok, map()} | {:error, term()}
  @callback get_transaction_history(binary()) :: {:ok, list()} | {:error, term()}
  @callback get_subscription_status(binary()) :: {:ok, map()} | {:error, term()}
end
```

#### 1.2.2 Create Apple Provider Implementation

- [ ] Create `lib/mosslet/billing/providers/apple/provider.ex`

```elixir
defmodule Mosslet.Billing.Providers.Apple.Provider do
  @moduledoc """
  Interface to Apple App Store Server API v2.
  Uses Req for HTTP requests.
  """
  @behaviour Mosslet.Billing.Providers.Apple.ProviderBehaviour

  @base_url "https://api.storekit.itunes.apple.com"
  @sandbox_url "https://api.storekit-sandbox.itunes.apple.com"

  @impl true
  def verify_transaction(signed_transaction) do
    # Decode and verify JWS signed transaction
    # Returns decoded transaction info
  end

  @impl true
  def get_transaction_history(original_transaction_id) do
    url = "#{base_url()}/inApps/v1/history/#{original_transaction_id}"

    Req.get(url, headers: auth_headers())
    |> handle_response()
  end

  @impl true
  def get_subscription_status(original_transaction_id) do
    url = "#{base_url()}/inApps/v1/subscriptions/#{original_transaction_id}"

    Req.get(url, headers: auth_headers())
    |> handle_response()
  end

  defp base_url do
    if Application.get_env(:mosslet, :apple_sandbox, false) do
      @sandbox_url
    else
      @base_url
    end
  end

  defp auth_headers do
    [{"Authorization", "Bearer #{generate_jwt()}"}]
  end

  defp generate_jwt do
    # Generate ES256 JWT for App Store Server API
    # Claims: iss (Issuer ID), iat, exp, aud, bid (Bundle ID)
  end
end
```

#### 1.2.3 Create Main Apple Billing Provider

- [ ] Create `lib/mosslet/billing/providers/apple.ex`

```elixir
defmodule Mosslet.Billing.Providers.Apple do
  @moduledoc """
  Apple In-App Purchase billing provider.
  Implements the shared billing behaviour.
  """
  use Mosslet.Billing.Providers.Behaviour

  alias Mosslet.Billing.Providers.Apple.Provider
  alias Mosslet.Billing.Providers.Apple.Services.VerifyPurchase
  alias Mosslet.Billing.Providers.Apple.Services.ProcessNotification

  # For Apple IAP, checkout happens client-side in the iOS app
  # Server just verifies the transaction after purchase
  def checkout(_user, _plan, _source, _source_id, _session_key) do
    {:error, :use_client_side_checkout}
  end

  def checkout_url(_session), do: nil

  def verify_and_activate(user, signed_transaction, source, source_id, session_key) do
    VerifyPurchase.call(user, signed_transaction, source, source_id, session_key)
  end

  # ... implement remaining callbacks
end
```

#### 1.2.4 Create Transaction Verification Service

- [ ] Create `lib/mosslet/billing/providers/apple/services/verify_purchase.ex`

```elixir
defmodule Mosslet.Billing.Providers.Apple.Services.VerifyPurchase do
  @moduledoc """
  Verifies an Apple IAP transaction and creates/updates customer + payment records.
  """

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Providers.Apple.Provider

  def call(user, signed_transaction, source, source_id, session_key) do
    with {:ok, transaction} <- Provider.verify_transaction(signed_transaction),
         {:ok, customer} <- find_or_create_customer(user, transaction, source, source_id, session_key),
         {:ok, payment_intent} <- create_payment_intent(customer, transaction) do
      {:ok, %{customer: customer, payment_intent: payment_intent}}
    end
  end

  defp find_or_create_customer(user, transaction, source, source_id, session_key) do
    # Similar to Stripe's FindOrCreateCustomer but for Apple
    # Use original_transaction_id as the provider_customer_id equivalent
  end

  defp create_payment_intent(customer, transaction) do
    # Map Apple transaction to our PaymentIntent schema
    # transaction_id -> provider_payment_intent_id
    # price (in milliunits) -> amount
  end
end
```

#### 1.2.5 Create Webhook Handler for Server Notifications

- [ ] Create `lib/mosslet/billing/providers/apple/webhook_handler.ex`

```elixir
defmodule Mosslet.Billing.Providers.Apple.WebhookHandler do
  @moduledoc """
  Handles Apple App Store Server Notifications v2.

  Apple sends signed JWS notifications for:
  - CONSUMPTION_REQUEST
  - DID_CHANGE_RENEWAL_PREF
  - DID_CHANGE_RENEWAL_STATUS
  - DID_FAIL_TO_RENEW
  - DID_RENEW
  - EXPIRED
  - GRACE_PERIOD_EXPIRED
  - OFFER_REDEEMED
  - PRICE_INCREASE
  - REFUND
  - REFUND_DECLINED
  - RENEWAL_EXTENDED
  - REVOKE
  - SUBSCRIBED
  - TEST
  """

  require Logger

  def handle_notification(signed_payload) do
    with {:ok, notification} <- decode_and_verify(signed_payload),
         :ok <- process_notification(notification) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Apple notification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_notification(%{notification_type: "REFUND"} = notification) do
    # Handle refunds - mark payment as refunded
    %{original_transaction_id: notification.data.signedTransactionInfo.originalTransactionId}
    |> Mosslet.Billing.Providers.Apple.Workers.RefundWorker.new()
    |> Oban.insert()
  end

  defp process_notification(%{notification_type: "CONSUMPTION_REQUEST"} = _notification) do
    # Apple requesting consumption info (for refund decisions)
    :ok
  end

  defp process_notification(_notification), do: :ok
end
```

#### 1.2.6 Create Webhook Plug

- [ ] Create `lib/mosslet_web/plugs/apple_webhook_plug.ex`

```elixir
defmodule MossletWeb.Plugs.AppleWebhookPlug do
  @moduledoc """
  Plug to handle Apple App Store Server Notifications.
  """

  import Plug.Conn
  alias Mosslet.Billing.Providers.Apple.WebhookHandler

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, payload} <- Jason.decode(body),
         :ok <- WebhookHandler.handle_notification(payload["signedPayload"]) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{status: "ok"}))
      |> halt()
    else
      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: inspect(reason)}))
        |> halt()
    end
  end
end
```

#### 1.2.7 Add Webhook Route

- [ ] Update `lib/mosslet_web/router.ex`

```elixir
# In router.ex, add:
scope "/webhooks" do
  post "/apple", MossletWeb.Plugs.AppleWebhookPlug, []
end
```

#### 1.2.8 Create Configuration

- [ ] Add to `config/runtime.exs`

```elixir
config :mosslet, :apple,
  key_id: System.get_env("APPLE_KEY_ID"),
  issuer_id: System.get_env("APPLE_ISSUER_ID"),
  bundle_id: System.get_env("APPLE_BUNDLE_ID"),
  private_key: System.get_env("APPLE_PRIVATE_KEY"),
  sandbox: System.get_env("APPLE_SANDBOX", "false") == "true"
```

#### 1.2.9 Create JWT Generation Module

- [ ] Create `lib/mosslet/billing/providers/apple/jwt.ex`

```elixir
defmodule Mosslet.Billing.Providers.Apple.JWT do
  @moduledoc """
  Generates ES256 JWTs for Apple App Store Server API authentication.
  """

  def generate do
    config = Application.get_env(:mosslet, :apple)

    now = System.system_time(:second)

    claims = %{
      "iss" => config[:issuer_id],
      "iat" => now,
      "exp" => now + 3600,
      "aud" => "appstoreconnect-v1",
      "bid" => config[:bundle_id]
    }

    header = %{
      "alg" => "ES256",
      "kid" => config[:key_id],
      "typ" => "JWT"
    }

    # Use JOSE or similar for ES256 signing
    sign_jwt(header, claims, config[:private_key])
  end
end
```

#### 1.2.10 Create LiveView Event for iOS Purchase Verification

- [ ] Add to relevant LiveView (or create new one)

```elixir
# In a LiveView that handles purchase verification from iOS
def handle_event("verify_apple_purchase", %{"signed_transaction" => signed_transaction}, socket) do
  user = socket.assigns.current_user
  session_key = socket.assigns.key

  case Mosslet.Billing.Providers.Apple.verify_and_activate(
    user,
    signed_transaction,
    :user,
    user.id,
    session_key
  ) do
    {:ok, %{payment_intent: payment_intent}} ->
      {:noreply,
       socket
       |> put_flash(:info, "Purchase verified! Welcome to MOSSLET.")
       |> assign(:current_payment_intent, payment_intent)}

    {:error, reason} ->
      {:noreply,
       socket
       |> put_flash(:error, "Purchase verification failed: #{inspect(reason)}")}
  end
end
```

### 1.3 Testing

- [ ] Create `test/mosslet/billing/providers/apple_test.exs`
- [ ] Create mock provider for tests
- [ ] Test transaction verification flow
- [ ] Test webhook handling
- [ ] Test with Apple Sandbox environment

---

## Phase 2: LiveView Native Setup

> **BLOCKED:** Waiting for LVN 0.4.x to support LiveView 1.1+

### 2.1 Dependencies

- [ ] Add LiveView Native dependencies when compatible release is available

```elixir
# mix.exs - add when LV 1.1+ compatible
{:live_view_native, "~> 0.4.0"},
{:live_view_native_stylesheet, "~> 0.4.0"},
{:live_view_native_swiftui, "~> 0.4.0"},
{:live_view_native_live_form, "~> 0.4.0"}
```

### 2.2 Configuration

- [ ] Configure LiveView Native in `config/config.exs`
- [ ] Set up native stylesheet configuration
- [ ] Configure SwiftUI modifiers

### 2.3 iOS Project Setup

- [ ] Generate SwiftUI client scaffold
- [ ] Configure Xcode project settings
- [ ] Set up signing & capabilities
- [ ] Add StoreKit 2 capability for IAP

---

## Phase 3: Native Templates Audit

### LiveViews Requiring Native Templates

#### Priority 1: Authentication (Required for MVP)

| LiveView                 | File                           | Native Template Needed | Notes              |
| ------------------------ | ------------------------------ | ---------------------- | ------------------ |
| `UserLoginLive`          | `user_login_live.ex`           | [ ] Yes                | Essential          |
| `UserRegistrationLive`   | `user_registration_live.ex`    | [ ] Yes                | Essential          |
| `UserForgotPasswordLive` | `user_forgot_password_live.ex` | [ ] Yes                | Account recovery   |
| `UserResetPasswordLive`  | `user_reset_password_live.ex`  | [ ] Yes                | Account recovery   |
| `UserConfirmationLive`   | `user_confirmation_live.ex`    | [ ] Yes                | Email verification |

#### Priority 2: Core App Experience

| LiveView             | File                               | Native Template Needed | Notes              |
| -------------------- | ---------------------------------- | ---------------------- | ------------------ |
| `HomeLive`           | `home_live.ex`                     | [ ] Yes                | Landing/dashboard  |
| `UserHomeLive`       | `user_home_live/user_home_live.ex` | [ ] Yes                | Authenticated home |
| `UserDashLive`       | `user_dash_live.ex`                | [ ] Yes                | Main dashboard     |
| `TimelineLive.Index` | `timeline_live/index.ex`           | [ ] Yes                | Core feature       |

#### Priority 3: Billing (Required for IAP)

| LiveView               | File                                | Native Template Needed | Notes                        |
| ---------------------- | ----------------------------------- | ---------------------- | ---------------------------- |
| `SubscribeLive`        | `billing/subscribe_live.ex`         | [ ] Yes                | Must integrate with StoreKit |
| `BillingLive`          | `billing/billing_live.ex`           | [ ] Yes                | Payment history              |
| `SubscribeSuccessLive` | `billing/subscribe_success_live.ex` | [ ] Yes                | Post-purchase                |

#### Priority 4: User Settings

| LiveView                | File                                       | Native Template Needed | Notes              |
| ----------------------- | ------------------------------------------ | ---------------------- | ------------------ |
| `EditProfileLive`       | `user_settings/edit_profile_live.ex`       | [ ] Yes                | Profile editing    |
| `EditEmailLive`         | `user_settings/edit_email_live.ex`         | [ ] Yes                | Account management |
| `EditPasswordLive`      | `user_settings/edit_password_live.ex`      | [ ] Yes                | Security           |
| `EditNotificationsLive` | `user_settings/edit_notifications_live.ex` | [ ] Yes                | Preferences        |
| `EditTotpLive`          | `user_settings/edit_totp_live.ex`          | [ ] Optional           | 2FA setup          |
| `DeleteAccountLive`     | `user_settings/delete_account_live.ex`     | [ ] Yes                | Required by Apple  |

#### Priority 5: Social Features

| LiveView                    | File                             | Native Template Needed | Notes             |
| --------------------------- | -------------------------------- | ---------------------- | ----------------- |
| `UserConnectionLive.Index`  | `user_connection_live/index.ex`  | [ ] Yes                | Connections list  |
| `UserConnectionLive.Show`   | `user_connection_live/show.ex`   | [ ] Yes                | Connection detail |
| `UserConnectionLive.Invite` | `user_connection_live/invite.ex` | [ ] Yes                | Invitations       |
| `GroupLive.Index`           | `group_live/index.ex`            | [ ] Yes                | Groups list       |
| `GroupLive.Show`            | `group_live/show.ex`             | [ ] Yes                | Group detail      |
| `PostLive.Index`            | `post_live/index.ex`             | [ ] Yes                | Posts             |
| `PostLive.Show`             | `post_live/show.ex`              | [ ] Yes                | Post detail       |
| `PublicProfileLive`         | `public_profile_live.ex`         | [ ] Yes                | Public profiles   |

#### Defer / Web-Only

| LiveView               | File                         | Notes                      |
| ---------------------- | ---------------------------- | -------------------------- |
| `AdminDashLive`        | `admin_dash_live.ex`         | Admin-only, web sufficient |
| `AdminModerationLive`  | `admin_moderation_live.ex`   | Admin-only                 |
| `AdminBotDefenseLive`  | `admin_bot_defense_live.ex`  | Admin-only                 |
| `AdminKeyRotationLive` | `admin_key_rotation_live.ex` | Admin-only                 |
| Public marketing pages | `public_live/*`              | Web-only is fine           |

### Template Creation Checklist

For each LiveView getting a native template:

- [ ] Create `.swiftui.heex` template file
- [ ] Map HTML components to SwiftUI equivalents
- [ ] Handle form inputs with `live_view_native_live_form`
- [ ] Test on iOS simulator
- [ ] Test on physical device

---

## Phase 4: iOS App Build & Submission

### 4.1 App Store Connect Setup

- [ ] Create app record in App Store Connect
- [ ] Configure app information (name, description, keywords, screenshots)
- [ ] Set up in-app purchase products (from Phase 1)
- [ ] Configure App Store Server Notifications URL
- [ ] Set up TestFlight for beta testing

### 4.2 Xcode Configuration

- [ ] Configure app icons (all required sizes)
- [ ] Configure launch screen
- [ ] Set up push notification capability (if needed)
- [ ] Configure URL schemes for deep linking
- [ ] Set minimum iOS version (recommend iOS 16+)

### 4.3 StoreKit Integration

- [ ] Implement StoreKit 2 purchase flow in SwiftUI
- [ ] Handle transaction verification via LiveView events
- [ ] Implement restore purchases functionality
- [ ] Handle subscription/purchase status display

### 4.4 Testing

- [ ] Test complete purchase flow in sandbox
- [ ] Test restore purchases
- [ ] Test webhook notifications
- [ ] Test offline/poor connectivity handling
- [ ] Test account recovery flows
- [ ] Accessibility testing

### 4.5 App Store Submission

- [ ] Create screenshots for all device sizes
- [ ] Write App Store description
- [ ] Prepare privacy policy URL
- [ ] Prepare support URL
- [ ] Submit for review
- [ ] Address any review feedback

---

## Appendix

### Environment Variables Required

```bash
# Apple App Store Server API
APPLE_KEY_ID=your_key_id
APPLE_ISSUER_ID=your_issuer_id
APPLE_BUNDLE_ID=com.mosslet.app
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
APPLE_SANDBOX=true  # Set to false for production
```

### Useful Resources

- [App Store Server API Documentation](https://developer.apple.com/documentation/appstoreserverapi)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications)
- [LiveView Native Documentation](https://hexdocs.pm/live_view_native/)
- [LiveView Native SwiftUI](https://hexdocs.pm/live_view_native_swiftui/)

### File Structure for Apple Provider

```
lib/mosslet/billing/providers/
├── behaviour.ex                    # Existing
├── stripe.ex                       # Existing
├── stripe/                         # Existing
│   ├── provider.ex
│   ├── provider_behaviour.ex
│   ├── webhook_handler.ex
│   ├── adapters/
│   ├── services/
│   └── workers/
└── apple/                          # NEW
    ├── provider.ex
    ├── provider_behaviour.ex
    ├── jwt.ex
    ├── webhook_handler.ex
    ├── adapters/
    │   └── payment_intent_adapter.ex
    ├── services/
    │   ├── verify_purchase.ex
    │   └── process_notification.ex
    └── workers/
        └── refund_worker.ex
```
