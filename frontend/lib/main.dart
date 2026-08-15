import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';

import 'dart:convert';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init(
    onNotificationTap: (payload) {
      if (payload != null && payload.isNotEmpty) {
        try {
          final data = json.decode(payload);
          final loc = data['location'] ?? data;
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            goRouter.push('/mission-map', extra: {
              'lat': lat,
              'lng': lng,
              'title': data['title'] ?? data['message'] ?? '🚨 Emergency SOS Target',
            });
            return;
          }
        } catch (_) {}
      }
      // Default to family alerts or map
      goRouter.go('/family-alerts');
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
        } else if (lowerRole == 'admin' || lowerRole == 'superadmin') {
          goRouter.go('/admin-dashboard');
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
