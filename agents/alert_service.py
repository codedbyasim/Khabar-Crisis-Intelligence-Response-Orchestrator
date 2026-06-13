"""
alert_service.py — Real Firebase Cloud Messaging V1 API Push Notifications
Uses Firebase Admin SDK with Service Account for FCM HTTP v1 API.
FR-21: Generates Urdu/English alerts + sends REAL push notifications.

Setup:
  1. Firebase Console → Project Settings → Service Accounts
  2. Click "Generate new private key"  
  3. Save JSON as agents/firebase_service_account.json
"""
import logging
import os
import json
from datetime import datetime, timezone
from typing import Dict, Any, List
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

# Path to Firebase Service Account JSON
SERVICE_ACCOUNT_PATH = os.path.join(
    os.path.dirname(__file__),
    'khabar-46771-firebase-adminsdk-fbsvc-e3117a9fbb.json'
)

# FCM Topic all Flutter app users are subscribed to
FCM_TOPIC = "khabar_public_alerts"

# Try importing firebase-admin
_fcm_app = None

def _init_firebase():
    """Initialize Firebase Admin SDK once using service account JSON."""
    global _fcm_app
    if _fcm_app:
        return True
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        logging.warning(
            "[FCM] firebase_service_account.json NOT FOUND at agents/. "
            "Go to Firebase Console → Project Settings → Service Accounts → "
            "'Generate new private key' and save as agents/firebase_service_account.json"
        )
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        _fcm_app = firebase_admin.initialize_app(cred)
        logging.info("[FCM] ✅ Firebase Admin SDK initialized with Service Account!")
        return True
    except ImportError:
        logging.warning("[FCM] firebase-admin not installed. Run: pip install firebase-admin")
        return False
    except Exception as e:
        logging.error(f"[FCM] Firebase init failed: {e}")
        return False


class AlertService:
    """
    Firebase Cloud Messaging V1 push notification service.
    Sends REAL push notifications to Flutter app if firebase_service_account.json is present.
    Otherwise logs a simulation with the same bilingual payload.
    """

    def __init__(self):
        self.sent_alerts: List[Dict[str, Any]] = []
        self.total_delivered = 0
        _init_firebase()

    URDU_TEMPLATES = {
        "flood":              "⚠️ سیلاب کا خطرہ: {location} میں سیلابی صورتحال۔ فوری محفوظ مقام پر جائیں۔",
        "urban flood":        "⚠️ شہری سیلاب: {location} میں پانی بھر گیا ہے۔ گاڑیاں نہ چلائیں۔",
        "fire":               "🔥 آگ کی اطلاع: {location} میں آگ لگی ہوئی ہے۔ فوری علاقہ خالی کریں۔ فائر بریگیڈ: 1122",
        "road accident":      "🚗 ٹریفک حادثہ: {location} پر حادثہ ہوا ہے۔ متبادل راستہ استعمال کریں۔",
        "building collapse":  "🏚️ عمارت منہدم: {location} میں عمارت گری ہے۔ علاقے سے دور ہو جائیں۔",
        "heatwave":           "🌡️ ہیٹ ویو وارننگ: {location} میں شدید گرمی۔ گھر سے باہر نہ نکلیں۔",
        "medical":            "🏥 طبی ہنگامی: {location}۔ ایمبولینس بھیجی گئی ہے۔",
        "road blockage":      "🚧 سڑک بند: {location} پر راستہ مسدود ہے۔ متبادل روٹ استعمال کریں۔",
        "infrastructure failure": "⚡ انفراسٹرکچر خرابی: {location} میں خدمات متاثر ہیں۔",
        "default":            "⚠️ ہنگامی اطلاع: {location} میں {severity} سطح کی صورتحال۔ احتیاط برتیں۔",
    }

    ENGLISH_TEMPLATES = {
        "flood":              "FLOOD ALERT: Flooding at {location}. Move to higher ground immediately.",
        "urban flood":        "URBAN FLOOD: Water logging at {location}. Do not drive through water.",
        "fire":               "FIRE ALERT: Fire at {location}. Evacuate immediately. Call 1122.",
        "road accident":      "ACCIDENT: Accident at {location}. Use alternate routes. Ambulance dispatched.",
        "building collapse":  "COLLAPSE ALERT: Building collapse at {location}. Stay clear. Rescue en route.",
        "heatwave":           "HEATWAVE WARNING: Extreme heat at {location}. Stay indoors. Stay hydrated.",
        "medical":            "MEDICAL EMERGENCY: {location}. Ambulance dispatched.",
        "road blockage":      "ROAD BLOCKED: {location} is blocked. Use alternate routes.",
        "default":            "EMERGENCY ALERT: {severity} incident at {location}. Stay safe.",
    }

    def _send_fcm_v1(self, title: str, body: str, data: dict) -> bool:
        """Send real FCM push notification via Firebase Admin SDK V1 API."""
        if not _fcm_app:
            return False
        try:
            from firebase_admin import messaging
            message = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in data.items()},
                topic=FCM_TOPIC,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="khabar_emergency",
                        sound="emergency_alert",
                    ),
                ),
                apns=messaging.APNSConfig(
                    headers={"apns-priority": "10"},
                ),
            )
            response = messaging.send(message)
            logging.info(f"[FCM] ✅ REAL Push Notification sent! Message ID: {response}")
            return True
        except Exception as e:
            logging.error(f"[FCM] Push notification failed: {e}")
            return False

    def send_alert(
        self,
        message: str,
        location: str,
        language: str = "ur",
        incident_id: str = None,
    ) -> Dict[str, Any]:
        """Send push notification — real FCM if configured, simulated otherwise."""
        recipient_count = self._estimate_recipients(location)

        title = "🚨 KHABAR — ہنگامی اطلاع" if language == "ur" else "🚨 KHABAR — Emergency Alert"
        fcm_sent = self._send_fcm_v1(
            title=title,
            body=message[:200],
            data={"incident_id": incident_id or "", "location": location, "language": language},
        )

        alert_record = {
            "alert_id": f"ALT-{int(datetime.now().timestamp())}",
            "message": message,
            "location": location,
            "language": language,
            "recipient_count": recipient_count,
            "status": "FCM_V1_DELIVERED" if fcm_sent else "SIMULATED_DELIVERY",
            "fcm_real": fcm_sent,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "channel": "FCM_V1_PUSH" if fcm_sent else "FCM_SIMULATED",
            "incident_id": incident_id,
        }
        self.sent_alerts.append(alert_record)
        self.total_delivered += 1

        status_label = "✅ REAL FCM V1" if fcm_sent else "📋 SIMULATED"
        logging.info(
            f"[FCM] {status_label} Alert #{self.total_delivered} → "
            f"~{recipient_count} users at {location}: '{message[:60]}...'"
        )
        return alert_record

    def broadcast_crisis_alert(
        self,
        incident_type: str,
        location: str,
        severity: str,
        incident_id: str = None,
    ) -> Dict[str, Any]:
        """Generate bilingual Urdu + English alert and send via real FCM V1."""
        incident_key = incident_type.lower().strip()
        urdu_msg = self.URDU_TEMPLATES.get(
            incident_key, self.URDU_TEMPLATES["default"]
        ).format(location=location, severity=severity)
        english_msg = self.ENGLISH_TEMPLATES.get(
            incident_key, self.ENGLISH_TEMPLATES["default"]
        ).format(location=location, severity=severity)

        urdu_record = self.send_alert(urdu_msg, location, language="ur", incident_id=incident_id)
        self.send_alert(english_msg, location, language="en", incident_id=incident_id)

        return {
            "urdu_message": urdu_msg,
            "english_message": english_msg,
            "recipient_count": urdu_record["recipient_count"],
            "alert_id": urdu_record["alert_id"],
            "status": urdu_record["status"],
            "fcm_real": urdu_record["fcm_real"],
        }

    def _estimate_recipients(self, location: str) -> int:
        loc = location.lower()
        # KHABAR is active only in Islamabad & Rawalpindi
        if any(c in loc for c in ["islamabad", "rawalpindi"]):
            return 1200
        if any(a in loc for a in [
            "g-10", "g-11", "g-9", "f-7", "f-8", "f-6",
            "e-11", "i-8", "i-10", "blue area", "saddar",
            "murree road", "faizabad", "shamsabad", "bahria", "dha"
        ]):
            return 480
        return 220

    def get_alert_history(self) -> List[Dict[str, Any]]:
        return self.sent_alerts


# Singleton instance
alert_service = AlertService()
