import 'package:flutter/services.dart';
import '../config/routes.dart';
import 'notification_service.dart';

class HardwareTriggerService {
  static final HardwareTriggerService _instance = HardwareTriggerService._internal();
  factory HardwareTriggerService() => _instance;
  HardwareTriggerService._internal();

  static const MethodChannel _channel = MethodChannel('com.khunyikalsal/emergency_trigger');
  bool _initialized = false;
  VoidCallback? onTripleClickCustomHandler;

  void init({VoidCallback? onTripleClick}) {
    if (_initialized) return;
    _initialized = true;
    if (onTripleClick != null) {
      onTripleClickCustomHandler = onTripleClick;
    }

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onEmergencyTripleClick':
          _handleTripleClick();
          break;
        case 'onQuickSosShortcut':
          _handleQuickSosShortcut();
          break;
        case 'onDisasterRadarShortcut':
          _handleDisasterRadarShortcut();
          break;
        default:
          break;
      }
    });
  }

  void _handleTripleClick() {
    NotificationService().triggerUrgentHapticAlarm();
    if (onTripleClickCustomHandler != null) {
      onTripleClickCustomHandler!();
    } else {
      // Default: navigate to emergency home / SOS
      try {
        goRouter.push('/home');
      } catch (_) {}
    }
  }

  void _handleQuickSosShortcut() {
    NotificationService().triggerUrgentHapticAlarm();
    try {
      goRouter.go('/home');
    } catch (_) {}
  }

  void _handleDisasterRadarShortcut() {
    try {
      goRouter.push('/weather-disaster');
    } catch (_) {}
  }
}
