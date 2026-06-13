import 'package:flutter/foundation.dart';
import 'web_helper_stub.dart'
    if (dart.library.js) 'web_helper_web.dart' as loader;

bool checkGoogleMapsLoaded() {
  if (!kIsWeb) return true; // Mobile standard SDK is loaded natively
  return loader.isGoogleMapsLoaded();
}

bool checkBrowserOnline() {
  if (!kIsWeb) return true;
  return loader.isBrowserOnline();
}

