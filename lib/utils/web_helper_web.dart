// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;


bool isGoogleMapsLoaded() {
  try {
    return js.context.hasProperty('google') &&
        (js.context['google'] as js.JsObject).hasProperty('maps');
  } catch (_) {
    return false;
  }
}

bool isBrowserOnline() {
  try {
    return js.context['navigator']['onLine'] == true;
  } catch (_) {
    return true;
  }
}

