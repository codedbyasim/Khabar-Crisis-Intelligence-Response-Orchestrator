import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class UserProfileHelper {
  static Map<String, dynamic>? _cachedProfile;

  static Map<String, dynamic>? get cachedProfile => _cachedProfile;

  static Future<File> get _profileFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/profile.json');
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    _cachedProfile = profile;
    final file = await _profileFile;
    await file.writeAsString(jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    if (_cachedProfile != null) return _cachedProfile;
    try {
      final file = await _profileFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        _cachedProfile = jsonDecode(contents) as Map<String, dynamic>;
        return _cachedProfile;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
    return null;
  }

  static Future<void> clearProfile() async {
    _cachedProfile = null;
    try {
      final file = await _profileFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing user profile: $e');
    }
  }

  static bool get isLoggedIn => _cachedProfile != null;
}
