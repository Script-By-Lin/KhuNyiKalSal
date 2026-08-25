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
      if (call.method == 'onEmergencyTripleClick') {
        _handleTripleClick();
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
}
