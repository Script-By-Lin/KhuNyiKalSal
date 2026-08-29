import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';

import 'dart:convert';
import 'services/notification_service.dart';
import 'services/hardware_trigger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HardwareTriggerService().init();

  await NotificationService().init(
    onNotificationTap: (payload) {
      if (payload != null && payload.isNotEmpty) {
        try {
          final data = json.decode(payload);
          if (data['route'] != null) {
            goRouter.push(data['route'].toString());
            return;
          }
          if (data['type'] == 'ANNOUNCEMENT' || data['event'] == 'NEW_ANNOUNCEMENT') {
            goRouter.push('/announcements');
            return;
          }
          if (data['type'] == 'EPHEMERAL_BROADCAST' || data['event'] == 'EPHEMERAL_BROADCAST') {
            goRouter.push('/announcements');
            return;
          }
          if (data['event'] == 'BLOOD_REQUEST_ACCEPTED' || data['event'] == 'NEW_BLOOD_SUPPLY_REQUEST' || data['type'] == 'BLOOD_REQUEST') {
            goRouter.push('/blood-donation');
            return;
          }
          if (data['type'] == 'DISASTER_ALERT' || data['event'] == 'NEW_DISASTER_ALERT' || data['type'] == 'EARTHQUAKE') {
            goRouter.push('/weather-disaster');
            return;
          }
          if (data['event'] == 'FAMILY_SOS_ALERT' || data['type'] == 'FAMILY_ALERT' || data['type'] == 'FAMILY_SOS') {
            final loc = data['location'] ?? data;
            final lat = (loc['lat'] as num?)?.toDouble();
            final lng = (loc['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              goRouter.push('/map', extra: {
                'lat': lat,
                'lng': lng,
                'title': data['title'] ?? data['message'] ?? '🚨 Family Emergency SOS Target',
                'returnRoute': '/family-alerts',
              });
              return;
            }
            goRouter.push('/family-alerts');
            return;
          }
          final loc = data['location'] ?? data;
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            if (data['event'] == 'SOS_CREATED') {
              goRouter.push('/mission-map', extra: {
                'lat': lat,
                'lng': lng,
                'title': data['title'] ?? data['message'] ?? '🚨 Emergency SOS Target',
                'returnRoute': '/org-dashboard',
              });
              return;
            }
            goRouter.push('/map', extra: {
              'lat': lat,
              'lng': lng,
              'title': data['title'] ?? data['message'] ?? '🚨 Emergency Target',
              'returnRoute': '/home',
            });
            return;
          }
        } catch (_) {}
      }
      // Default to home
      goRouter.go('/home');
    },
  );
  runApp(const ProviderScope(child: KhuNyiKalSalApp()));
}

class KhuNyiKalSalApp extends ConsumerStatefulWidget {
  const KhuNyiKalSalApp({super.key});

  @override
  ConsumerState<KhuNyiKalSalApp> createState() => _KhuNyiKalSalAppState();
}

class _KhuNyiKalSalAppState extends ConsumerState<KhuNyiKalSalApp> {
  @override
  void initState() {
    super.initState();
    // Try auto-login from stored token in local storage
    Future.microtask(() async {
      final role = await ref.read(authProvider.notifier).tryAutoLogin();
      if (role != null) {
        final lowerRole = role.toLowerCase();
        if (lowerRole == 'volunteer') {
          goRouter.go('/volunteer-dashboard');
        } else if (lowerRole == 'organization') {
          goRouter.go('/org-dashboard');
        } else {
          goRouter.go('/home');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Khu Nyi Kal Sal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: settings.locale,
      // Minimal localization support placeholders:
      supportedLocales: const [Locale('en'), Locale('my')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: goRouter,
    );
  }
}
