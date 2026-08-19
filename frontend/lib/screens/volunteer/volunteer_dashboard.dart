import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

import 'dart:convert';
import '../../services/notification_service.dart';

class VolunteerDashboard extends ConsumerStatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  ConsumerState<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends ConsumerState<VolunteerDashboard> {
  int _currentTabIndex = 0; // 0: Missions, 1: Services / Profile
  final List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _isDutyActive = true;
  Map<String, dynamic>? _profile;
  StreamSubscription? _wsSub;
  StreamSubscription? _locationSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _loadProfile();
    _listenForAlerts();
    _startLocationStreaming();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadAlerts());
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

  Future<void> _startLocationStreaming() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (_isDutyActive) {
        ApiService().updateVolunteerLocation(pos.latitude, pos.longitude);
      }
      _locationSub = LocationService.getLocationStream().listen((pos) {
        if (_isDutyActive) {
          ApiService().updateVolunteerLocation(pos.latitude, pos.longitude);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await ApiService().getVolunteerAlerts();
      if (mounted) {
        setState(() {
          _alerts.clear();
          _alerts.addAll(List<Map<String, dynamic>>.from(res.data));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForAlerts() {
    final auth = ref.read(authProvider.notifier);
    _wsSub = auth.ws.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event'];
      if (eventType == 'SOS_CREATED') {
        _loadAlerts();
        NotificationService().triggerUrgentHapticAlarm();
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🚨 CRITICAL SOS DISPATCH',
          body: 'Emergency mission assigned in your coverage area! Tap to navigate.',
          payload: json.encode(event),
        );
      } else if (eventType == 'VOLUNTEER_ACCEPTED' || eventType == 'EMERGENCY_ACCEPTED') {
        _loadAlerts();
      } else if (eventType == 'EMERGENCY_COMPLETED' || eventType == 'SOS_CANCELLED') {
        setState(() {
          _alerts.removeWhere((a) => a['emergency_id'] == event['emergency_id']);
        });
      }
    });
  }

  Future<void> _respond(String emergencyId, String action) async {
    try {
      await ApiService().respondToEmergency(emergencyId, action);
      if (mounted) {
        if (action == 'accept') {
          final myId = ref.read(authProvider).userId ?? '';
          const myName = 'You';
          setState(() {
            final idx = _alerts.indexWhere((a) => a['emergency_id'] == emergencyId);
            if (idx != -1) {
              _alerts[idx]['status'] = 'accepted';
              _alerts[idx]['assigned_volunteer_id'] = myId;
              _alerts[idx]['assigned_volunteer_name'] = myName;
            }
          });
          _loadAlerts();
          final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMm ? '✅ အရေးပေါ် အမှုတွဲကို လက်ခံပြီး တိုက်ရိုက် GPS တည်နေရာ စတင်မျှဝေပါပြီ' : '✅ Emergency Accepted — Streaming live location to victim!'),
              backgroundColor: AppTheme.primaryRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _alerts.removeWhere((a) => a['emergency_id'] == emergencyId);
          });
          final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMm ? 'အရေးပေါ် ခေါ်ဆိုမှုကို ပယ်ဖျက်လိုက်ပါသည်' : 'Emergency Rejected'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isMm ? 'အရေးပေါ် ခေါ်ဆိုမှု တုံ့ပြန်ရန် မအောင်မြင်ပါ' : 'Failed to respond to emergency alert')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final bgCol = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_run_rounded, color: AppTheme.primaryRed, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMm ? 'စေတနာ့ဝန်ထမ်း ကွပ်ကဲရေး' : 'Volunteer Console',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Text(
                    _currentTabIndex == 0
                        ? (isMm ? 'တိုက်ရိုက် အရေးပေါ် တာဝန်များ' : 'Live Emergency Missions')
                        : (isMm ? 'အကောင့်၊ ဘာသာစကားနှင့် ဆက်တင်များ' : 'Profile, Settings & Security'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildMissionsTab(isDark, isMm),
          _buildVolunteerServicesTab(isDark, isMm),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: borderCol, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.radar_outlined,
                  activeIcon: Icons.radar_rounded,
                  label: isMm ? 'တာဝန်များ' : 'Missions',
                  badgeCount: _alerts.isNotEmpty ? _alerts.length : null,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: isMm ? 'ဝန်ဆောင်မှု' : 'Services',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _currentTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.primaryRed;
    final inactiveColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount != null && badgeCount > 0,
                label: Text('$badgeCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: AppTheme.primaryRed,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionsTab(bool isDark, bool isMm) {
    final headerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dutyCardBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Column(
      children: [
        // ── Duty Status Banner Header ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: dutyCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDutyActive ? AppTheme.primaryRed : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isDutyActive ? AppTheme.primaryRed : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isDutyActive)
                        BoxShadow(
                          color: AppTheme.primaryRed.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isDutyActive
                            ? (isMm ? 'တာဝန်ထမ်းဆောင်ဆဲ (Active)' : 'ON DUTY (Active)')
                            : (isMm ? 'တာဝန်ပိတ်ထားသည် (Inactive)' : 'OFF DUTY (Inactive)'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _isDutyActive ? AppTheme.primaryRed : (isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isDutyActive
                            ? (isMm ? 'တိုက်ရိုက်ခေါ်ဆိုမှု ဖွင့်ထားသည်' : 'Live dispatch active')
                            : (isMm ? 'အသင့်အနေအထား' : 'Standby mode'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: _isDutyActive,
                    activeThumbColor: AppTheme.primaryRed,
                    activeTrackColor: AppTheme.primaryRed.withValues(alpha: 0.3),
                    onChanged: (val) => setState(() => _isDutyActive = val),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 64, color: isDark ? Colors.white30 : Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            isMm ? 'လက်ရှိ အရေးပေါ် ခေါ်ဆိုမှု မရှိပါ' : 'No emergency dispatch calls',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isMm ? 'အနီးနားရှိ အရေးပေါ် ခေါ်ဆိုမှုများကို စောင့်ကြည့်နေပါသည်...' : 'Monitoring for incoming emergency calls...',
                            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlerts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alerts.length,
                        itemBuilder: (_, i) => _AlertCard(
                          alert: _alerts[i],
                          currentUserId: ref.read(authProvider).userId ?? '',
                          onAccept: () =>
                              _respond(_alerts[i]['emergency_id'], 'accept'),
                          onReject: () =>
                              _respond(_alerts[i]['emergency_id'], 'reject'),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildVolunteerServicesTab(bool isDark, bool isMm) {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    final volName = _profile?['full_name'] ?? auth.email?.split('@').first ?? 'First Responder';
    final volPhone = _profile?['phone_number'] ?? '';
    final volNrc = _profile?['nrc_number'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Volunteer Profile Banner ─────────────────────────────
          Container(
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
                      (volName.isNotEmpty ? volName[0] : 'V').toUpperCase(),
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
                              volName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'VOLUNTEER',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        volPhone.isNotEmpty ? volPhone : (auth.email ?? ''),
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      if (volNrc.isNotEmpty)
                        Text(
                          'NRC: $volNrc',
                          style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Account & Security ──────────────────────────────────────
          Text(
            isMm ? 'အကောင့်နှင့် လုံခြုံရေး' : 'Account & Security',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardBg,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: isDark ? Colors.amber : Colors.amber.shade900, size: 22),
                  ),
                  title: Text(
                    isMm ? 'စကားဝှက် ပြောင်းလဲရန်' : 'Change Password',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  subtitle: Text(
                    isMm ? 'စကားဝှက်အသစ် သတ်မှတ်ပါ' : 'Set a new secure password',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: textSecondary.withValues(alpha: 0.5), size: 20),
                  onTap: () => context.push('/change-password'),
                ),
                Divider(height: 1, color: cardBorder),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.devices_rounded, color: Colors.blue, size: 22),
                  ),
                  title: Text(
                    isMm ? 'ချိတ်ဆက်ထားသော စက်ပစ္စည်းများ' : 'Logged-in Devices',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  subtitle: Text(
                    isMm ? 'ဝင်ရောက်ထားသော စက်များ စီမံခန့်ခွဲရန်' : 'Manage active login sessions',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: textSecondary.withValues(alpha: 0.5), size: 20),
                  onTap: () => context.push('/settings/devices'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── App Appearance & Theme ──────────────────────────────────
          Text(
            isMm ? 'အသွင်အပြင် (Theme Mode)' : 'Appearance & Theme',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardBg,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  secondary: const Icon(Icons.light_mode_outlined, color: Colors.amber),
                  title: Text(
                    isMm ? 'အလင်းမုဒ် (Light Mode)' : 'Light Mode',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                ),
                Divider(height: 1, color: cardBorder),
                RadioListTile<ThemeMode>(
                  secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigoAccent),
                  title: Text(
                    isMm ? 'အမှောင်မုဒ် (Dark Mode)' : 'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                ),
                Divider(height: 1, color: cardBorder),
                RadioListTile<ThemeMode>(
                  secondary: Icon(Icons.settings_brightness_outlined, color: textSecondary),
                  title: Text(
                    isMm ? 'စနစ်သုံး မုဒ် (System Default)' : 'System Default',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Language Preferences ────────────────────────────────────
          Text(
            isMm ? 'ဘာသာစကား (Language)' : 'Language Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardBg,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  secondary: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                  title: Text('English', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                  value: 'en',
                  groupValue: settings.locale.languageCode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setLocale(val);
                  },
                ),
                Divider(height: 1, color: cardBorder),
                RadioListTile<String>(
                  secondary: const Text('🇲🇲', style: TextStyle(fontSize: 22)),
                  title: Text('မြန်မာ (Myanmar)', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                  value: 'my',
                  groupValue: settings.locale.languageCode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setLocale(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Refresh Action ──────────────────────────────────────────
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cardBorder),
            ),
            tileColor: cardBg,
            leading: const Icon(Icons.refresh_rounded, color: AppTheme.primaryRed),
            title: Text(
              isMm ? 'ဒေတာများ ပြန်လည်ရယူရန်' : 'Refresh Missions & Profile',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              isMm ? 'အရေးပေါ် တာဝန်ဒေတာများကို အသစ်ရယူပါ' : 'Reload all assigned missions and responder profile',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            onTap: () {
              _loadAlerts();
              _loadProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isMm ? 'စေတနာ့ဝန်ထမ်း အချက်အလက်များ အသစ်ပြန်လည်ရယူပြီးပါပြီ' : 'Volunteer data refreshed'),
                  backgroundColor: AppTheme.secondaryGreen,
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Logout Button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isMm ? 'စေတနာ့ဝန်ထမ်း အကောင့်မှ ထွက်မည်' : 'SIGN OUT OF VOLUNTEER',
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _confirmVolunteerLogout(isMm),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _confirmVolunteerLogout(bool isMm) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isMm ? 'အကောင့်မှ ထွက်ခွာမည်လား?' : 'Log Out Volunteer?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isMm
              ? 'သင်သည် စေတနာ့ဝန်ထမ်း ကွပ်ကဲရေးစနစ်မှ ထွက်ခွာရန် သေချာပါသလား?'
              : 'Are you sure you want to end your first responder session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isMm ? 'မထွက်ပါ' : 'CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isMm ? 'ထွက်မည်' : 'LOG OUT'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/login');
    }
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final String currentUserId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _AlertCard({
    required this.alert,
    required this.currentUserId,
    required this.onAccept,
    required this.onReject,
  });

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userInfo = alert['user_info'] as Map<String, dynamic>? ?? {};
    final typeStr = (alert['type'] ?? 'emergency').toString().toUpperCase();
    final isFire = typeStr == 'FIRE';
    final isMedical = typeStr == 'MEDICAL';
    final phone = userInfo['phone_number'] ?? '';
    final isAccepted = alert['status'] == 'accepted';
    final isAssignedToMe = isAccepted &&
        alert['assigned_volunteer_id'] != null &&
        currentUserId.isNotEmpty &&
        alert['assigned_volunteer_id'].toString().trim().toLowerCase() == currentUserId.trim().toLowerCase();

    final cardColor = isFire
        ? const Color(0xFFEA580C)
        : (isMedical ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final iconData = isFire
        ? Icons.local_fire_department
        : (isMedical ? Icons.local_hospital : Icons.shield);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAccepted ? AppTheme.primaryRed : (isDark ? cardColor.withValues(alpha: 0.5) : cardColor.withValues(alpha: 0.3)),
          width: isAccepted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAccepted ? AppTheme.primaryRed : cardColor).withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: (isAccepted ? AppTheme.primaryRed : cardColor).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAccepted ? AppTheme.primaryRed : cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAccepted ? Icons.airport_shuttle : iconData,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '🚨 $typeStr CALL',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isAccepted ? AppTheme.primaryRed : cardColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isAccepted ? AppTheme.primaryRed : Colors.orange)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isAccepted ? 'ACTIVE RESCUE' : 'PENDING DISPATCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isAccepted ? AppTheme.primaryRed : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Victim Information (Name & Phone ONLY for Fire/Crime, Blood/Medical ONLY for Medical)
                _infoRow(Icons.person, 'Victim Name', userInfo['full_name'] ?? 'Unknown Victim', isDark: isDark),
                _infoRow(Icons.phone, 'Phone Contact', phone.isNotEmpty ? phone : 'Not Provided', isDark: isDark),

                // Medical details shown strictly ONLY for MEDICAL emergency calls
                if (isMedical) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(
                        Icons.bloodtype,
                        'Blood: ${userInfo['blood_type'] ?? 'Unknown'}',
                        Colors.red.shade700,
                        Colors.red.shade50,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        Icons.medical_information,
                        'Condition: ${userInfo['medical_conditions'] ?? 'None'}',
                        Colors.blue.shade700,
                        Colors.blue.shade50,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],

                // ── Map Navigation Button ─────────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final loc = alert['location'] as Map<String, dynamic>? ?? {};
                        final lat = (loc['lat'] as num?)?.toDouble() ?? 16.8661;
                        final lng = (loc['lng'] as num?)?.toDouble() ?? 96.1951;
                        context.push('/mission-map', extra: {
                          'lat': lat,
                          'lng': lng,
                          'title': '🚨 Emergency Target: ${userInfo['full_name'] ?? 'Victim'} ($typeStr)',
                          'returnRoute': '/volunteer-dashboard',
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.map_rounded, color: Color(0xFF38BDF8), size: 19),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'VIEW ROAD ROUTE ON MAP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.call, size: 18, color: AppTheme.primaryRed),
                            label: const Text('CALL', style: TextStyle(fontWeight: FontWeight.w800)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryRed,
                              side: const BorderSide(color: AppTheme.primaryRed),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => _makeCall(phone),
                          ),
                        ),
                      ),
                    if (isAccepted)
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAssignedToMe
                                ? const Color(0xFF00E676).withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAssignedToMe ? const Color(0xFF00C853) : Colors.amber.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isAssignedToMe ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                                color: isAssignedToMe ? const Color(0xFF00C853) : Colors.amber.shade900,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isAssignedToMe
                                        ? 'ACCEPTED BY YOU • EN ROUTE'
                                        : 'ACCEPTED BY ${alert['assigned_volunteer_name']?.toString().toUpperCase() ?? 'OTHER VOLUNTEER'}',
                                    style: TextStyle(
                                      color: isAssignedToMe ? const Color(0xFF00C853) : Colors.amber.shade900,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'ACCEPT & DISPATCH',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: onAccept,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: onReject,
                          child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white60 : AppTheme.subtleGrey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : AppTheme.subtleGrey),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color textColor, Color bgColor, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? textColor.withValues(alpha: 0.15) : bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }
}
