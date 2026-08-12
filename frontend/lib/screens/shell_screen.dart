import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🚨 SOS Activated! Searching nearest rescue teams...'),
                backgroundColor: AppTheme.primaryRed,
              ),
            );
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
          if (activeEmergency != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeEmergency.isAccepted
                        ? Colors.green.shade600
                        : AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE SOS - ${activeEmergency.type.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeEmergency.isAccepted
                                  ? 'Responder assigned • Help on the way!'
                                  : 'Alerting rescue teams • Waiting 5 min/org...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black26,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.cancel, color: Colors.white, size: 16),
                            label: const Text('CANCEL SOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                            onPressed: () {
                              ref
                                  .read(emergencyProvider.notifier)
                                  .cancelEmergency(activeEmergency.id);
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                            tooltip: 'Mark Complete',
                            onPressed: () {
                              ref
                                  .read(emergencyProvider.notifier)
                                  .completeEmergency(activeEmergency.id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                label: isMm ? 'ပင်မစာမျက်နှာ' : 'Home',
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

              // 3. CENTER EMERGENCY SOS BUTTON (HOLD 3 SECONDS)
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
                  if (!_sosActivated) {
                    _sosCtrl.reset();
                  }
                },
                child: AnimatedBuilder(
                  animation: _sosCtrl,
                  builder: (context, _) {
                    return Container(
                      width: 58,
                      height: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
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
                            blurRadius: 14 + _sosCtrl.value * 16,
                            spreadRadius: 2 + _sosCtrl.value * 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_sosCtrl.value > 0)
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: CircularProgressIndicator(
                                value: _sosCtrl.value,
                                strokeWidth: 3.5,
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.sos_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              Text(
                                _sosHolding ? 'HOLD...' : 'HOLD 3s',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 4. Map
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: isMm ? 'မြေပုံ' : 'Map',
                isActive: _currentIndex(context) == 2,
                onTap: () => context.go('/map'),
              ),

              // 5. Settings
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: isMm ? 'ဆက်တင်များ' : 'Settings',
                isActive: _currentIndex(context) == 3,
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
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/settings')) return 3;
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryRed.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.primaryRed : AppTheme.subtleGrey,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
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
