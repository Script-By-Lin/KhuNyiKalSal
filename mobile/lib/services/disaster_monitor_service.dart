import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';
import 'notification_service.dart';
import 'weather_service.dart';

class DisasterMonitorService {
  static final DisasterMonitorService _instance = DisasterMonitorService._internal();
  factory DisasterMonitorService() => _instance;
  DisasterMonitorService._internal();

  Timer? _pollingTimer;
  final WeatherService _weatherService = WeatherService();
  final Set<String> _alertedIds = {};
  bool _isRunning = false;

  static const String _alertedIdsKey = 'notified_disaster_alert_ids';

  Future<void> startMonitoring() async {
    if (_isRunning) return;
    _isRunning = true;
    await _loadAlertedIds();

    // Initial check immediately
    _checkDisasterProximity();

    // Periodic check every 45 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _checkDisasterProximity();
    });
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
  }

  Future<void> _loadAlertedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_alertedIdsKey) ?? [];
      _alertedIds.addAll(list);
    } catch (_) {}
  }

  Future<void> _saveAlertedId(String id) async {
    try {
      _alertedIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_alertedIdsKey, _alertedIds.toList());
    } catch (_) {}
  }

  Future<void> _checkDisasterProximity() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      final alerts = await _weatherService.getDisasterAlerts(lat: pos.latitude, lon: pos.longitude);

      for (var alert in alerts) {
        // If the disaster alert is in close proximity to user in Myanmar (<= 150 km or critical alert)
        if (alert.isEmergencyProximity && !_alertedIds.contains(alert.id)) {
          await _saveAlertedId(alert.id);

          final distanceText = alert.distanceKm != null
              ? '${alert.distanceKm!.toStringAsFixed(0)} km away'
              : 'in your region';

          NotificationService().showDisasterProximityAlarm(
            id: alert.id.hashCode,
            title: '🚨 ${alert.titleMy} ($distanceText)',
            body: '${alert.descriptionMy}\n${alert.actionAdviceMy}',
            payload: '{"type":"DISASTER_ALERT","route":"/weather-disaster","id":"${alert.id}"}',
          );
        }
      }
    } catch (e) {
      debugPrint('Disaster proximity check note: $e');
    }
  }

  /// Trigger emergency check manually on WebSocket event or manual pull
  Future<void> triggerManualCheck() async {
    await _checkDisasterProximity();
  }
}
