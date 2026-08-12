import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

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
    final savedLang = await _storage.read(key: 'locale_lang');

    Locale loc = const Locale('en');
    if (savedLang != null && savedLang.isNotEmpty) {
      loc = Locale(savedLang);
    }

    state = state.copyWith(locale: loc);
  }

  Future<void> setLocale(String langCode) async {
    state = state.copyWith(locale: Locale(langCode));
    await _storage.write(key: 'locale_lang', value: langCode);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
