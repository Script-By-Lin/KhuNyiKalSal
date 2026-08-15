import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

class AppSettings {
  final Locale locale;
  final ThemeMode themeMode;

  AppSettings({
    required this.locale,
    this.themeMode = ThemeMode.light,
  });

  AppSettings copyWith({
    Locale? locale,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier()
      : super(AppSettings(
          locale: const Locale('en'),
          themeMode: ThemeMode.light,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final savedLang = await _storage.read(key: 'locale_lang');
      final savedTheme = await _storage.read(key: 'theme_mode');

      Locale loc = const Locale('en');
      if (savedLang != null && savedLang.isNotEmpty) {
        loc = Locale(savedLang);
      }

      ThemeMode mode = ThemeMode.light;
      if (savedTheme == 'dark') {
        mode = ThemeMode.dark;
      } else if (savedTheme == 'system') {
        mode = ThemeMode.system;
      } else {
        mode = ThemeMode.light;
      }

      state = state.copyWith(locale: loc, themeMode: mode);
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

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      String modeStr = 'light';
      if (mode == ThemeMode.dark) {
        modeStr = 'dark';
      } else if (mode == ThemeMode.system) {
        modeStr = 'system';
      }
      await _storage.write(key: 'theme_mode', value: modeStr);
    } catch (_) {}
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
