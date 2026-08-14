import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;

  OfflineService._internal() {
    _initConnectivityListener();
  }

  static const String _orgsCacheKey = 'cached_organizations_list';
  static const String _profileCacheKey = 'cached_user_profile';
  static const String _emergencyContactsKey = 'cached_emergency_contacts';
  static const String _offlineSosQueueKey = 'offline_sos_action_queue';

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineStreamController =
      StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _onlineStreamController.stream;

  void _initConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
      if (_isOnline != hasConnection) {
        _isOnline = hasConnection;
        _onlineStreamController.add(_isOnline);
        if (_isOnline) {
          syncPendingSOSQueue();
        }
      }
    });
  }

  Future<bool> checkInternet() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    return _isOnline;
  }

  // ── Organizations Caching ─────────────────────────────────────────────

  Future<void> cacheOrganizations(List<Map<String, dynamic>> orgs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_orgsCacheKey, json.encode(orgs));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedOrganizations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_orgsCacheKey);
      if (dataStr != null) {
        final decoded = json.decode(dataStr) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Profile & Emergency Contacts Caching ──────────────────────────────

  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileCacheKey, json.encode(profile));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_profileCacheKey);
      if (dataStr != null) {
        return Map<String, dynamic>.from(json.decode(dataStr));
      }
    } catch (_) {}
    return null;
  }

  Future<void> cacheEmergencyContacts(List<dynamic> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emergencyContactsKey, json.encode(contacts));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCachedEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_emergencyContactsKey);
      if (dataStr != null) {
        final decoded = json.decode(dataStr) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Offline SOS Queue & Auto-Sync ─────────────────────────────────────

  Future<void> queueOfflineSOS({
    required String type,
    required double lat,
    required double lng,
    String? note,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getPendingSOSQueue();
      final item = {
        'id': 'offline_sos_${DateTime.now().millisecondsSinceEpoch}',
        'type': type,
        'location_lat': lat,
        'location_lng': lng,
        'note': note ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
      list.add(item);
      await prefs.setString(_offlineSosQueueKey, json.encode(list));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getPendingSOSQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_offlineSosQueueKey);
      if (dataStr != null) {
        final decoded = json.decode(dataStr) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> removePendingSOS(String localId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getPendingSOSQueue();
      list.removeWhere((item) => item['id'] == localId);
      await prefs.setString(_offlineSosQueueKey, json.encode(list));
    } catch (_) {}
  }

  Future<void> clearPendingSOSQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineSosQueueKey);
    } catch (_) {}
  }

  Future<int> syncPendingSOSQueue() async {
    final queue = await getPendingSOSQueue();
    if (queue.isEmpty) return 0;

    int syncedCount = 0;
    final api = ApiService();

    for (final item in List<Map<String, dynamic>>.from(queue)) {
      try {
        final res = await api.createSOS(
          item['type'],
          (item['location_lat'] as num).toDouble(),
          (item['location_lng'] as num).toDouble(),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          await removePendingSOS(item['id']);
          syncedCount++;
        }
      } catch (_) {
        // Stop on network failure to avoid spamming
        break;
      }
    }
    return syncedCount;
  }
}
