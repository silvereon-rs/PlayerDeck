import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'file_helper.dart';

class CloudSync {
  static const String _storageKey = 'playerdeck_library_data_v1';

  static Future<void> saveLibraryToLocal(List<Game> games, List<PlatformAccount> accounts, List<FriendActivity> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'version': '1.0',
        'updatedAt': DateTime.now().toIso8601String(),
        'games': games.map((g) => g.toJson()).toList(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'activities': activities.map((act) => act.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving library to local storage: $e');
    }
  }

  static Future<Map<String, dynamic>?> loadLibraryFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading library from local storage: $e');
    }
    return null;
  }

  static void exportLibraryToFile(List<Game> games, List<PlatformAccount> accounts, List<FriendActivity> activities) {
    final data = {
      'app': 'PlayerDeck',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'games': games.map((g) => g.toJson()).toList(),
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'activities': activities.map((act) => act.toJson()).toList(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final filename = 'playerdeck_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    exportJsonFile(jsonStr, filename);
  }
}
