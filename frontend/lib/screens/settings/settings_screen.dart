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
    
    final title = isMm ? 'ဆက်တင်များ' : 'Settings';
    final langTitle = isMm ? 'ဘာသာစကား' : 'Language';
    final desc = isMm 
        ? 'သင်အသုံးပြုလိုသော ဘာသာစကားကို ရွေးချယ်ပါ။' 
        : 'Choose your preferred language.';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMm ? 'အကောင့်' : 'Account',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListTile(
                  leading: const Icon(Icons.person, color: AppTheme.primaryRed),
                  title: Text(
                    isMm ? 'ကိုယ်ရေးအချက်အလက် ပြင်ဆင်ရန်' : 'Update Profile',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/profile');
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                langTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: 'en',
                      groupValue: settings.locale.languageCode,
                      onChanged: (val) => settingsNotifier.setLocale(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('မြန်မာ', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: 'my',
                      groupValue: settings.locale.languageCode,
                      onChanged: (val) => settingsNotifier.setLocale(val!),
                      activeColor: AppTheme.primaryRed,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Logout Button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text(isMm ? 'အကောင့်မှထွက်မည်' : 'Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isMm ? 'အကောင့်မှထွက်မည်' : 'Log Out'),
                        content: Text(
                          isMm
                              ? 'အကောင့်မှထွက်မည် သေချာပါသလား။'
                              : 'Are you sure you want to log out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                            child: Text(
                              isMm ? 'အကောင့်မှထွက်မည်' : 'Log Out',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
