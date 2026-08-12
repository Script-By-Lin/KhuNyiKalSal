import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

import 'dart:async';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/organization.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng? _userPos;
  final List<Map<String, dynamic>> _orgs = [];
  StreamSubscription? _locSub;
  Map<String, dynamic>? _selectedOrg; // Currently tapped org

  @override
  void initState() {
    super.initState();
    _initLocationAndOrgs();
  }

  Future<void> _initLocationAndOrgs() async {
    // 1. Get real current GPS location of the user
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_userPos!, 14.0);
      }
    } catch (_) {}

    // Stream continuous position updates
    try {
      _locSub = LocationService.getLocationStream().listen((pos) {
        if (mounted) {
          setState(() {
            _userPos = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (_) {}

    // 2. Fetch real active organizations (pass user coords for distance calc)
    try {
      final res = await ApiService().getAllOrgs(
        lat: _userPos?.latitude,
        lng: _userPos?.longitude,
      );
      if (mounted) {
        setState(() {
          _orgs.clear();
          _orgs.addAll(List<Map<String, dynamic>>.from(res.data));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _locSub?.cancel();
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPos = _userPos ?? const LatLng(16.8661, 96.1951);
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [


              // ── Live Map Preview Box ────────────────────────────────────
              Text(
                isMm ? 'မြေပုံ အစမ်းကြည့်ရှုခြင်း' : 'Live Radar Preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Container(
                height: 210,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: currentPos,
                          initialZoom: 13.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                          onTap: (_, __) => setState(() => _selectedOrg = null),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.khunyikalsal.app',
                          ),
                          MarkerLayer(
                            markers: [
                              // User Location Marker
                              Marker(
                                point: currentPos,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryRed.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.my_location, color: Colors.white, size: 22),
                                ),
                              ),
                              // Organization Markers (tappable)
                              ..._orgs.map((org) {
                                final double lat = (org['geo_lat'] as num?)?.toDouble() ?? 16.8661;
                                final double lng = (org['geo_lng'] as num?)?.toDouble() ?? 96.1951;
                                final name = (org['org_name'] ?? '').toString();
                                final isFire = name.toLowerCase().contains('fire');

                                return Marker(
                                  point: LatLng(lat, lng),
                                  width: 36,
                                  height: 36,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedOrg = org),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isFire ? Colors.orange : AppTheme.secondaryGreen,
                                        shape: BoxShape.circle,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        isFire ? Icons.local_fire_department : Icons.local_hospital,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                      // ── Selected Org Info Card ──────────────────────────
                      if (_selectedOrg != null)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.local_hospital, color: AppTheme.secondaryGreen, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (_selectedOrg!['org_name'] ?? (isMm ? 'အမည်မရှိ' : 'Unknown')).toString(),
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                (_selectedOrg!['phone_number'] ?? _selectedOrg!['phone'] ?? '').toString(),
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.map_outlined, color: Colors.blue),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                      ),
                                      onPressed: () {
                                        final orgModel = OrganizationModel.fromJson(_selectedOrg!);
                                        context.go('/map', extra: orgModel);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.call, color: AppTheme.secondaryGreen),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                                      ),
                                      onPressed: () {
                                        final phone = (_selectedOrg!['phone_number'] ?? _selectedOrg!['phone'] ?? '').toString();
                                        if (phone.isNotEmpty) {
                                          _makeCall(phone);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.radar, size: 14, color: AppTheme.primaryRed),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Coverage: ${(_selectedOrg!['coverage_radius_km'] ?? 50.0).toString()} km',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.navigation, size: 14, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          () {
                                            final d = (_selectedOrg!['distance_km'] as num?)?.toDouble();
                                            if (d == null) return isMm ? 'မသိရှိပါ' : 'N/A';
                                            return d < 1
                                                ? '${(d * 1000).toStringAsFixed(0)} m ${isMm ? "အကွာ" : "away"}'
                                                : '${d.toStringAsFixed(1)} km ${isMm ? "အကွာ" : "away"}';
                                          }(),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Quick Actions ─────────────────────────────────────────
              Text(
                isMm ? 'အမြန်လုပ်ဆောင်ချက်များ' : 'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.map_outlined,
                        title: isMm ? 'မြေပုံဖွင့်ရန်' : 'Open Map',
                        subtitle: isMm ? 'အနီးဆုံးအကူအညီရှာရန်' : 'Find nearby help',
                        color: AppTheme.primaryRed,
                        onTap: () => context.go('/map'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.health_and_safety_outlined,
                        title: isMm ? 'ကယ်ဆယ်ရေးအဖွဲ့များ' : 'Rescue Orgs',
                        subtitle: isMm ? 'အဖွဲ့များကြည့်ရှုရန်' : 'View available orgs',
                        color: AppTheme.secondaryGreen,
                        onTap: () => context.go('/organizations'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.person_outline,
                        title: isMm ? 'ပရိုဖိုင်' : 'Profile',
                        subtitle: isMm ? 'ဆေးဘက်ဆိုင်ရာနှင့် အရေးပေါ်အချက်အလက်' : 'Medical & emergency info',
                        color: Colors.blue,
                        onTap: () => context.push('/profile'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Info Buttons ──────────────────────────────────────────
              Text(
                isMm ? 'သတင်းအချက်အလက်' : 'Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _InfoTile(
                icon: Icons.help_outline,
                title: isMm ? 'အသုံးပြုပုံ' : 'How to Use',
                subtitle: isMm ? 'အရေးပေါ်အခြေအနေ အသုံးပြုနည်း' : 'Step-by-step emergency guide',
                onTap: () => context.push('/how-to-use'),
              ),
              const SizedBox(height: 10),
              _InfoTile(
                icon: Icons.gavel,
                title: isMm ? 'စည်းမျဉ်းနှင့် ဥပဒေများ' : 'Rules & Laws',
                subtitle: isMm ? 'တရားဝင်စည်းမျဉ်းများ' : 'Legal regulations & terms',
                onTap: () => context.push('/legal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.textDark, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.subtleGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.subtleGrey),
          ],
        ),
      ),
    );
  }
}
