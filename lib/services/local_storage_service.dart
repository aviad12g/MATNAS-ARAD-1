import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_data.dart';

class LocalStorageService {
  static const String _storageKey = 'matnas_arad_app_state';

  Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null || stored.isEmpty) {
      return AppData.empty();
    }

    try {
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      return AppData.fromJson(decoded);
    } catch (_) {
      return AppData.empty();
    }
  }

  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(data.toJson());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
