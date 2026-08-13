import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/settings_provider.dart';
import '../../services/cache_service.dart';
import 'package:shimmer/shimmer.dart';

class FamilyAlertsScreen extends ConsumerStatefulWidget {
  const FamilyAlertsScreen({super.key});

  @override
  ConsumerState<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends ConsumerState<FamilyAlertsScreen> {
  List<dynamic> _alerts = [];
  bool _loading = true;
  bool _hasGroup = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Instantly load from cache first
    final cached = await CacheService.getFamilyAlerts();
    if (cached != null && mounted) {
      setState(() {
        _alerts = cached;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    // 2. Fetch fresh data in background
    try {
      await ApiService().getMyFamilyGroup();
      _hasGroup = true;
    } catch (_) {
      _hasGroup = false;
    }

    if (_hasGroup) {
      try {
        final res = await ApiService().getFamilyAlerts();
        if (mounted) {
          setState(() {
            _alerts = res.data as List;
            _loading = false;
          });
        }
        await CacheService.saveFamilyAlerts(res.data);
      } catch (_) {
        if (mounted && cached == null) {
          setState(() {
            _alerts = [];
            _loading = false;
          });
        }
      }
    } else {
      if (mounted && cached == null) {
        setState(() {
          _alerts = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'မိသားစု အရေးပေါ် သတိပေးချက်များ' : 'Family Emergency Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading && _alerts.isEmpty
          ? _buildSkeletonLoader()
          : !_hasGroup && _alerts.isEmpty
              ? _buildNoGroupAlertView(isMm)
              : _buildAlertsListView(isMm),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoGroupAlertView(bool isMm) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group_off_outlined, size: 64, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 20),
            Text(
              isMm ? 'မိသားစု အဖွဲ့ မရှိသေးပါ' : 'You Have No Family Group',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              isMm
                  ? 'မိသားစုဝင်များထံမှ အရေးပေါ် SOS သတိပေးချက်စာတိုများကို လက်ခံရရှိရန် မိသားစု အဖွဲ့တစ်ခုကို ဦးစွာ ဖန်တီးပါ သို့မဟုတ် ပူးပေါင်းပါ။'
                  : 'You have not created or joined a family group yet. Please create or join a family group first to receive emergency alert message boxes from your family members.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.family_restroom, color: Colors.white),
                label: Text(
                  isMm ? 'မိသားစု အဖွဲ့ သို့ သွားမည်' : 'CREATE / JOIN FAMILY GROUP',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => context.go('/family'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsListView(bool isMm) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryRed,
      child: _alerts.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, size: 64, color: AppTheme.secondaryGreen),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isMm ? 'အရေးပေါ် သတိပေးချက် မရှိပါ' : 'All Family Members Safe',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMm
                          ? 'သင်၏ မိသားစုဝင်များထံမှ အရေးပေါ် SOS သတိပေးချက်များ မရှိသေးပါ။'
                          : 'No family emergency alerts received yet. When a family member triggers an SOS, their alert message will appear here in real-time.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                final senderName = alert['sender_name'] ?? 'Family Member';
                final relationship = alert['relationship'] ?? 'Family';
                final type = (alert['emergency_type'] ?? 'emergency').toString().toUpperCase();
                final message = alert['message'] ?? 'Emergency SOS triggered!';
                final createdAt = alert['created_at']?.toString().replaceFirst('T', ' ').split('.').first ?? '';
                final double lat = (alert['location_lat'] as num?)?.toDouble() ?? 16.8661;
                final double lng = (alert['location_lng'] as num?)?.toDouble() ?? 96.1951;

                Color typeColor = AppTheme.primaryRed;
                IconData typeIcon = Icons.medical_services;
                if (type.contains('FIRE')) {
                  typeColor = Colors.orange;
                  typeIcon = Icons.local_fire_department;
                } else if (type.contains('CRIME')) {
                  typeColor = Colors.purple;
                  typeIcon = Icons.shield;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Bar ─────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Row(
                          children: [
                            Icon(typeIcon, color: typeColor, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          relationship,
                                          style: TextStyle(
                                            color: typeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Alert Date: $createdAt',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.subtleGrey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                type,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Message Box Body ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Action Button to View Location on Map
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: typeColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.map_outlined, color: Colors.white),
                                label: const Text(
                                  'VIEW LIVE LOCATION ON MAP',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: () {
                                  context.go('/map', extra: {
                                    'lat': lat,
                                    'lng': lng,
                                  });
                                },
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
    );
  }
}
