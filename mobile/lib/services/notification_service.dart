import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _lastCachedFcmToken;

  NotificationService._internal();

  static const String sirenChannelId = 'emergency_siren_channel_v5';
  static const String sirenChannelName = '🚨 Critical Emergency Siren & Alarms';
  static const String sirenChannelDesc =
      'High priority siren and vibration alerts for SOS emergencies that wake up the device';

  static const String disasterChannelId = 'disaster_proximity_siren_v1';
  static const String disasterChannelName = '🌪️ Natural Disaster Emergency Radar';
  static const String disasterChannelDesc =
      'Audible alarms and warning sirens for earthquakes, severe storms, and floods near your location in Myanmar';

  static const String bloodChannelId = 'blood_donation_alerts_v1';
  static const String bloodChannelName = '🩸 Blood Requests & Donation Alerts';
  static const String bloodChannelDesc =
      'Notifications for urgent patient blood requests, donor matches, and organization appointment approvals';

  static const String announcementChannelId = 'announcement_alerts_v1';
  static const String announcementChannelName = '📢 Official Announcements & News';
  static const String announcementChannelDesc =
      'Audible alerts for emergency broadcasts, disaster announcements, and government weather news';

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

      // Initialize Firebase Cloud Messaging for closed-app & background push notifications
      await _initFirebaseMessaging(onNotificationTap);
    } catch (e) {
      debugPrint('NotificationService init warning: $e');
    }
  }

  Future<void> _initFirebaseMessaging(Function(String? payload)? onNotificationTap) async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        _lastCachedFcmToken = token;
        debugPrint('FCM Token generated: $token');
        await syncDeviceToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) async {
        _lastCachedFcmToken = newToken;
        await syncDeviceToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        if (notification != null) {
          final type = data['type'] ?? data['event'] ?? '';
          if (type == 'ANNOUNCEMENT' || type == 'NEW_ANNOUNCEMENT') {
            showAnnouncementNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: notification.title ?? 'Official Announcement',
              body: notification.body ?? '',
              payload: json.encode(data),
            );
          } else if (type == 'EPHEMERAL_BROADCAST') {
            showEphemeralBroadcastNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: notification.title ?? 'Khu Nyi Kal Sal',
              body: notification.body ?? '',
              category: data['category'] ?? 'DAILY_QUOTE',
              payload: json.encode(data),
            );
          } else if (type == 'DISASTER_ALERT' || type == 'NEW_DISASTER_ALERT') {
            showDisasterProximityAlarm(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: notification.title ?? 'Disaster Warning',
              body: notification.body ?? '',
              payload: json.encode(data),
            );
          } else if (type == 'BLOOD_REQUEST' || type == 'NEW_BLOOD_SUPPLY_REQUEST' || type == 'BLOOD_REQUEST_ACCEPTED') {
            showBloodNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: notification.title ?? 'Blood Donation Alert',
              body: notification.body ?? '',
              payload: json.encode(data),
            );
          } else {
            showEmergencyAlert(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: notification.title ?? 'Emergency Alert',
              body: notification.body ?? '',
              payload: json.encode(data),
            );
          }
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (onNotificationTap != null) {
          onNotificationTap(json.encode(message.data));
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null && onNotificationTap != null) {
        onNotificationTap(json.encode(initialMessage.data));
      }
    } catch (e) {
      debugPrint('Firebase messaging initialization warning: $e');
    }
  }

  Future<void> syncSavedDeviceToken() async {
    if (_lastCachedFcmToken != null) {
      await syncDeviceToken(_lastCachedFcmToken!);
    } else {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          _lastCachedFcmToken = token;
          await syncDeviceToken(token);
        }
      } catch (_) {}
    }
  }

  Future<void> syncDeviceToken(String fcmToken) async {
    try {
      final api = ApiService();
      final hasToken = await api.getToken();
      if (hasToken != null) {
        await api.registerDeviceToken(fcmToken);
        debugPrint('Device token synced with backend: ${fcmToken.substring(0, 10)}...');
      }
    } catch (e) {
      debugPrint('Device token sync error: $e');
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

        final disasterChannel = AndroidNotificationChannel(
          disasterChannelId,
          disasterChannelName,
          description: disasterChannelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1200, 400, 1200, 400, 1200, 400, 1200]),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

        final bloodChannel = AndroidNotificationChannel(
          bloodChannelId,
          bloodChannelName,
          description: bloodChannelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          audioAttributesUsage: AudioAttributesUsage.notification,
        );

        final announcementChannel = AndroidNotificationChannel(
          announcementChannelId,
          announcementChannelName,
          description: announcementChannelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          audioAttributesUsage: AudioAttributesUsage.notification,
        );

        await androidPlugin.createNotificationChannel(sirenChannel);
        await androidPlugin.createNotificationChannel(disasterChannel);
        await androidPlugin.createNotificationChannel(bloodChannel);
        await androidPlugin.createNotificationChannel(announcementChannel);
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

  /// Plays high-priority loud siren alert for natural disasters occurring near the user in Myanmar
  Future<void> showDisasterProximityAlarm({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      triggerUrgentHapticAlarm();

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        disasterChannelId,
        disasterChannelName,
        channelDescription: disasterChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1200, 400, 1200, 400, 1200, 400, 1200]),
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
        interruptionLevel: InterruptionLevel.critical,
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
      debugPrint('Error showing disaster proximity alarm: $e');
    }
  }

  /// Displays audible notification for incoming blood requests & donor approvals
  Future<void> showBloodNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        bloodChannelId,
        bloodChannelName,
        channelDescription: bloodChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        category: AndroidNotificationCategory.message,
        audioAttributesUsage: AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails darwinPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
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
      debugPrint('Error showing blood notification: $e');
    }
  }

  /// Displays audible notification for Admin announcements, news bulletins, and weather warnings
  Future<void> showAnnouncementNotification({
    required int id,
    required String title,
    required String body,
    bool isPinned = false,
    String? payload,
  }) async {
    try {
      if (isPinned) {
        triggerUrgentHapticAlarm();
      } else {
        HapticFeedback.heavyImpact();
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        isPinned ? sirenChannelId : announcementChannelId,
        isPinned ? sirenChannelName : announcementChannelName,
        channelDescription: isPinned ? sirenChannelDesc : announcementChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(isPinned ? [0, 1000, 300, 1000] : [0, 500, 200, 500]),
        category: isPinned ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.event,
        audioAttributesUsage: isPinned ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,
      );

      final DarwinNotificationDetails darwinPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isPinned ? InterruptionLevel.critical : InterruptionLevel.timeSensitive,
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
      debugPrint('Error showing announcement notification: $e');
    }
  }

  /// Displays audible notification for temporary ephemeral broadcasts, Daily Quotes, and Missing Person alerts
  Future<void> showEphemeralBroadcastNotification({
    required int id,
    required String title,
    required String body,
    String category = 'DAILY_QUOTE',
    String? payload,
  }) async {
    try {
      final isUrgent = category == 'MISSING_PERSON';
      if (isUrgent) {
        triggerUrgentHapticAlarm();
      } else {
        HapticFeedback.mediumImpact();
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        isUrgent ? sirenChannelId : announcementChannelId,
        isUrgent ? sirenChannelName : announcementChannelName,
        channelDescription: isUrgent ? sirenChannelDesc : announcementChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(isUrgent ? [0, 1000, 300, 1000] : [0, 400, 150, 400]),
        category: isUrgent ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.event,
        audioAttributesUsage: isUrgent ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,
      );

      final DarwinNotificationDetails darwinPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isUrgent ? InterruptionLevel.critical : InterruptionLevel.active,
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
      debugPrint('Error showing ephemeral broadcast notification: $e');
    }
  }
}
