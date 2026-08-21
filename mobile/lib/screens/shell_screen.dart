import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/offline_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_sos_dialog.dart';
import 'sos/emergency_type_sheet.dart';

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sosCtrl;
  Timer? _countdownTicker;
  bool _sosHolding = false;
  bool _sosActivated = false;

  // Progressive 3-Tier Suspension State
  bool _isSuspended = false;
  int _remainingSuspensionSeconds = 0;
  int _suspensionTier = 1;
  String? _suspensionReason;

  @override
  void initState() {
    super.initState();
    _sosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_sosActivated) {
          _sosActivated = true;
          HapticFeedback.heavyImpact();
          _triggerEmergencyTypeSheet();
        }
      });

    // Countdown ticker for live Dynamic Island & Suspension countdown
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        if (_isSuspended && _remainingSuspensionSeconds > 0) {
          setState(() {
            _remainingSuspensionSeconds--;
            if (_remainingSuspensionSeconds <= 0) {
              _isSuspended = false; // Auto-reactivated!
            }
          });
        }
        final activeList = ref.read(emergencyProvider).value ?? [];
        if (activeList.isNotEmpty && !activeList.first.isAccepted) {
          setState(() {});
        }
      }
    });

    // Load active emergencies and suspension status when shell screen initializes
    Future.microtask(() {
      ref.read(emergencyProvider.notifier).loadActive();
      _checkSuspensionStatus();
    });

    // Listen to global WebSocket events (e.g. Family SOS, Account Suspension)
    final auth = ref.read(authProvider.notifier);
    auth.ws.events.listen((event) {
      if (!mounted) return;
      if (event['event'] == 'ACCOUNT_SUSPENDED') {
        setState(() {
          _isSuspended = true;
          _remainingSuspensionSeconds = (event['remaining_seconds'] as num?)?.toInt() ?? 86400;
          _suspensionTier = (event['suspension_tier'] as num?)?.toInt() ?? 1;
          _suspensionReason = event['suspension_reason'] ?? event['reason'];
        });
      } else if (event['event'] == 'ACCOUNT_UNSUSPENDED') {
        setState(() {
          _isSuspended = false;
          _remainingSuspensionSeconds = 0;
          _suspensionReason = null;
        });
      } else if (event['event'] == 'FAMILY_SOS_ALERT') {
        final senderName = event['sender_name'] ?? 'Family Member';
        final rel = event['relationship'] ?? 'Family';
        final type = (event['emergency_type'] ?? 'EMERGENCY').toString().toUpperCase();
        
        // Trigger system notification with loud emergency siren and payload
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🚨 $type SOS from $senderName!',
          body: 'Your $rel has activated an SOS emergency alert.',
          payload: json.encode(event),
        );

        // Show global alert
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.all(16),
            backgroundColor: AppTheme.primaryRed,
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
            content: Text(
              '🚨 $type SOS from $senderName ($rel)!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  // Navigate directly to map with coordinates
                  final loc = event['location'];
                  if (loc != null) {
                    context.go('/map', extra: {
                      'lat': (loc['lat'] as num).toDouble(),
                      'lng': (loc['lng'] as num).toDouble(),
                    });
                  } else {
                    context.go('/family-alerts');
                  }
                },
                child: const Text('VIEW ON MAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      } else if (event['event'] == 'SOS_ASSIGNED') {
        ref.read(emergencyProvider.notifier).loadActive();
      } else if (event['event'] == 'VOLUNTEER_ACCEPTED' || event['event'] == 'EMERGENCY_ACCEPTED') {
        ref.read(emergencyProvider.notifier).markAccepted(
          event['emergency_id'] ?? '',
          assignedOrgId: event['assigned_org_id'],
        );
        ref.read(emergencyProvider.notifier).loadActive();
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '✅ SOS Accepted!',
          body: 'A rescue team has accepted your distress call and is en route.',
        );
      } else if (event['event'] == 'EMERGENCY_COMPLETED' || event['event'] == 'SOS_CANCELLED') {
        ref.read(emergencyProvider.notifier).loadActive();
      }
    });
  }

  Future<void> _checkSuspensionStatus() async {
    try {
      final res = await ApiService().getProfile();
      if (mounted && res.data != null) {
        final data = res.data;
        if (data['is_suspended'] == true) {
          setState(() {
            _isSuspended = true;
            _remainingSuspensionSeconds = (data['remaining_suspension_seconds'] as num?)?.toInt() ?? 0;
            _suspensionTier = (data['suspension_count'] as num?)?.toInt() ?? 1;
            _suspensionReason = data['suspension_reason'];
          });
        }
      }
    } catch (_) {}
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (days > 0) {
      return '$days d ${hours.toString().padLeft(2, '0')} h ${minutes.toString().padLeft(2, '0')} m';
    }
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _sosCtrl.dispose();
    super.dispose();
  }

  void _triggerEmergencyTypeSheet() {
    if (_isSuspended) {
      final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
      final tierStr = _suspensionTier == 1
          ? (isMm ? '၁ ရက် ပိတ်ပင်ထားပါသည်' : '1-Day Suspension')
          : (_suspensionTier == 2
              ? (isMm ? '၁၀ ရက် ပိတ်ပင်ထားပါသည်' : '10-Days Suspension')
              : (isMm ? 'နှစ်ပေါင်း ၁၀၀ ပိတ်ပင်ထားပါသည်' : '100-Years Ban'));
      final timerStr = _formatDuration(_remainingSuspensionSeconds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryRed,
          content: Text(
            '⚠️ $tierStr: ${_suspensionTier >= 3 ? (isMm ? "အက်ဒမင်သို့ ဆက်သွယ်ပါ" : "Contact Admin") : "${isMm ? "ပြန်ဖွင့်ရန်ကျန်ချိန်" : "Re-activating in"} $timerStr"}\n${_suspensionReason ?? ""}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmergencyTypeSheet(
        onTypeSelected: (type) async {
          Navigator.pop(context);
          double lat = 16.8661;
          double lng = 96.1951;
          try {
            final pos = await LocationService.getCurrentLocation();
            lat = pos.latitude;
            lng = pos.longitude;
          } catch (_) {}

          final isOnline = await OfflineService().checkInternet();
          if (!isOnline) {
            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (ctx) => OfflineSOSDialog(
                  emergencyType: type,
                  lat: lat,
                  lng: lng,
                ),
              ),
            );
            return;
          }

          final notifier = ref.read(emergencyProvider.notifier);
          final emergencyId = await notifier.createSOS(type, lat, lng);

          if (!mounted) return;

          if (emergencyId != null) {
            context.go('/map');
          } else {
            // Failed due to timeout or network -> Offer Offline fallback
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (ctx) => OfflineSOSDialog(
                  emergencyType: type,
                  lat: lat,
                  lng: lng,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showLegalLawsSheet(BuildContext context, bool isMm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final textMuted = isDark ? Colors.white70 : Colors.black54;

        final laws = [
          {
            'section': isMm ? 'ရာဇသတ်ကြီး ဥပဒေပုဒ်မ ၁၈၂' : 'Myanmar Penal Code § 182',
            'title': isMm ? 'မမှန်သတင်း ပေးပို့မှု' : 'False Information to Public Servants',
            'desc': isMm
                ? 'ပြည်သူ့ဝန်ထမ်း (သို့မဟုတ်) အရေးပေါ်ကယ်ဆယ်ရေးတပ်ဖွဲ့ထံသို့ မမှန်ကန်ကြောင်းသိလျက်နှင့် သတင်းမှားပေးပို့ခြင်း။'
                : 'Giving false information to any public servant or rescue dispatcher with intent to cause injury or annoyance.',
            'penalty': isMm ? 'ထောင်ဒဏ် (၆) လ သို့မဟုတ် ငွေဒဏ် (သို့မဟုတ်) ဒဏ်နှစ်ရပ်လုံး' : 'Imprisonment up to 6 months, or fine, or both',
            'icon': Icons.gavel_rounded,
            'color': Colors.redAccent,
          },
          {
            'section': isMm ? 'ရာဇသတ်ကြီး ဥပဒေပုဒ်မ ၅၀၅(ခ)' : 'Myanmar Penal Code § 505(b)',
            'title': isMm ? 'ပြည်သူ့အေးချမ်းမှုကို ထိခိုက်စေသော သတင်းမှား' : 'Public Alarm & Emergency Disruption',
            'desc': isMm
                ? 'ပြည်သူလူထုအတွင်း ထိတ်လန့်တကြားဖြစ်စေရန် သို့မဟုတ် အရေးပေါ်လိုင်းများအား အနှောင့်အယှက်ဖြစ်စေရန် ကြံရွယ်ပြုလုပ်မှု။'
                : 'Making or circulating rumors/alarms causing fear or public panic, disrupting critical emergency response networks.',
            'penalty': isMm ? 'ထောင်ဒဏ် (၂) နှစ်အထိ သို့မဟုတ် ငွေဒဏ်' : 'Imprisonment up to 2 years, or fine, or both',
            'icon': Icons.warning_amber_rounded,
            'color': Colors.amber,
          },
          {
            'section': isMm ? 'ဆက်သွယ်ရေး ဥပဒေပုဒ်မ ၆၆(ဃ)' : 'Telecommunications Law § 66(d)',
            'title': isMm ? 'အရေးပေါ် ဆက်သွယ်ရေးလိုင်း နှောင့်ယှက်မှု' : 'Misuse of Emergency Telecom Network',
            'desc': isMm
                ? 'အရေးပေါ် ဆက်သွယ်ရေးကွန်ရက်ကို အသုံးပြု၍ နှောင့်ယှက်ခြင်း၊ ခြိမ်းခြောက်ခြင်း၊ အတုအယောင် သတင်းမှားလွှင့်ခြင်း။'
                : 'Extorting, coercing, restraining wrongfully, defaming, or creating false distress signals on telecommunications network.',
            'penalty': isMm ? 'ထောင်ဒဏ် (၂) နှစ်အထိ သို့မဟုတ် ငွေဒဏ်' : 'Imprisonment up to 2 years, or fine, or both',
            'icon': Icons.cell_tower,
            'color': Colors.blueAccent,
          },
          {
            'section': isMm ? 'သဘာဝဘေးအန္တရာယ် စီမံခန့်ခွဲမှု ဥပဒေပုဒ်မ ၃၀' : 'Disaster Management Law § 30',
            'title': isMm ? 'ကယ်ဆယ်ရေးလုပ်ငန်း အဟန့်အတား' : 'Obstruction of Emergency Relief',
            'desc': isMm
                ? 'အရေးပေါ် ကယ်ဆယ်ရေးလုပ်ငန်းများကို အဟန့်အတားဖြစ်စေသော မဟုတ်မမှန် သတင်းထုတ်လွှင့်မှုများ ပြုလုပ်ခြင်း။'
                : 'Creating hoax disaster alarms that obstruct active search, rescue, medical aid, or emergency supply distribution.',
            'penalty': isMm ? 'ထောင်ဒဏ် (၁) နှစ်အထိ သို့မဟုတ် ငွေဒဏ်' : 'Imprisonment up to 1 year, or fine, or both',
            'icon': Icons.shield_rounded,
            'color': Colors.orangeAccent,
          },
        ];

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryRed, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm ? 'အရေးပေါ်လိုင်း အလွဲသုံးစားမှုဆိုင်ရာ ဥပဒေများ' : 'Emergency Anti-Hoax Laws & Penalties',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                          Text(
                            isMm ? 'မြန်မာနိုင်ငံ တည်ဆဲဥပဒေ ပြဋ္ဌာန်းချက်များ' : 'Applicable Myanmar Legal Regulations',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: textMuted,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Laws List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: laws.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (ctx, idx) {
                    final item = laws[idx];
                    final color = item['color'] as Color;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(item['icon'] as IconData, color: color, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item['section'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.gavel, size: 14, color: AppTheme.primaryRed),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${isMm ? "ပြစ်ဒဏ်" : "Penalty"}: ${item['penalty']}',
                                    style: const TextStyle(
                                      color: AppTheme.primaryRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Dismiss
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      isMm ? 'နားလည်ပါသည် (ပိတ်မည်)' : 'I Understand & Agree',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── FULL-SCREEN SUSPENSION & BAN LOCKOUT VIEW ─────────────────────────────
  Widget _buildFullScreenBanLockout(BuildContext context, bool isMm) {
    final timerStr = _formatDuration(_remainingSuspensionSeconds);

    final title = _suspensionTier == 1
        ? (isMm ? 'အကောင့် (၁) ရက် ယာယီဆိုင်းငံ့ထားပါသည်' : '1-Day Suspension (1st Offense)')
        : (_suspensionTier == 2
            ? (isMm ? 'အကောင့် (၁၀) ရက် ဆိုင်းငံ့ထားပါသည်' : '10-Days Suspension (2nd Offense)')
            : (isMm ? 'အကောင့်အား (၁၀၀) နှစ် ပိတ်ပင်ထားပါသည်' : 'Permanent Ban (100 Years)'));

    final subtext = _suspensionTier >= 3
        ? (isMm
            ? 'အရေးပေါ် ကယ်ဆယ်ရေးလိုင်းများအား ထပ်တလဲလဲ အလွဲသုံးစားပြုလုပ်ခဲ့သောကြောင့် အပြီးတိုင် ပိတ်ပင်ထားပါသည်။ စီမံခန့်ခွဲသူ (Admin) ထံသို့ ဆက်သွယ်ပါ။'
            : 'Permanently banned due to repeated false alarm violations. Please contact System Administrator.')
        : (isMm
            ? '၂၄ နာရီအတွင်း အရေးပေါ် SOS အချက်ပြမှုများအား အကြိမ်ကြိမ် ပယ်ဖျက်ခဲ့ခြင်းကြောင့် ဖြစ်ပါသည်။ စစ်မှန်သော ကယ်ဆယ်ရေးလုပ်ငန်းများ မနှောင့်နှေးစေရန် လုပ်ဆောင်ချက်အားလုံးကို ဆိုင်းငံ့ထားပါသည်။'
            : 'Suspended due to multiple emergency SOS cancellations within 24 hours. All operations are locked to protect emergency dispatch lines.');

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Glowing Shield Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E1010),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.gavel_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Suspension Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Text(
                      isMm ? 'လုပ်ဆောင်ချက်များ ပိတ်ပင်ထားပါသည်' : 'ACCOUNT ACCESS RESTRICTED',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 20),

              // Live Digital Countdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B1414), Color(0xFF110808)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isMm ? 'ပြန်လည်ဖွင့်လှစ်ရန် ကျန်ရှိချိန်' : 'REMAINING SUSPENSION TIME',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _suspensionTier >= 3 ? (isMm ? "အပြီးတိုင် ပိတ်ပင်ထားသည်" : "100 YEARS BAN") : timerStr,
                      style: TextStyle(
                        color: _suspensionTier >= 3 ? Colors.redAccent : const Color(0xFFFF5252),
                        fontSize: _suspensionTier >= 3 ? 20 : 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _suspensionTier >= 3
                          ? (isMm ? "စီမံခန့်ခွဲသူမှသာ ဖွင့်ပေးနိုင်ပါမည်" : "Requires Administrator Un-ban")
                          : (isMm ? "သတ်မှတ်ချိန်ပြည့်ပါက အလိုအလျောက် ပွင့်ပါမည်" : "Auto-reactivates when timer reaches 0"),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Reason & Description Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E131F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isMm ? 'ပိတ်ပင်ရသည့် အကြောင်းရင်း' : 'Suspension Reason & Notice',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _suspensionReason ?? subtext,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action 1: View Legal Laws & Penalties Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _showLegalLawsSheet(context, isMm),
                  icon: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                  label: Text(
                    isMm ? 'ဥပဒေနှင့် ပြစ်ဒဏ်များ ကြည့်ရန်' : 'VIEW LEGAL LAWS & PENALTIES',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action 2: Check Status / Re-check
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _checkSuspensionStatus();
                    if (!mounted) return;
                    if (!_isSuspended) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isMm ? 'အကောင့်ပြန်လည် အသုံးပြုနိုင်ပါပြီ!' : 'Account reactivated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isMm ? 'ဆိုင်းငံ့ကာလ ကျန်ရှိနေသေးပါသည်' : 'Account is still suspended.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                  label: Text(
                    isMm ? 'အကောင့်အခြေအနေ ပြန်စစ်မည်' : 'RE-CHECK STATUS',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action 3: Logout
              TextButton.icon(
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) router.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white54),
                label: Text(
                  isMm ? 'အကောင့်မှ ထွက်မည်' : 'Log Out / Switch Account',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(settingsProvider).locale.languageCode;
    final isMm = locale == 'my';

    // ── STRICT LOCKOUT: If user is banned/suspended, render full-screen lockout ──
    if (_isSuspended) {
      return _buildFullScreenBanLockout(context, isMm);
    }

    final activeEmergencies = ref.watch(emergencyProvider).value ?? [];
    final activeEmergency =
        activeEmergencies.isNotEmpty ? activeEmergencies.first : null;

    // Calculate auto-reroute remaining countdown (180s = 3 minutes)
    int remainingRerouteSeconds = 180;
    if (activeEmergency != null && !activeEmergency.isAccepted) {
      final elapsed = DateTime.now().toUtc().difference(activeEmergency.createdAt.toUtc()).inSeconds;
      remainingRerouteSeconds = (180 - (elapsed % 180)).clamp(0, 180);
    }
    final minStr = (remainingRerouteSeconds ~/ 60).toString().padLeft(2, '0');
    final secStr = (remainingRerouteSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Column(
            children: [
              const OfflineBanner(),
              Expanded(child: widget.child),
            ],
          ),

          if (activeEmergency != null || _sosHolding)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              child: AnimatedBuilder(
                animation: _sosCtrl,
                builder: (context, _) {
                  final isAccepted = activeEmergency?.isAccepted == true;
                  final statusColor = isAccepted ? AppTheme.secondaryGreen : AppTheme.primaryRed;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black, // Sleek black dynamic island look
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: activeEmergency != null
                        ? Row(
                            children: [
                              // Pulsing indicator dot
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAccepted
                                          ? (isMm ? 'SOS လက်ခံထားပါသည်' : 'SOS ACCEPTED')
                                          : (isMm ? 'SOS အချက်ပြနေပါသည်' : 'SOS PENDING'),
                                      style: TextStyle(
                                        color: isAccepted ? const Color(0xFF00E676) : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isAccepted
                                          ? (isMm ? 'ကယ်ဆယ်ရေးအဖွဲ့ လာရောက်နေပါသည် • အကူအညီ လမ်းခရီးတွင်' : 'Rescue Team En Route • Help on the way')
                                          : (isMm
                                              ? 'အဖွဲ့သစ်သို့ ပြန်ပြောင်းရန်: $minStr:$secStr • အဖွဲ့ရှာဖွေဆဲ...'
                                              : 'Auto-reroute in: $minStr:$secStr • Alerting teams...'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Cancel button (only when pending / not yet accepted)
                              if (!isAccepted)
                                GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(emergencyProvider.notifier)
                                        .cancelEmergency(activeEmergency.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isMm ? 'ပယ်ဖျက်မည်' : 'CANCEL',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock_outline, size: 12, color: Color(0xFF00E676)),
                                      const SizedBox(width: 4),
                                      Text(
                                        isMm ? 'လက်ခံပြီး' : 'ACCEPTED',
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Hold to activate SOS... ${(3 - (_sosCtrl.value * 3)).ceil().clamp(1, 3)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
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
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: 68,
              margin: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
              // 1. Home
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: isMm ? 'ပင်မ' : 'Home',
                isActive: _currentIndex(context) == 0,
                onTap: () => context.go('/home'),
              ),

              // 2. Rescue Orgs
              _NavItem(
                icon: Icons.business_outlined,
                activeIcon: Icons.business,
                label: isMm ? 'အဖွဲ့များ' : 'Orgs',
                isActive: _currentIndex(context) == 1,
                onTap: () => context.go('/organizations'),
              ),

              // 3. Family Group
              _NavItem(
                icon: Icons.family_restroom_outlined,
                activeIcon: Icons.family_restroom,
                label: isMm ? 'မိသားစု' : 'Family',
                isActive: _currentIndex(context) == 2,
                onTap: () => context.go('/family'),
              ),

              // 4. CENTER EMERGENCY SOS BUTTON (HOLD 3 SECONDS)
              GestureDetector(
                onLongPressStart: (_) {
                  setState(() {
                    _sosHolding = true;
                    _sosActivated = false;
                  });
                  HapticFeedback.lightImpact();
                  _sosCtrl.forward(from: 0);
                },
                onLongPressEnd: (_) {
                  setState(() => _sosHolding = false);
                  _sosCtrl.reset();
                  _sosActivated = false;
                },
                onLongPressCancel: () {
                  setState(() => _sosHolding = false);
                  _sosCtrl.reset();
                  _sosActivated = false;
                },
                child: AnimatedBuilder(
                  animation: _sosCtrl,
                  builder: (context, _) {
                    return Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF5252),
                            AppTheme.primaryRed,
                            Color(0xFFB71C1C),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryRed.withValues(
                              alpha: 0.45 + _sosCtrl.value * 0.3,
                            ),
                            blurRadius: 12 + _sosCtrl.value * 14,
                            spreadRadius: 2 + _sosCtrl.value * 3,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_sosHolding && _sosCtrl.value > 0)
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                value: _sosCtrl.value,
                                strokeWidth: 3,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                              ),
                            ),
                          const Icon(
                            Icons.sos_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 5. Family Emergency Alerts
              _NavItem(
                icon: Icons.notifications_none_outlined,
                activeIcon: Icons.notifications_active,
                label: isMm ? 'သတိပေးချက်' : 'Alerts',
                isActive: _currentIndex(context) == 3,
                onTap: () => context.go('/family-alerts'),
              ),

              // 6. Map
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: isMm ? 'မြေပုံ' : 'Map',
                isActive: _currentIndex(context) == 4,
                onTap: () => context.go('/map'),
              ),

              // 7. More Hub
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: isMm ? 'ပိုမို' : 'More',
                isActive: _currentIndex(context) == 5,
                onTap: () => context.go('/more'),
              ),
            ],
          ),
        );
      },
    ),
  ),
);
}

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/organizations')) return 1;
    if (location.startsWith('/family-alerts')) return 3;
    if (location.startsWith('/family')) return 2;
    if (location.startsWith('/map')) return 4;
    if (location.startsWith('/more') || location.startsWith('/settings')) return 5;
    return 0;
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.white60 : AppTheme.subtleGrey;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryRed.withValues(alpha: isDark ? 0.2 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.primaryRed : unselectedColor,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppTheme.primaryRed : unselectedColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
