# Push Notification Setup

This document describes how to configure push notifications for the Mosslet native apps.

## iOS (APNs)

### Prerequisites

1. Apple Developer account with push notification entitlement
2. App ID configured with Push Notifications capability

### Setup Steps

1. **Create APNs Key in Apple Developer Console:**

   - Go to Certificates, Identifiers & Profiles → Keys
   - Create a new key with "Apple Push Notifications service (APNs)" enabled
   - Download the `.p8` file and note the Key ID

2. **Configure Server Environment:**

   ```bash
   # Add to your environment variables (Fly.io secrets, etc.)
   APPLE_ISSUER_ID=your-team-id
   APPLE_KEY_ID=your-key-id
   APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
   ```

3. **Update Entitlements (already done):**

   - `Mosslet.entitlements` already includes `aps-environment` set to `development`
   - Change to `production` for App Store builds

4. **Verify Info.plist (already done):**
   - `UIBackgroundModes` includes `remote-notification`

### How It Works (iOS)

The implementation is complete in:

- `AppDelegate.swift` - Handles `didRegisterForRemoteNotificationsWithDeviceToken` and `UNUserNotificationCenterDelegate`
- `JsonBridge.swift` - Bridges push events to WebView via `mosslet-push-*` custom events

Flow:

1. JS calls `MobileNative.push.requestPermission()`
2. iOS requests authorization via `UNUserNotificationCenter`
3. If granted, iOS calls `registerForRemoteNotifications()`
4. APNs returns device token via `didRegisterForRemoteNotificationsWithDeviceToken`
5. Token is sent to WebView via `mosslet-push-token` event
6. LiveView hook sends token to server via `push_token_received` event
7. Server stores token in `device_tokens` table

---

## Android (FCM)

### Prerequisites

1. Firebase project with Cloud Messaging enabled
2. `google-services.json` file from Firebase Console

### Setup Steps

1. **Create Firebase Project:**

   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use existing
   - Add Android app with package name `com.mosslet.app`

2. **Download google-services.json:**

   - In Firebase Console → Project Settings → Your apps
   - Download `google-services.json`
   - Place it in `native/android/app/google-services.json`
   - **DO NOT commit this file to git** (it's in .gitignore)

3. **Configure Server Environment:**

   ```bash
   # Option 1: Service account JSON (recommended)
   GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

   # Option 2: Individual credentials
   GOOGLE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
   GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
   ```

4. **Get Server Key for FCM HTTP v1:**
   - Firebase Console → Project Settings → Service Accounts
   - Generate new private key
   - Use for server-side push sending

### How It Works (Android)

The implementation is complete in:

- `PushNotificationService.kt` - Extends `FirebaseMessagingService`, handles `onNewToken` and `onMessageReceived`
- `JsonBridge.kt` - Handles permission requests and bridges events to WebView
- `MainActivity.kt` - Handles permission results and notification tap intents
- `MossletApplication.kt` - Creates notification channel on app start

Flow:

1. JS calls `MobileNative.push.requestPermission()`
2. Android checks/requests `POST_NOTIFICATIONS` permission (Android 13+)
3. If granted, FCM token is requested via `FirebaseMessaging.getInstance().token`
4. Token is sent to WebView via `mosslet-push-token` event
5. LiveView hook sends token to server via `push_token_received` event
6. Server stores token in `device_tokens` table

### Notification Channels

Android 8+ requires notification channels. The app creates a default channel:

- Channel ID: `mosslet_notifications`
- Name: "Mosslet Notifications"
- Importance: HIGH (shows heads-up notification)

---

## Server-Side API

### Register Device Token

The server API endpoint for registering tokens:

```
POST /api/devices/token
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "token": "device-push-token",
  "platform": "ios" | "android"
}
```

### Send Push Notification (Internal)

```elixir
# Send to specific user
Mosslet.Notifications.Push.send_to_user(user_id, %{
  title: "New Message",
  body: "You have a new message from Jane",
  data: %{
    type: "message",
    path: "/app/messages/123"
  }
})

# Send to specific device
Mosslet.Notifications.Push.send_to_device(device_token, platform, payload)
```

---

## Testing Push Notifications

### iOS Simulator

- Push notifications don't work on iOS Simulator
- Use a physical device for testing
- Or use Xcode's push notification simulator (Xcode 11.4+)

### Android Emulator

- FCM works on emulators with Google Play Services
- Use Firebase Console → Cloud Messaging → Send test message
- Or use the FCM REST API directly

### Debug Logging

Enable debug logging to trace push flow:

```elixir
# config/dev.exs
config :logger, level: :debug
```

Check browser console for `mosslet-push-*` events.

---

## Troubleshooting

### iOS: Token not received

1. Check entitlements include `aps-environment`
2. Verify push capability is enabled in Xcode
3. Check device is not in Airplane mode
4. Try deleting and reinstalling the app

### Android: Token not received

1. Verify `google-services.json` is in place
2. Check Firebase project is correctly configured
3. Ensure device has Google Play Services
4. Check logcat for Firebase errors

### Notifications not showing

1. Check notification permissions in device settings
2. Verify notification channel exists (Android)
3. Check server logs for send errors
4. Verify token is correctly stored in database
