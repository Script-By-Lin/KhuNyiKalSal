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
  bool _sosHolding = false;
  bool _sosActivated = false;

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

    // Load active emergencies when the shell screen initializes (e.g., after login)
    Future.microtask(() {
      ref.read(emergencyProvider.notifier).loadActive();
    });

    // Listen to global WebSocket events (e.g. Family SOS)
    final auth = ref.read(authProvider.notifier);
    auth.ws.events.listen((event) {
      if (!mounted) return;
      if (event['event'] == 'FAMILY_SOS_ALERT') {
        final senderName = event['sender_name'] ?? 'Family Member';
        final rel = event['relationship'] ?? 'Family';
        final type = (event['emergency_type'] ?? 'EMERGENCY').toString().toUpperCase();
        
        // Trigger system notification
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🚨 $type SOS from $senderName!',
          body: 'Your $rel has activated an SOS emergency alert.',
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
      }
    });
  }

  @override
  void dispose() {
    _sosCtrl.dispose();
    super.dispose();
  }

  void _triggerEmergencyTypeSheet() {
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

          final notifier = ref.read(emergencyProvider.notifier);
          final emergencyId = await notifier.createSOS(type, lat, lng);

          if (!mounted) return;

          if (emergencyId != null) {
            context.go('/map');
          } else if (notifier.lastError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ ${notifier.lastError}'),
                backgroundColor: Colors.orange,
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

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          widget.child,

          if (activeEmergency != null || _sosHolding)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              child: AnimatedBuilder(
                animation: _sosCtrl,
                builder: (context, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black, // Sleek black dynamic island look
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryRed.withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: activeEmergency != null
                        ? Row(
                            children: [
                              // A pulsing red dot or icon
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SOS ${activeEmergency.status.toUpperCase()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      activeEmergency.isAccepted
                                          ? 'Help on the way'
                                          : 'Alerting teams...',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Cancel button
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
                                  child: const Text(
                                    'CANCEL',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
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
        child: Container(
          height: 68,
          margin: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.15),
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

              // 7. Settings
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: isMm ? 'ပြင်ဆင်ရန်' : 'Settings',
                isActive: _currentIndex(context) == 5,
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
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
    if (location.startsWith('/settings')) return 5;
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryRed.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.primaryRed : AppTheme.subtleGrey,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppTheme.primaryRed : AppTheme.subtleGrey,
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
