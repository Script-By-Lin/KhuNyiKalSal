import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _familyGroupKey = 'family_group_cache';
  static const String _familyAlertsKey = 'family_alerts_cache';

  static Future<void> saveFamilyGroup(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyGroupKey, json.encode(data));
  }

  static Future<Map<String, dynamic>?> getFamilyGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_familyGroupKey);
    if (dataStr != null) {
      try {
        return json.decode(dataStr) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> saveFamilyAlerts(List<dynamic> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyAlertsKey, json.encode(alerts));
  }

  static Future<List<dynamic>?> getFamilyAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_familyAlertsKey);
    if (dataStr != null) {
      try {
        return json.decode(dataStr) as List<dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_familyGroupKey);
    await prefs.remove(_familyAlertsKey);
  }
}
