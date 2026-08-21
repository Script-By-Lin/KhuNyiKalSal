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

  @override
  Widget build(BuildContext context) {
    final activeEmergencies = ref.watch(emergencyProvider).value ?? [];
    final activeEmergency =
        activeEmergencies.isNotEmpty ? activeEmergencies.first : null;
    final locale = ref.watch(settingsProvider).locale.languageCode;
    final isMm = locale == 'my';

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

          if (_isSuspended)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1010),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _suspensionTier == 1
                                ? (isMm ? '⚠️ အကောင့် ၁ ရက် ပိတ်ပင်ထားပါသည်' : '⚠️ 1-Day Suspension (1st Offense)')
                                : (_suspensionTier == 2
                                    ? (isMm ? '⚠️ အကောင့် ၁၀ ရက် ပိတ်ပင်ထားပါသည်' : '⚠️ 10-Days Suspension (2nd Offense)')
                                    : (isMm ? '🚫 နှစ်ပေါင်း ၁၀၀ ပိတ်ပင်ထားပါသည်' : '🚫 Permanent Ban (100 Years)')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _suspensionTier >= 3
                                ? (isMm ? 'အက်ဒမင်ထံသို့ ဆက်သွယ်ပါ' : 'Please contact administrator.')
                                : '${isMm ? "ပြန်လည်ဖွင့်ရန် ကျန်ရှိချိန်" : "Re-activating in"}: ${_formatDuration(_remainingSuspensionSeconds)}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
