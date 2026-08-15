import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService().getProfile();
      if (mounted) {
        setState(() {
          _profile = res.data;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final role = (auth.role ?? 'user').toLowerCase();
    final isVolunteer = role == 'volunteer' || role == 'admin' || role == 'superadmin';
    final isOrg = role == 'organization' || role == 'admin' || role == 'superadmin';
    final isAdmin = role == 'admin' || role == 'superadmin';

    final fullName = _profile?['full_name'] ?? _profile?['org_name'] ?? auth.email?.split('@').first ?? 'User';
    final phone = _profile?['phone_number'] ?? '';
    final bloodType = _profile?['blood_type'];

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'ပိုမိုသိရှိရန်' : 'More Services',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: isMm ? 'ဆက်တင်များ' : 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Banner Card ─────────────────────────────────
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            (fullName.isNotEmpty ? fullName[0] : '?').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (bloodType != null && bloodType.toString().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryRed,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      bloodType,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone.isNotEmpty ? phone : (auth.email ?? ''),
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Featured Service: Blood Donation ────────────────────
              Text(
                isMm ? 'အထူးဝန်ဆောင်မှု' : 'Featured Services',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => context.push('/blood-donation'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFC2185B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.water_drop, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isMm ? 'သွေးလှူဒါန်းခြင်း ဗဟိုဌာန' : 'Blood Donation Hub',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMm
                                  ? 'သွေးလှူဒါန်းရန်နှင့် အရေးပေါ် သွေးတောင်းခံရန်'
                                  : 'Donate blood or request emergency blood units',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Emergency & Rescue Services ─────────────────────────
              Text(
                isMm ? 'အရေးပေါ်နှင့် ကယ်ဆယ်ရေး ဝန်ဆောင်မှုများ' : 'Emergency & Rescue Services',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 12),
              _menuTile(
                icon: Icons.medical_services_outlined,
                color: AppTheme.primaryRed,
                title: isMm ? 'အရေးပေါ် ရှေးဦးသူနာပြုစုနည်း' : 'First Aid Guide',
                subtitle: isMm ? 'အော့ဖ်လိုင်း အသုံးပြုနိုင်သော လမ်းညွှန်' : 'Offline emergency medical manual',
                onTap: () => context.push('/first-aid'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.business_outlined,
                color: Colors.blue,
                title: isMm ? 'ကယ်ဆယ်ရေး အဖွဲ့အစည်းများ' : 'Rescue Organizations',
                subtitle: isMm ? 'အနီးဆုံး ကယ်ဆယ်ရေးအဖွဲ့များ စာရင်း' : 'Directory of nearby rescue units',
                onTap: () => context.push('/organizations'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.family_restroom_outlined,
                color: Colors.teal,
                title: isMm ? 'မိသားစု အဖွဲ့' : 'Family Safety Circle',
                subtitle: isMm ? 'မိသားစုဝင်များနှင့် အရေးပေါ်ချိတ်ဆက်ရန်' : 'Emergency network with loved ones',
                onTap: () => context.push('/family'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.notifications_active_outlined,
                color: Colors.orange,
                title: isMm ? 'မိသားစု အရေးပေါ် သတိပေးချက်များ' : 'Family Emergency Alerts',
                subtitle: isMm ? 'မိသားစုဝင်များ၏ အရေးပေါ်အခြေအနေများ' : 'Active alerts from your circle',
                onTap: () => context.push('/family-alerts'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const SizedBox(height: 24),

              // ── Settings & Security ─────────────────────────────────
              Text(
                isMm ? 'ဆက်တင်နှင့် လုံခြုံရေး' : 'Settings & Security',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 12),
              _menuTile(
                icon: Icons.person_outline_rounded,
                color: Colors.indigo,
                title: isMm ? 'ပရိုဖိုင်နှင့် ဆေးမှတ်တမ်း' : 'My Profile & Medical Info',
                subtitle: isMm ? 'သွေးအမျိုးအစားနှင့် အချက်အလက်များ ပြင်ဆင်ရန်' : 'Update blood type, contacts & medical info',
                onTap: () => context.push('/profile'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.language_rounded,
                color: Colors.green,
                title: isMm ? 'ဆက်တင်နှင့် ဘာသာစကား' : 'Language & Themes',
                subtitle: isMm ? 'ဘာသာစကားနှင့် အပြင်အဆင် ပြောင်းလဲရန်' : 'Theme mode, app language and alerts',
                onTap: () => context.push('/settings'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.devices_rounded,
                color: Colors.deepPurple,
                title: isMm ? 'ချိတ်ဆက်ထားသော စက်ပစ္စည်းများ' : 'Connected Devices',
                subtitle: isMm ? 'လက်ရှိ အသုံးပြုနေသော ဖုန်းနှင့် ကွန်ပျူတာများ' : 'Manage active login sessions',
                onTap: () => context.push('/settings/devices'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.lock_reset_rounded,
                color: Colors.amber.shade900,
                title: isMm ? 'စကားဝှက် ပြောင်းလဲရန်' : 'Change Password',
                subtitle: isMm ? 'အကောင့်လုံခြုံရေးအတွက် စကားဝှက်အသစ်သတ်မှတ်ရန်' : 'Update account login password',
                onTap: () => context.push('/change-password'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.help_outline_rounded,
                color: Colors.brown,
                title: isMm ? 'အသုံးပြုပုံ လမ်းညွှန်' : 'How to Use App',
                subtitle: isMm ? 'အရေးပေါ် အသုံးပြုနည်း အဆင့်ဆင့်' : 'Step-by-step emergency user manual',
                onTap: () => context.push('/how-to-use'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.gavel_rounded,
                color: Colors.blueGrey,
                title: isMm ? 'စည်းမျဉ်းနှင့် ဥပဒေများ' : 'Rules & Legal Regulations',
                subtitle: isMm ? 'တရားဝင် သဘောတူညီချက်များ' : 'Terms of service and privacy',
                onTap: () => context.push('/rules-laws'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.campaign_rounded,
                color: Colors.deepOrange,
                title: isMm ? 'သတင်းနှင့် ထုတ်ပြန်ချက်များ' : 'Announcements & News',
                subtitle: isMm ? 'ဗဟိုဌာနချုပ်၏ တရားဝင် သတင်းလွှာများ' : 'Official emergency bulletins & news',
                onTap: () => context.push('/announcements'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _menuTile(
                icon: Icons.volunteer_activism_rounded,
                color: AppTheme.primaryRed,
                title: isMm ? 'လှူဒါန်းထောက်ပံ့ရန်' : 'Support Our Mission',
                subtitle: isMm ? 'KBZPay, WavePay, MMQR ဖြင့် လှူဒါန်းရန်' : 'Donate via KBZPay, WavePay & Bank Transfer',
                onTap: () => context.push('/support-us'),
                cardBg: cardBg,
                cardBorder: cardBorder,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // ── Privileged Role Portals ─────────────────────────────
              if (isVolunteer || isOrg || isAdmin) ...[
                const SizedBox(height: 24),
                Text(
                  isMm ? 'တာဝန်ကျ ကွန်ဆိုးလ်များ' : 'Privileged Portals',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 12),
                if (isVolunteer)
                  _menuTile(
                    icon: Icons.health_and_safety_outlined,
                    color: AppTheme.secondaryGreen,
                    title: 'Volunteer Dashboard',
                    subtitle: 'View and respond to assigned emergencies',
                    onTap: () => context.push('/volunteer-dashboard'),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                if (isOrg)
                  _menuTile(
                    icon: Icons.local_hospital_outlined,
                    color: Colors.redAccent,
                    title: 'Organization Console',
                    subtitle: 'Manage rescue operations and dispatch',
                    onTap: () => context.push('/org-dashboard'),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                if (isAdmin)
                  _menuTile(
                    icon: Icons.admin_panel_settings_outlined,
                    color: isDark ? Colors.amber : Colors.black87,
                    title: 'Super Admin Command Center',
                    subtitle: 'Manage organizations, SOS radar & abuse',
                    onTap: () => context.push('/admin-dashboard'),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
              ],

              const SizedBox(height: 32),

              // ── Log Out Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: Text(
                    isMm ? 'အကောင့်မှ ထွက်မည်' : 'Log Out',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _confirmLogout(context, isMm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, bool isMm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMm ? 'အကောင့်မှ ထွက်ရန်' : 'Log Out'),
        content: Text(
          isMm
              ? 'အကောင့်မှ ထွက်ရန် သေချာပါသလား?'
              : 'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isMm ? 'မထွက်ပါ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().cancelActiveEmergencies();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              isMm ? 'ထွက်မည်' : 'Log Out',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
        trailing: Icon(Icons.chevron_right, color: textSecondary.withValues(alpha: 0.5), size: 20),
        onTap: onTap,
      ),
    );
  }
}
