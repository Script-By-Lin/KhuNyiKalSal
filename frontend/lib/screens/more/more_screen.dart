import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dio/dio.dart';
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
    final auth = ref.watch(authProvider);
    final role = (auth.role ?? 'user').toLowerCase();
    final isVolunteer = role == 'volunteer' || role == 'admin' || role == 'superadmin';
    final isOrg = role == 'organization' || role == 'admin' || role == 'superadmin';
    final isAdmin = role == 'admin' || role == 'superadmin';

    final fullName = _profile?['full_name'] ?? auth.email?.split('@').first ?? 'User';
    final phone = _profile?['phone_number'] ?? '';
    final bloodType = _profile?['blood_type'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
                          color: AppTheme.primaryRed.withValues(alpha: 0.1),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
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
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Featured Service: Blood Donation ────────────────────
              Text(
                isMm ? 'အထူးဝန်ဆောင်မှု' : 'Featured Services',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                        color: Colors.red.withValues(alpha: 0.25),
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
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bloodtype, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isMm ? 'သွေးလှူဒါန်းရန်' : 'Blood Donation Hub',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: AppTheme.primaryRed,
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
                                  ? 'အနီးဆုံးဆေးရုံ/သွေးဘဏ် ရွေးချယ်၍ ရက်ချိန်းရယူရန်'
                                  : 'Schedule a blood donation with nearest hospital',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── General Emergency Options ───────────────────────────
              Text(
                isMm ? 'အရေးပေါ်နှင့် ကျန်းမာရေး' : 'Emergency & Health',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _menuTile(
                icon: Icons.medical_services_outlined,
                color: AppTheme.primaryRed,
                title: isMm ? 'အော့ဖ်လိုင်း ရှေးဦးပြုစုနည်းများ' : 'Offline First-Aid Guides',
                subtitle: isMm ? '၁၀၀% အင်တာနက်မလိုဘဲ ဖတ်ရှုနိုင်သော နည်းလမ်းများ' : 'Survival protocols without internet',
                onTap: () => context.push('/first-aid'),
              ),
              _menuTile(
                icon: Icons.business_outlined,
                color: AppTheme.secondaryGreen,
                title: isMm ? 'ကယ်ဆယ်ရေးအဖွဲ့များ' : 'Rescue Organizations',
                subtitle: isMm ? 'ဒေသတွင်း အဖွဲ့များ ကြည့်ရှုရန်' : 'View all registered rescue organizations',
                onTap: () => context.push('/organizations'),
              ),
              _menuTile(
                icon: Icons.family_restroom,
                color: Colors.purple,
                title: isMm ? 'မိသားစု အဖွဲ့' : 'Family Emergency Network',
                subtitle: isMm ? 'မိသားစုဝင်များ ချိတ်ဆက်စီမံရန်' : 'Link family members for instant SOS alerts',
                onTap: () => context.push('/family'),
              ),
              _menuTile(
                icon: Icons.notifications_active_outlined,
                color: Colors.deepOrange,
                title: isMm ? 'အရေးပေါ် သတိပေးချက်များ' : 'Emergency SOS Alerts',
                subtitle: isMm ? 'မိသားစုဝင်များထံမှ သတိပေးချက်မှတ်တမ်း' : 'Real-time alert messages & logs',
                onTap: () => context.push('/family-alerts'),
              ),

              const SizedBox(height: 24),

              // ── App Settings & Security ─────────────────────────────
              Text(
                isMm ? 'ဆက်တင်နှင့် လုံခြုံရေး' : 'Settings & Security',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _menuTile(
                icon: Icons.person_outline,
                color: Colors.blue,
                title: isMm ? 'ကိုယ်ရေးအချက်အလက် ပြင်ဆင်ရန်' : 'My Profile & Medical Info',
                subtitle: isMm ? 'ပရိုဖိုင်နှင့် ဆေးဘက်မှတ်တမ်းများ' : 'Update blood type, contacts & medical info',
                onTap: () => context.push('/profile'),
              ),
              _menuTile(
                icon: Icons.language_rounded,
                color: Colors.teal,
                title: isMm ? 'ဆက်တင်နှင့် ဘာသာစကား' : 'Settings & Language',
                subtitle: isMm ? 'မြန်မာ / English ပြောင်းလဲရန်' : 'App language and notifications',
                onTap: () => context.push('/settings'),
              ),
              _menuTile(
                icon: Icons.devices_outlined,
                color: Colors.indigo,
                title: isMm ? 'ချိတ်ဆက်ထားသော စက်များ' : 'Connected Devices',
                subtitle: isMm ? 'စက်ပစ္စည်းများကို စီမံခန့်ခွဲရန်' : 'Manage active login sessions',
                onTap: () => context.push('/settings/devices'),
              ),
              _menuTile(
                icon: Icons.lock_reset_rounded,
                color: Colors.amber.shade900,
                title: isMm ? 'စကားဝှက် ပြောင်းလဲရန်' : 'Change Password',
                subtitle: isMm ? 'အကောင့်လုံခြုံရေးအတွက် စကားဝှက်အသစ်သတ်မှတ်ရန်' : 'Update account login password',
                onTap: () => _showChangePasswordDialog(context, isMm),
              ),
              _menuTile(
                icon: Icons.help_outline_rounded,
                color: Colors.brown,
                title: isMm ? 'အသုံးပြုပုံ လမ်းညွှန်' : 'How to Use App',
                subtitle: isMm ? 'အရေးပေါ် အသုံးပြုနည်း အဆင့်ဆင့်' : 'Step-by-step emergency user manual',
                onTap: () => context.push('/how-to-use'),
              ),
              _menuTile(
                icon: Icons.gavel_rounded,
                color: Colors.blueGrey,
                title: isMm ? 'စည်းမျဉ်းနှင့် ဥပဒေများ' : 'Rules & Legal Regulations',
                subtitle: isMm ? 'တရားဝင် သဘောတူညီချက်များ' : 'Terms of service and privacy',
                onTap: () => context.push('/legal'),
              ),
              _menuTile(
                icon: Icons.campaign_rounded,
                color: Colors.deepOrange,
                title: isMm ? 'သတင်းနှင့် ထုတ်ပြန်ချက်များ' : 'Announcements & News',
                subtitle: isMm ? 'ဗဟိုဌာနချုပ်၏ တရားဝင် သတင်းလွှာများ' : 'Official emergency bulletins & news',
                onTap: () => context.push('/announcements'),
              ),
              _menuTile(
                icon: Icons.volunteer_activism_rounded,
                color: AppTheme.primaryRed,
                title: isMm ? 'လှူဒါန်းထောက်ပံ့ရန်' : 'Support Our Mission',
                subtitle: isMm ? 'KBZPay, WavePay, MMQR ဖြင့် လှူဒါန်းရန်' : 'Donate via KBZPay, WavePay & Bank Transfer',
                onTap: () => context.push('/support-us'),
              ),

              // ── Privileged Role Portals ─────────────────────────────
              if (isVolunteer || isOrg || isAdmin) ...[
                const SizedBox(height: 24),
                Text(
                  isMm ? 'တာဝန်ကျ ကွန်ဆိုးလ်များ' : 'Privileged Portals',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (isVolunteer)
                  _menuTile(
                    icon: Icons.health_and_safety_outlined,
                    color: Colors.green.shade700,
                    title: 'Volunteer Mission Center',
                    subtitle: 'Respond to nearby citizen emergency SOS calls',
                    onTap: () => context.push('/volunteer-dashboard'),
                  ),
                if (isOrg)
                  _menuTile(
                    icon: Icons.local_hospital_outlined,
                    color: AppTheme.primaryRed,
                    title: 'Organization Command Center',
                    subtitle: 'Manage rescue fleet, dispatch & blood appointments',
                    onTap: () => context.push('/org-dashboard'),
                  ),
                if (isAdmin)
                  _menuTile(
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.black87,
                    title: 'Super Admin Control Panel',
                    subtitle: 'Manage organizations and system data',
                    onTap: () => context.push('/admin-dashboard'),
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
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

              const SizedBox(height: 24),

              // ── App Brand Footer ────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo_symbol_transparent.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Khu Nyi Kal Sal • v1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
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

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, bool isMm) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_reset_rounded, color: Colors.amber.shade900, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMm ? 'စကားဝှက် ပြောင်းလဲရန်' : 'Change Password',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isMm ? 'အကောင့်လုံခြုံရေးအတွက် စကားဝှက်အသစ်သတ်မှတ်ပါ' : 'Set a new secure login password',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Current Password
                    Text(
                      isMm ? 'လက်ရှိ စကားဝှက်' : 'Current Password',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        hintText: isMm ? 'လက်ရှိ စကားဝှက် ရိုက်ထည့်ပါ' : 'Enter current password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // New Password
                    Text(
                      isMm ? 'စကားဝှက် အသစ်' : 'New Password',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        hintText: isMm ? 'အနည်းဆုံး ၆ လုံး (စာလုံးကြီး၊ စာလုံးသေး၊ ဂဏန်း)' : 'At least 6 chars (A-Z, a-z, 0-9)',
                        prefixIcon: const Icon(Icons.key_outlined, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirm New Password
                    Text(
                      isMm ? 'စကားဝှက် အသစ် ထပ်မံရိုက်ထည့်ပါ' : 'Confirm New Password',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmPassController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        hintText: isMm ? 'စကားဝှက် အသစ် ပြန်ရိုက်ပါ' : 'Re-enter new password',
                        prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final currentPass = currentPassController.text.trim();
                                final newPass = newPassController.text.trim();
                                final confirmPass = confirmPassController.text.trim();

                                if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                                  setModalState(() {
                                    errorMessage = isMm
                                        ? 'စကားဝှက်အကွက်များ အားလုံးဖြည့်သွင်းပေးပါ။'
                                        : 'Please fill in all password fields.';
                                  });
                                  return;
                                }

                                if (newPass != confirmPass) {
                                  setModalState(() {
                                    errorMessage = isMm
                                        ? 'စကားဝှက်အသစ် နှစ်ခု တူညီမှုမရှိပါ။'
                                        : 'New password and confirmation do not match.';
                                  });
                                  return;
                                }

                                if (newPass.length < 6) {
                                  setModalState(() {
                                    errorMessage = isMm
                                        ? 'စကားဝှက်သည် အနည်းဆုံး ၆ လုံး ရှိရပါမည်။'
                                        : 'Password must be at least 6 characters long.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  errorMessage = null;
                                });

                                try {
                                  await ApiService().changePassword(
                                    currentPassword: currentPass,
                                    newPassword: newPass,
                                  );

                                  if (modalCtx.mounted) {
                                    Navigator.pop(ctx);
                                  }

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isMm
                                              ? 'စကားဝှက် အောင်မြင်စွာ ပြောင်းလဲပြီးပါပြီ။'
                                              : 'Password changed successfully.',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: AppTheme.secondaryGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  String errDetail = isMm
                                      ? 'စကားဝှက် ပြောင်းလဲ၍ မရပါ။ ကျေးဇူးပြု၍ ပြန်လည်စစ်ဆေးပါ။'
                                      : 'Failed to change password. Please check your current password.';
                                  if (e is DioException && e.response?.data != null) {
                                    final data = e.response!.data;
                                    if (data is Map && data['detail'] != null) {
                                      errDetail = data['detail'].toString();
                                    }
                                  }
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMessage = errDetail;
                                  });
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                isMm ? 'စကားဝှက် အသစ်သိမ်းမည်' : 'UPDATE PASSWORD',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
