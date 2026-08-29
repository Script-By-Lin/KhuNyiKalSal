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
import '../services/disaster_monitor_service.dart';
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
  int _tickerCounter = 0;

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

    // Countdown ticker for live Dynamic Island, Suspension countdown & fast real-time status sync
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _tickerCounter++;
        // Fast periodic sync every 3 seconds to immediately detect admin ban/unban in real-time
        if (_tickerCounter % 3 == 0) {
          _checkSuspensionStatus();
        }

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
      DisasterMonitorService().startMonitoring();
    });

    // Listen to global WebSocket events (e.g. Family SOS, Account Suspension, Blood, Disasters)
    final auth = ref.read(authProvider.notifier);
    auth.ws.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event']?.toString() ?? '';

      if (eventType == 'ACCOUNT_SUSPENDED') {
        setState(() {
          _isSuspended = true;
          _remainingSuspensionSeconds = (event['remaining_seconds'] as num?)?.toInt() ?? 86400;
          _suspensionTier = (event['suspension_tier'] as num?)?.toInt() ?? 1;
          _suspensionReason = event['suspension_reason'] ?? event['reason'];
        });
        _checkSuspensionStatus();
      } else if (eventType == 'ACCOUNT_UNSUSPENDED') {
        setState(() {
          _isSuspended = false;
          _remainingSuspensionSeconds = 0;
          _suspensionReason = null;
        });
        _checkSuspensionStatus();
      } else if (eventType == 'FAMILY_SOS_ALERT') {
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

        // Show global alert banner
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
                      'title': '🚨 $type SOS from $senderName ($rel)',
                      'returnRoute': '/family-alerts',
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
      } else if (eventType == 'NEW_BLOOD_SUPPLY_REQUEST') {
        final bType = event['blood_type'] ?? 'Blood';
        final units = event['units'] ?? 1;
        final hospital = event['hospital_name'] ?? 'Hospital';
        final isMm = ref.read(settingsProvider).locale.languageCode == 'my';

        NotificationService().showBloodNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🩸 Urgent $bType Blood Request ($units Units)!',
          body: 'Patient in critical need at $hospital. Tap to respond or pledge.',
          payload: json.encode({'event': 'NEW_BLOOD_SUPPLY_REQUEST', 'route': '/blood-donation'}),
        );

        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.all(14),
            backgroundColor: const Color(0xFFC2185B),
            leading: const Icon(Icons.water_drop, color: Colors.white, size: 28),
            content: Text(
              isMm
                  ? '🩸 အရေးပေါ် သွေးလိုအပ်ချက် - $bType ($units ယူနစ်)\nနေရာ - $hospital'
                  : '🩸 Urgent Blood Supply: $bType ($units Units) at $hospital',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  context.push('/blood-donation');
                },
                child: const Text('VIEW REQUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      } else if (eventType == 'BLOOD_REQUEST_ACCEPTED') {
        final orgName = event['org_name'] ?? 'Rescue Medical Org';
        final location = event['pickup_location_message'] ?? event['appointment_location'] ?? 'Medical Center';
        final isMm = ref.read(settingsProvider).locale.languageCode == 'my';

        NotificationService().showBloodNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '✅ Blood Request Accepted by $orgName!',
          body: 'Pickup Location: $location',
          payload: json.encode({'event': 'BLOOD_REQUEST_ACCEPTED', 'route': '/blood-donation'}),
        );

        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.all(14),
            backgroundColor: const Color(0xFF2E7D32),
            leading: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
            content: Text(
              isMm
                  ? '✅ သွေးတောင်းခံမှုကို $orgName မှ လက်ခံဆောင်ရွက်ပေးပါပြီ!\nယူဆောင်ရမည့်နေရာ - $location'
                  : '✅ Blood Request Accepted by $orgName!\nPickup: $location',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  context.push('/blood-donation');
                },
                child: const Text('DETAILS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      } else if (eventType == 'NEW_ANNOUNCEMENT') {
        final title = event['title'] ?? 'Official Bulletin';
        final content = event['content'] ?? '';
        final isPinned = event['is_pinned'] == true;
        final isMm = ref.read(settingsProvider).locale.languageCode == 'my';

        NotificationService().showAnnouncementNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '${isPinned ? "🚨 [URGENT] " : "📢 "} $title',
          body: content,
          isPinned: isPinned,
          payload: json.encode({'type': 'ANNOUNCEMENT', 'route': '/announcements'}),
        );

        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.all(14),
            backgroundColor: isPinned ? AppTheme.primaryRed : const Color(0xFF1E3A8A),
            leading: Icon(
              isPinned ? Icons.warning_amber_rounded : Icons.campaign_rounded,
              color: Colors.white,
              size: 28,
            ),
            content: Text(
              '${isPinned ? "🚨 " : "📢 "}$title\n$content',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  context.push('/announcements');
                },
                child: Text(
                  isMm ? 'ဖတ်ရှုရန်' : 'READ',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      } else if (eventType == 'EPHEMERAL_BROADCAST') {
        final category = event['category'] ?? 'DAILY_QUOTE';
        final isDailyQuote = category == 'DAILY_QUOTE';
        final isMissingPerson = category == 'MISSING_PERSON';
        final title = isDailyQuote ? 'Khu Nyi Kal Sal' : (event['title'] ?? 'Khu Nyi Kal Sal');
        final message = event['message'] ?? '';
        final isMm = ref.read(settingsProvider).locale.languageCode == 'my';

        NotificationService().showEphemeralBroadcastNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: isDailyQuote ? 'Khu Nyi Kal Sal' : (isMissingPerson ? '🔍 [MISSING PERSON] $title' : title),
          body: message,
          category: category,
          payload: json.encode({'type': 'EPHEMERAL_BROADCAST', 'category': category}),
        );

        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            padding: const EdgeInsets.all(14),
            backgroundColor: isMissingPerson ? const Color(0xFFC2410C) : const Color(0xFF4338CA),
            leading: Icon(
              isMissingPerson ? Icons.person_search_rounded : Icons.format_quote_rounded,
              color: Colors.white,
              size: 28,
            ),
            content: Text(
              isDailyQuote ? 'Khu Nyi Kal Sal\n$message' : (isMissingPerson ? '🔍 $title\n$message' : '$title\n$message'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: Text(isMm ? 'သိရှိပါပြီ' : 'GOT IT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else if (eventType == 'NEW_DISASTER_ALERT') {
        DisasterMonitorService().triggerManualCheck();
      } else if (eventType == 'SOS_ASSIGNED') {
        ref.read(emergencyProvider.notifier).loadActive();
      } else if (eventType == 'VOLUNTEER_ACCEPTED' || eventType == 'EMERGENCY_ACCEPTED') {
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
      } else if (eventType == 'EMERGENCY_COMPLETED' || eventType == 'SOS_CANCELLED') {
        ref.read(emergencyProvider.notifier).loadActive();
      }
    });
  }

  Future<void> _checkSuspensionStatus() async {
    try {
      final res = await ApiService().getProfile();
      if (mounted && res.data != null) {
        final data = res.data;
        final bool isSusp = data['is_suspended'] == true;
        if (isSusp) {
          final rem = (data['remaining_suspension_seconds'] as num?)?.toInt() ?? 0;
          final tier = (data['suspension_count'] as num?)?.toInt() ?? 1;
          final reason = data['suspension_reason'] as String?;
          if (!_isSuspended || _remainingSuspensionSeconds != rem || _suspensionReason != reason) {
            setState(() {
              _isSuspended = true;
              _remainingSuspensionSeconds = rem;
              _suspensionTier = tier;
              _suspensionReason = reason;
            });
          }
        } else {
          if (_isSuspended) {
            setState(() {
              _isSuspended = false;
              _remainingSuspensionSeconds = 0;
              _suspensionReason = null;
            });
          }
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
    DisasterMonitorService().stopMonitoring();
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
          final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
          final messenger = ScaffoldMessenger.of(context);
          final router = GoRouter.of(context);
          final notifier = ref.read(emergencyProvider.notifier);

          Navigator.pop(context);
          double lat = 16.8661;
          double lng = 96.1951;
          try {
            final pos = await LocationService.getCurrentLocation();
            lat = pos.latitude;
            lng = pos.longitude;
          } catch (_) {}

          final emergencyId = await notifier.createSOS(type, lat, lng);

          if (!mounted) return;

          if (emergencyId != null) {
            router.go('/map');
          } else {
            // Check if it was a true network connection failure vs API server response
            if (notifier.isLastNetworkError) {
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
            } else {
              final errorMsg = notifier.lastError ?? (isMm ? 'SOS ပေးပို့ရန် မအောင်မြင်ပါ' : 'Failed to trigger SOS');
              messenger.showSnackBar(
                SnackBar(
                  content: Text(errorMsg, style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.primaryRed,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
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
        final laws = [
          {
            'section': 'ရာဇသတ်ကြီး ဥပဒေပုဒ်မ ၁၈၂',
            'title': 'မမှန်သတင်း ပေးပို့မှု',
            'desc': 'ပြည်သူ့ဝန်ထမ်း (သို့မဟုတ်) အရေးပေါ်ကယ်ဆယ်ရေးတပ်ဖွဲ့ထံသို့ မမှန်ကန်ကြောင်းသိလျက်နှင့် သတင်းမှားပေးပို့ခြင်း။',
            'penalty': 'ထောင်ဒဏ် (၆) လ သို့မဟုတ် ငွေဒဏ် (သို့မဟုတ်) ဒဏ်နှစ်ရပ်လုံး',
            'icon': Icons.gavel_rounded,
            'color': const Color(0xFFDC2626),
          },
          {
            'section': 'ရာဇသတ်ကြီး ဥပဒေပုဒ်မ ၅၀၅(ခ)',
            'title': 'ပြည်သူ့အေးချမ်းမှုကို ထိခိုက်စေသော သတင်းမှား',
            'desc': 'ပြည်သူလူထုအတွင်း ထိတ်လန့်တကြားဖြစ်စေရန် သို့မဟုတ် အရေးပေါ်လိုင်းများအား အနှောင့်အယှက်ဖြစ်စေရန် ကြံရွယ်ပြုလုပ်မှု။',
            'penalty': 'ထောင်ဒဏ် (၂) နှစ်အထိ သို့မဟုတ် ငွေဒဏ်',
            'icon': Icons.warning_amber_rounded,
            'color': const Color(0xFFD97706),
          },
          {
            'section': 'ဆက်သွယ်ရေး ဥပဒေပုဒ်မ ၆၆(ဃ)',
            'title': 'အရေးပေါ် ဆက်သွယ်ရေးလိုင်း နှောင့်ယှက်မှု',
            'desc': 'အရေးပေါ် ဆက်သွယ်ရေးကွန်ရက်ကို အသုံးပြု၍ နှောင့်ယှက်ခြင်း၊ ခြိမ်းခြောက်ခြင်း၊ အတုအယောင် သတင်းမှားလွှင့်ခြင်း။',
            'penalty': 'ထောင်ဒဏ် (၂) နှစ်အထိ သို့မဟုတ် ငွေဒဏ်',
            'icon': Icons.cell_tower,
            'color': const Color(0xFF2563EB),
          },
          {
            'section': 'သဘာဝဘေးအန္တရာယ် စီမံခန့်ခွဲမှု ဥပဒေပုဒ်မ ၃၀',
            'title': 'ကယ်ဆယ်ရေးလုပ်ငန်း အဟန့်အတား',
            'desc': 'အရေးပေါ် ကယ်ဆယ်ရေးလုပ်ငန်းများကို အဟန့်အတားဖြစ်စေသော မဟုတ်မမှန် သတင်းထုတ်လွှင့်မှုများ ပြုလုပ်ခြင်း။',
            'penalty': 'ထောင်ဒဏ် (၁) နှစ်အထိ သို့မဟုတ် ငွေဒဏ်',
            'icon': Icons.shield_rounded,
            'color': const Color(0xFFEA580C),
          },
        ];

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
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
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFFDC2626), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'အရေးပေါ်လိုင်း အလွဲသုံးစားမှုဆိုင်ရာ ဥပဒေများ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'မြန်မာနိုင်ငံ တည်ဆဲဥပဒေ ပြဋ္ဌာန်းချက်များနှင့် ပြစ်ဒဏ်များ',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: const Color(0xFF64748B),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Laws List (Flat clean full-screen style)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: laws.length,
                  separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final item = laws[idx];
                    final color = item['color'] as Color;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(item['icon'] as IconData, color: color, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['section'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['desc'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ပြစ်ဒဏ် - ',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item['penalty'] as String,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom Dismiss
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'နားလည်ပါသည် (ပိတ်မည်)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  // ── FULL-SCREEN SUSPENSION & BAN LOCKOUT VIEW (FLAT CLEAN FULL-SCREEN, NO CARDS) ──
  Widget _buildFullScreenBanLockout(BuildContext context, bool isMm) {
    final timerStr = _formatDuration(_remainingSuspensionSeconds);

    // Accurately determine tier from remaining seconds or explicit suspension tier
    final bool is100Years = _suspensionTier >= 3 || _remainingSuspensionSeconds > 30 * 86400;
    final bool is10Days = !is100Years && (_suspensionTier == 2 || _remainingSuspensionSeconds > 86400);

    final title = is100Years
        ? 'အကောင့်အား (၁၀၀) နှစ် အပြီးတိုင် ပိတ်ပင်ထားပါသည်'
        : (is10Days
            ? 'အကောင့်အား (၁၀) ရက် ဆိုင်းငံ့ထားပါသည်'
            : 'အကောင့်အား (၁) ရက် ယာယီဆိုင်းငံ့ထားပါသည်');

    final tierSubtitle = is100Years
        ? 'အဆင့် ၃ ပြစ်ဒဏ် (Permanent Ban)'
        : (is10Days ? 'အဆင့် ၂ ပြစ်ဒဏ် (Tier 2 - 10 Days)' : 'အဆင့် ၁ ပြစ်ဒဏ် (Tier 1 - 24 Hours)');

    final subtext = is100Years
        ? 'အရေးပေါ် ကယ်ဆယ်ရေးလိုင်းများအား ထပ်တလဲလဲ အလွဲသုံးစားပြုလုပ်ခဲ့သောကြောင့် အပြီးတိုင် ပိတ်ပင်ထားပါသည်။ စီမံခန့်ခွဲသူ (Admin) ထံသို့ ဆက်သွယ်ပါ။'
        : '၂၄ နာရီအတွင်း အရေးပေါ် SOS အချက်ပြမှုများအား အကြိမ်ကြိမ် ပယ်ဖျက်ခဲ့ခြင်းကြောင့် ဖြစ်ပါသည်။ စစ်မှန်သော ကယ်ဆယ်ရေးလုပ်ငန်းများ မနှောင့်နှေးစေရန် လုပ်ဆောင်ချက်အားလုံးကို ဆိုင်းငံ့ထားပါသည်။';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // Top Emblem
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFEE2E2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.gavel_rounded,
                          color: Color(0xFFDC2626),
                          size: 40,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: Color(0xFFDC2626)),
                          SizedBox(width: 6),
                          Text(
                            'လုပ်ဆောင်ချက်များ အားလုံး ပိတ်ပင်ထားပါသည်',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Headline Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      tierSubtitle,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 24),

                    // ── FLAT FULL-SCREEN COUNTDOWN SECTION (NO CARD) ──
                    const Text(
                      'ပြန်လည်ဖွင့်လှစ်ရန် ကျန်ရှိချိန်',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      is100Years ? "အပြီးတိုင် ပိတ်ပင်ထားသည်" : timerStr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: is100Years ? const Color(0xFFDC2626) : const Color(0xFFBE123C),
                        fontSize: is100Years ? 22 : (is10Days ? 28 : 36),
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: is10Days ? 1 : 2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      is100Years
                          ? "စီမံခန့်ခွဲသူ (Admin) မှသာ ပြန်လည်ဖွင့်ပေးနိုင်ပါမည်"
                          : "သတ်မှတ်ချိန်ပြည့်ပါက အလိုအလျောက် ပြန်လည်အသုံးပြုနိုင်ပါမည်",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 20),

                    // ── FLAT REASON & NOTICE SECTION (NO CARD) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ပိတ်ပင်ရသည့် အကြောင်းရင်းနှင့် သတိပေးချက်',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _suspensionReason ?? subtext,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── BOTTOM FULL-WIDTH ACTIONS ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLegalLawsSheet(context, true),
                      icon: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'ဥပဒေနှင့် ပြစ်ဒဏ်များ ကြည့်ရန်',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await _checkSuspensionStatus();
                        if (!mounted) return;
                        if (!_isSuspended) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('အကောင့်ပြန်လည် အသုံးပြုနိုင်ပါပြီ!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('ဆိုင်းငံ့ကာလ ကျန်ရှိနေသေးပါသည်'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF334155)),
                      label: const Text(
                        'အကောင့်အခြေအနေ ပြန်စစ်မည်',
                        style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      await ref.read(authProvider.notifier).logout();
                      if (mounted) router.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF64748B)),
                    label: const Text(
                      'အကောင့်မှ ထွက်မည်',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
