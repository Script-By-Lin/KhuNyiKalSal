import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  static const String sirenChannelId = 'emergency_siren_channel_v5';
  static const String sirenChannelName = '🚨 Critical Emergency Siren & Alarms';
  static const String sirenChannelDesc =
      'High priority siren and vibration alerts for SOS emergencies that wake up the device';

  Future<void> init({Function(String? payload)? onNotificationTap}) async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (onNotificationTap != null) {
            onNotificationTap(response.payload);
          }
        },
      );

      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }
      await _requestPermissions();
    } catch (e) {
      debugPrint('NotificationService init warning: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final sirenChannel = AndroidNotificationChannel(
          sirenChannelId,
          sirenChannelName,
          description: sirenChannelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 300, 1000, 300, 1000, 300, 1000]),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

        await androidPlugin.createNotificationChannel(sirenChannel);
      }
    } catch (e) {
      debugPrint('Error creating notification channel: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  Future<void> triggerUrgentHapticAlarm() async {
    try {
      for (int i = 0; i < 4; i++) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 350));
      }
    } catch (_) {}
  }

  Future<void> showEmergencyAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        sirenChannelId,
        sirenChannelName,
        channelDescription: sirenChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 300, 1000, 300, 1000, 300, 1000]),
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails darwinPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinPlatformChannelSpecifics,
        macOS: darwinPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing emergency alert: $e');
    }
  }
}
