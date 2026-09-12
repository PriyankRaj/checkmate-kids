import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin JSON-over-SharedPreferences wrapper used for progress/settings
/// persistence across puzzles, tutorials, challenges, and profile.
class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsStore> create() async {
    return PrefsStore(await SharedPreferences.getInstance());
  }

  Map<String, dynamic> readJson(String key, {Map<String, dynamic>? fallback}) {
    final raw = _prefs.getString(key);
    if (raw == null) return fallback ?? <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return fallback ?? <String, dynamic>{};
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, jsonEncode(value));
  }

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
}
