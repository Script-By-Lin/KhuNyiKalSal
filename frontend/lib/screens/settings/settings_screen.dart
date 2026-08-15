import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../config/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isMm = settings.locale.languageCode == 'my';
    
    final title = isMm ? 'ဆက်တင်နှင့် ဘာသာစကား' : 'Settings & Language';
    final themeTitle = isMm ? 'အသွင်အပြင် (Theme Mode)' : 'Appearance & Theme';
    final themeDesc = isMm ? 'အလင်း သို့မဟုတ် အမှောင် မုဒ် ရွေးချယ်ပါ' : 'Choose light, dark, or system default mode';
    final langTitle = isMm ? 'ဘာသာစကား (Language)' : 'Language';
    final langDesc = isMm 
        ? 'သင်အသုံးပြုလိုသော ဘာသာစကားကို ရွေးချယ်ပါ။' 
        : 'Choose your preferred language.';

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Theme / Appearance Section ────────────────────────
              Text(
                themeTitle,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                themeDesc,
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 12),
              Card(
                color: cardBg,
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cardBorder),
                ),
                child: RadioGroup<ThemeMode>(
                  groupValue: settings.themeMode,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        secondary: const Icon(Icons.light_mode_outlined, color: Colors.amber),
                        title: Text(
                          isMm ? 'အလင်းမုဒ် (Light Mode)' : 'Light Mode',
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        value: ThemeMode.light,
                        activeColor: AppTheme.primaryRed,
                      ),
                      Divider(height: 1, color: cardBorder),
                      RadioListTile<ThemeMode>(
                        secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigoAccent),
                        title: Text(
                          isMm ? 'အမှောင်မုဒ် (Dark Mode)' : 'Dark Mode',
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        value: ThemeMode.dark,
                        activeColor: AppTheme.primaryRed,
                      ),
                      Divider(height: 1, color: cardBorder),
                      RadioListTile<ThemeMode>(
                        secondary: Icon(Icons.settings_brightness_outlined, color: textSecondary),
                        title: Text(
                          isMm ? 'စနစ်သုံး မုဒ် (System Default)' : 'System Default',
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        value: ThemeMode.system,
                        activeColor: AppTheme.primaryRed,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),
              
              // ── Language Section ──────────────────────────────────
              Text(
                langTitle,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                langDesc,
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 12),
              Card(
                color: cardBg,
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cardBorder),
                ),
                child: RadioGroup<String>(
                  groupValue: settings.locale.languageCode,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setLocale(val);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        secondary: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                        title: Text('English', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        value: 'en',
                        activeColor: AppTheme.primaryRed,
                      ),
                      Divider(height: 1, color: cardBorder),
                      RadioListTile<String>(
                        secondary: const Text('🇲🇲', style: TextStyle(fontSize: 22)),
                        title: Text('မြန်မာ', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        value: 'my',
                        activeColor: AppTheme.primaryRed,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── App Brand Footer ─────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo_symbol_transparent.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Khu Nyi Kal Sal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Version 2.2.0 (Build 2026.08)',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
