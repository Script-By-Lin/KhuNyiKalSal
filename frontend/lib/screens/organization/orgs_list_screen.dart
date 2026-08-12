import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/organization.dart';
import '../../providers/organization_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/location_service.dart';

class OrgsListScreen extends ConsumerStatefulWidget {
  const OrgsListScreen({super.key});

  @override
  ConsumerState<OrgsListScreen> createState() => _OrgsListScreenState();
}

class _OrgsListScreenState extends ConsumerState<OrgsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentLocation();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    ref.read(allOrganizationsProvider.notifier).loadAll(lat: lat, lng: lng);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final orgsAsync = ref.watch(allOrganizationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'ကယ်ဆယ်ရေးအဖွဲ့အစည်းများ' : 'Rescue Organizations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrgs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: isMm ? 'အမည် သို့မဟုတ် ဒေသဖြင့် ရှာဖွေပါ (ဥပမာ - ပဲခူး)...' : 'Search by name or region (e.g. Bago)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          Expanded(
            child: orgsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryRed),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load organizations: $err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadOrgs,
                      child: Text(isMm ? 'ပြန်လည်ကြိုးစားမည်' : 'Retry'),
                    ),
                  ],
                ),
              ),
              data: (orgs) {
                final filtered = orgs.where((o) {
                  return o.orgName.toLowerCase().contains(_query) ||
                      o.phoneNumber.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: AppTheme.subtleGrey),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? 'No rescue organizations available'
                              : 'No matching organizations for "$_query"',
                          style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadOrgs,
                  color: AppTheme.primaryRed,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final org = filtered[index];
                      return _OrgCard(org: org);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  final OrganizationModel org;

  const _OrgCard({required this.org});

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: AppTheme.secondaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.orgName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppTheme.subtleGrey),
                        const SizedBox(width: 4),
                        Text(
                          org.phoneNumber,
                          style: const TextStyle(fontSize: 13, color: AppTheme.subtleGrey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.map_outlined, color: Colors.blue),
                tooltip: 'View on Map',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.12),
                ),
                onPressed: () => context.go('/map', extra: org),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.call, color: AppTheme.secondaryGreen),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                ),
                onPressed: () => _makeCall(org.phoneNumber),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, size: 15, color: AppTheme.primaryRed),
                  const SizedBox(width: 4),
                  Text(
                    'Coverage: ${org.coverageRadiusKm.toStringAsFixed(0)} km',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (org.distanceKm != null)
                Row(
                  children: [
                    const Icon(Icons.near_me, size: 15, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${org.distanceKm!.toStringAsFixed(1)} km away',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
