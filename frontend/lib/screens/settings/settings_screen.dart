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
                child: Column(
                  children: [
                    ListTile(
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
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.devices, color: AppTheme.primaryRed),
                      title: Text(
                        isMm ? 'ချိတ်ဆက်ထားသော စက်များ' : 'Connected Devices',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push('/settings/devices');
                      },
                    ),
                  ],
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
            ],
          ),
        ),
      ),
    );
  }
}
