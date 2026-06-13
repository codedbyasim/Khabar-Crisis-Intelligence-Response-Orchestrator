# 🔔 Firebase Cloud Messaging (FCM) — Push Notifications

KHABAR sends **real-time bilingual push notifications** to all citizen app users using Firebase Cloud Messaging v1 HTTP API via the Firebase Admin SDK.

---

## How It Works

```
Execution Agent triggers broadcast_alert tool
            ↓
AlertService.broadcast_crisis_alert()
            ↓
Generates Urdu + English message from templates
            ↓
FCM v1 API via firebase-admin SDK
            ↓
All users subscribed to topic: khabar_public_alerts
            ↓
Flutter app receives notification (foreground + background)
```

---

## Setup

### Step 1 — Get Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project `khabar-46771`
3. **Project Settings → Service Accounts → Generate new private key**
4. Download JSON and place at:
   ```
   h:\khabar\agents\khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json
   ```

### Step 2 — Subscribe Flutter Users to Topic
Flutter app subscribes on startup (in `main.dart`):
```dart
await FirebaseMessaging.instance.subscribeToTopic('khabar_public_alerts');
```

### Step 3 — Verify FCM Works
With backend running, submit a test incident and check logs for:
```
[FCM] ✅ REAL Push Notification sent! Message ID: projects/khabar-46771/messages/...
```

---

## Alert Templates

`AlertService` has built-in bilingual templates for 9 crisis types:

| Crisis Type | Urdu Template | English Template |
|---|---|---|
| `flood` | ⚠️ سیلاب کا خطرہ: {location}... | FLOOD ALERT: Flooding at {location}... |
| `urban flood` | ⚠️ شہری سیلاب: {location}... | URBAN FLOOD: Water logging at {location}... |
| `fire` | 🔥 آگ کی اطلاع: {location}... | FIRE ALERT: Fire at {location}... |
| `road accident` | 🚗 ٹریفک حادثہ: {location}... | ACCIDENT: Accident at {location}... |
| `building collapse` | 🏚️ عمارت منہدم: {location}... | COLLAPSE ALERT: Building collapse... |
| `heatwave` | 🌡️ ہیٹ ویو وارننگ: {location}... | HEATWAVE WARNING: Extreme heat... |
| `medical` | 🏥 طبی ہنگامی: {location}... | MEDICAL EMERGENCY: {location}... |
| `road blockage` | 🚧 سڑک بند: {location}... | ROAD BLOCKED: {location}... |
| `default` | ⚠️ ہنگامی اطلاع: {location}... | EMERGENCY ALERT: {severity} incident... |

---

## Alert Payload Structure

```python
message = messaging.Message(
    notification = Notification(title="🚨 KHABAR — ہنگامی اطلاع", body=urdu_message),
    data = {"incident_id": "SIG-...", "location": "Rawalpindi", "language": "ur"},
    topic = "khabar_public_alerts",
    android = AndroidConfig(
        priority="high",
        notification=AndroidNotification(
            channel_id="khabar_emergency",
            sound="emergency_alert"
        )
    ),
    apns = APNSConfig(headers={"apns-priority": "10"})
)
```

---

## Fallback (No Service Account File)

If `firebase_service_account.json` is missing:
- System logs `[FCM] SIMULATED Alert` instead of failing
- Alert record is stored with `status: "SIMULATED_DELIVERY"`
- Rest of the pipeline continues normally — **no crash**

---

## Recipient Estimation

`AlertService._estimate_recipients()` estimates the audience size by location:

| Location Type | Estimated Recipients |
|---|---|
| Islamabad or Rawalpindi (city-wide) | ~1,200 |
| Named sectors (G-10, F-7, Saddar, Murree Road, Faizabad, Bahria, DHA) | ~480 |
| Other areas (not matched above) | ~220 |
