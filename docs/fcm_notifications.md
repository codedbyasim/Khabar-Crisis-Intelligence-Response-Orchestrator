# 🔔 Firebase Cloud Messaging (FCM) Integration

KHABAR integrates Firebase Cloud Messaging (FCM) to support real-time crisis warning signals, forcing localized warning popups directly onto the user's mobile screen.

---

## 📲 1. App Navigation State Routing
During active emergency events, notifications must trigger dynamic app reactions immediately.
*   **Global Navigator Key:** 
    Inside `lib/main.dart`, we define a `GlobalKey<NavigatorState>`:
    ```dart
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    ```
*   **Purpose:** Allows background service handlers and FCM listeners to perform context-free screen routing or display modal dialog overlays even when the user is deep inside another screen.

---

## ⚡ 2. Foreground vs. Background Handlers
The Flutter application listens for real-time messages on the `khabar_alerts` notification channel.

### 🟢 Foreground Handling:
1. When a user has the app open and the backend Execution Agent invokes `BroadcastAlert`, an FCM payload is sent.
2. The application listens using `FirebaseMessaging.onMessage.listen(...)`.
3. If the message payload contains `"priority": "CRITICAL"`, it triggers a foreground modal dialog:
   - Displays a red glassmorphic backdrop.
   - Shows the warning in Roman Urdu and English.
   - Provides a direct action button: **"Go to Incident Map"** which dynamically routes the user to `MapScreen` using the global `navigatorKey`.

### 🔴 Background Handling:
1. If the app is closed, the system listens using a top-level function annotated with `@pragma('vm:entry-point')`:
   ```dart
   Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
       // Processes and caches incoming signals locally
   }
   ```
2. Triggers a system tray notification with high-priority ringtone channels to ensure the citizen is warned immediately.
