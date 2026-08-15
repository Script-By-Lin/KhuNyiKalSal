import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final isMm = settings.locale.languageCode == 'my';
    
    final title = isMm ? 'ဆက်တင်နှင့် ဘာသာစကား' : 'Settings & Language';
    final themeTitle = isMm ? 'အသွင်အပြင် (Theme Mode)' : 'Appearance & Theme';
    final themeDesc = isMm ? 'အလင်း သို့မဟုတ် အမှောင် မုဒ် ရွေးချယ်ပါ' : 'Choose light, dark, or system default mode';
    final langTitle = isMm ? 'ဘာသာစကား (Language)' : 'Language';
    final langDesc = isMm 
        ? 'သင်အသုံးပြုလိုသော ဘာသာစကားကို ရွေးချယ်ပါ။' 
        : 'Choose your preferred language.';

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
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                themeDesc,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      secondary: const Icon(Icons.light_mode_outlined, color: Colors.amber),
                      title: Text(
                        isMm ? 'အလင်းမုဒ် (Light Mode)' : 'Light Mode',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: ThemeMode.light,
                      groupValue: settings.themeMode,
                      onChanged: (val) => settingsNotifier.setThemeMode(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigo),
                      title: Text(
                        isMm ? 'အမှောင်မုဒ် (Dark Mode)' : 'Dark Mode',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: ThemeMode.dark,
                      groupValue: settings.themeMode,
                      onChanged: (val) => settingsNotifier.setThemeMode(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      secondary: const Icon(Icons.settings_brightness_outlined, color: Colors.blueGrey),
                      title: Text(
                        isMm ? 'စနစ်သုံး မုဒ် (System Default)' : 'System Default',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: ThemeMode.system,
                      groupValue: settings.themeMode,
                      onChanged: (val) => settingsNotifier.setThemeMode(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              
              // ── Language Section ──────────────────────────────────
              Text(
                langTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                langDesc,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      secondary: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                      title: const Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: 'en',
                      groupValue: settings.locale.languageCode,
                      onChanged: (val) => settingsNotifier.setLocale(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      secondary: const Text('🇲🇲', style: TextStyle(fontSize: 22)),
                      title: const Text('မြန်မာ', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: 'my',
                      groupValue: settings.locale.languageCode,
                      onChanged: (val) => settingsNotifier.setLocale(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                  ],
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
                        color: Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'v1.0.0 • Myanmar Emergency Response',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Logout Button ────────────────────────────────────
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRed.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                  label: Text(
                    isMm ? 'အကောင့်မှ ထွက်မည်' : 'Log Out',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            const Icon(Icons.logout_rounded, color: AppTheme.primaryRed),
                            const SizedBox(width: 10),
                            Text(isMm ? 'အကောင့်မှ ထွက်မည်' : 'Log Out'),
                          ],
                        ),
                        content: Text(
                          isMm
                              ? 'အကောင့်မှ ထွက်ရန် သေချာပါသလား။'
                              : 'Are you sure you want to log out?',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                            child: Text(
                              isMm ? 'ထွက်မည်' : 'Log Out',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
