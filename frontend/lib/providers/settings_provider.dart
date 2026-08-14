import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

class AppSettings {
  final Locale locale;

  AppSettings({
    required this.locale,
  });

  AppSettings copyWith({
    Locale? locale,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier()
      : super(AppSettings(
          locale: const Locale('en'),
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final savedLang = await _storage.read(key: 'locale_lang');

      Locale loc = const Locale('en');
      if (savedLang != null && savedLang.isNotEmpty) {
        loc = Locale(savedLang);
      }

      state = state.copyWith(locale: loc);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  Future<void> setLocale(String langCode) async {
    state = state.copyWith(locale: Locale(langCode));
    try {
      await _storage.write(key: 'locale_lang', value: langCode);
    } catch (_) {}
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
