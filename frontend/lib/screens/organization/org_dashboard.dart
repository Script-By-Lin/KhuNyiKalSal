import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

class OrgDashboard extends ConsumerStatefulWidget {
  const OrgDashboard({super.key});

  @override
  ConsumerState<OrgDashboard> createState() => _OrgDashboardState();
}

class _OrgDashboardState extends ConsumerState<OrgDashboard>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _emergencies = [];
  final List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _historyLoading = true;
  StreamSubscription? _wsSub;
  StreamSubscription? _locSub;
  Timer? _pollTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initRealtimeTracking();
    _loadAlerts();
    _loadHistory();
    _listenForEvents();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadAlerts());
  }

  Future<void> _initRealtimeTracking() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      ApiService().updateVolunteerLocation(pos.latitude, pos.longitude);
      _locSub = LocationService.getLocationStream().listen((pos) {
        ApiService().updateVolunteerLocation(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _wsSub?.cancel();
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await ApiService().getVolunteerAlerts();
      if (mounted) {
        setState(() {
          _emergencies.clear();
          _emergencies.addAll(List<Map<String, dynamic>>.from(res.data));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiService().getResponderHistory();
      if (mounted) {
        setState(() {
          _history.clear();
          _history.addAll(List<Map<String, dynamic>>.from(res.data));
          _historyLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _listenForEvents() {
    final auth = ref.read(authProvider.notifier);
    _wsSub = auth.ws.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event'];
      if (eventType == 'SOS_CREATED') {
        _loadAlerts();
        NotificationService().triggerUrgentHapticAlarm();
        final typeStr = (event['type'] ?? 'EMERGENCY').toString().toUpperCase();
        final victimName = (event['user_info']?['full_name'] ?? 'Citizen').toString();
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🚨 CRITICAL $typeStr SOS ALERT!',
          body: 'Patient: $victimName. Tap to view road route & dispatch rescue.',
          payload: json.encode(event),
        );
      } else if (eventType == 'VOLUNTEER_ACCEPTED' || eventType == 'EMERGENCY_ACCEPTED') {
        _loadAlerts();
      } else if (eventType == 'EMERGENCY_COMPLETED' || eventType == 'SOS_CANCELLED') {
        setState(() {
          _emergencies.removeWhere((e) => e['emergency_id'] == event['emergency_id']);
        });
        _loadHistory();
      }
    });
  }

  Future<void> _respond(String emergencyId, String action) async {
    try {
      await ApiService().respondToEmergency(emergencyId, action);
      if (mounted) {
        if (action == 'accept') {
          setState(() {
            final idx = _emergencies.indexWhere((e) => e['emergency_id'] == emergencyId);
            if (idx != -1) _emergencies[idx]['status'] = 'accepted';
          });
          _snack('✅ Case Accepted — Rescue Team Dispatched!', AppTheme.primaryRed);
        } else {
          setState(() {
            _emergencies.removeWhere((e) => e['emergency_id'] == emergencyId);
          });
          _snack('❌ Emergency Rejected', Colors.orange);
        }
      }
    } catch (_) {
      _snack('Failed to update emergency status', Colors.red);
    }
  }

  Future<void> _completeEmergency(String emergencyId) async {
    try {
      await ApiService().completeEmergency(emergencyId);
      if (mounted) {
        setState(() {
          _emergencies.removeWhere((e) => e['emergency_id'] == emergencyId);
        });
        _loadHistory();
        _snack('🎉 Mission Completed! Record saved.', AppTheme.primaryRed);
      }
    } catch (e) {
      String errMsg = 'Failed to complete emergency';
      try {
        final dioErr = e as dynamic;
        if (dioErr.response?.data != null) {
          final data = dioErr.response.data;
          if (data is Map && data.containsKey('detail')) {
            errMsg = data['detail'].toString();
          }
        }
      } catch (_) {}
      _snack('❌ $errMsg', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }





  // ───────────────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pending = _emergencies.where((e) => e['status'] != 'accepted').toList();
    final active = _emergencies.where((e) => e['status'] == 'accepted').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppTheme.primaryRed, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('COMMAND CENTER',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 0.8)),
                        SizedBox(height: 2),
                        Text('Live Emergency Dispatch & GPS Radar',
                            style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                  _topAction(Icons.people_outline, () => context.push('/manage-volunteers')),
                  _topAction(Icons.refresh, () {
                    _loadAlerts();
                    _loadHistory();
                  }),
                  _topAction(Icons.logout, () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Stat Counters Row ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _counter('PENDING', pending.length, const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _counter('ACTIVE', active.length, AppTheme.primaryRed),
                  const SizedBox(width: 10),
                  _counter('COMPLETED', _history.where((h) => h['status'] == 'completed').length, const Color(0xFF06B6D4)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Light Tab Bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelPadding: EdgeInsets.zero,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  dividerHeight: 0,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  tabs: [
                    Tab(text: 'Pending (${pending.length})'),
                    Tab(text: 'Active (${active.length})'),
                    Tab(text: 'History (${_history.length})'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab Content Container (Light Theme) ─────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.black12),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCardList(pending, isPending: true),
                    _buildCardList(active, isPending: false),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Action Icon ────────────────────────────────────────────────
  Widget _topAction(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton(
        icon: Icon(icon, color: Colors.black54, size: 20),
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black12),
          ),
        ),
      ),
    );
  }

  // ── Stat Counter Badge ─────────────────────────────────────────────
  Widget _counter(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 24)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }

  // ── Emergency Card List ────────────────────────────────────────────
  Widget _buildCardList(List<Map<String, dynamic>> items, {required bool isPending}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPending ? Icons.notifications_off_outlined : Icons.check_circle_outline,
                size: 52, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              isPending ? 'No pending emergency calls' : 'No active dispatches right now',
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      backgroundColor: Colors.white,
      color: AppTheme.primaryRed,
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => _emergencyCard(items[i]),
      ),
    );
  }

  // ── Emergency Card (Sleek Dark Theme) ──────────────────────────────
  Widget _emergencyCard(Map<String, dynamic> e) {
    final info = e['user_info'] as Map<String, dynamic>? ?? {};
    final typeStr = (e['type'] ?? 'emergency').toString().toUpperCase();
    final isFire = typeStr == 'FIRE';
    final isMedical = typeStr == 'MEDICAL';
    final phone = info['phone_number'] ?? '';
    final eid = e['emergency_id'] ?? '';
    final isAccepted = e['status'] == 'accepted';

    final accent = isFire
        ? const Color(0xFFF97316)
        : isMedical
            ? const Color(0xFFEF4444)
            : const Color(0xFF3B82F6);
    final icon = isFire
        ? Icons.local_fire_department
        : isMedical
            ? Icons.local_hospital
            : Icons.shield;

    // Estimate ETA based on sample distance (~4.2km -> ~6 mins)
    const double sampleDist = 4.2;
    final int etaMins = ((sampleDist / 40.0) * 60).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAccepted ? AppTheme.primaryRed : accent.withValues(alpha: 0.4),
          width: isAccepted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAccepted ? AppTheme.primaryRed : accent).withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card Header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (isAccepted ? AppTheme.primaryRed : accent).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isAccepted ? AppTheme.primaryRed : accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(isAccepted ? Icons.airport_shuttle : icon,
                      color: Colors.black, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$typeStr EMERGENCY',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: isAccepted ? AppTheme.primaryRed : accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isAccepted)
                        Text(
                          '⏱️ ETA: ~$etaMins mins ($sampleDist km away)',
                          style: const TextStyle(
                              color: AppTheme.primaryRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isAccepted ? AppTheme.primaryRed : Colors.orange).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAccepted ? AppTheme.primaryRed : Colors.orange,
                    ),
                  ),
                  child: Text(
                    isAccepted ? 'EN ROUTE' : 'PENDING DISPATCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isAccepted ? AppTheme.primaryRed : Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Card Body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _darkField(Icons.person, info['full_name'] ?? 'Unknown Victim'),
                _darkField(Icons.phone, phone.isNotEmpty ? phone : 'Not Provided'),
                if (isMedical) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _darkBadge(Icons.bloodtype, info['blood_type'] ?? 'N/A', Colors.redAccent),
                      const SizedBox(width: 8),
                      _darkBadge(Icons.medical_information, info['medical_conditions'] ?? 'None', Colors.blueAccent),
                    ],
                  ),
                ],

                if (isAccepted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF818CF8), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_run_rounded, color: Color(0xFF38BDF8), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HANDLED BY RESCUE VOLUNTEER',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e['assigned_volunteer_name'] != null 
                                    ? e['assigned_volunteer_name'].toString()
                                    : 'Assigned Volunteer',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00E676)),
                          ),
                          child: const Text(
                            'EN ROUTE',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Map Navigation Button ─────────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                        final loc = e['location'] as Map<String, dynamic>? ?? {};
                        final lat = (loc['lat'] as num?)?.toDouble() ?? 16.8661;
                        final lng = (loc['lng'] as num?)?.toDouble() ?? 96.1951;
                        context.push('/mission-map', extra: {
                          'lat': lat,
                          'lng': lng,
                          'title': '🚨 Emergency Target: ${info['full_name'] ?? 'Victim'} ($typeStr)',
                          'returnRoute': '/org-dashboard',
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

                // ── Primary Action Buttons ────────────────────────────
                Row(
                  children: [
                    if (phone.isNotEmpty)
                      _iconBtn(Icons.call, AppTheme.primaryRed, () => _makeCall(phone)),
                    if (phone.isNotEmpty) const SizedBox(width: 8),
                    if (isAccepted)
                      Expanded(
                        child: _actionBtn(
                          'MISSION COMPLETE',
                          AppTheme.primaryRed,
                          Icons.check_circle_rounded,
                          () => _completeEmergency(eid),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: _actionBtn(
                          'DISPATCH RESCUE',
                          AppTheme.primaryRed,
                          Icons.send_rounded,
                          () => _respond(eid, 'accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.close, const Color(0xFFEF4444), () => _respond(eid, 'reject')),
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

  // ── History List (Scoped to this Org) ──────────────────────────────
  Widget _buildHistoryList() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 52, color: Colors.black38),
            const SizedBox(height: 12),
            const Text(
              'No mission records for your organization',
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Completed dispatches will be archived here',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      backgroundColor: Colors.white,
      color: AppTheme.primaryRed,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: _history.length,
        itemBuilder: (_, i) => _historyCard(_history[i]),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> h) {
    final info = h['user_info'] as Map<String, dynamic>? ?? {};
    final typeStr = (h['type'] ?? 'emergency').toString().toUpperCase();
    final status = h['status'] ?? '';
    final isCompleted = status == 'completed';
    final createdAt = h['created_at'] != null
        ? DateFormat('MMM dd, yyyy – HH:mm').format(DateTime.parse(h['created_at']).toLocal())
        : 'Unknown';

    final accent = isCompleted ? AppTheme.primaryRed : Colors.black54;
    final icon = isCompleted ? Icons.check_circle_rounded : Icons.cancel_outlined;

    return GestureDetector(
      onTap: () => _showUserDetails(info, typeStr, status),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$typeStr — ${info['full_name'] ?? 'Unknown'}',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  createdAt,
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              isCompleted ? 'COMPLETED' : 'CANCELLED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> info, String typeStr, String status) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  const Text('Victim Details', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.black12, height: 30),
              _darkField(Icons.person, info['full_name'] ?? 'Unknown'),
              _darkField(Icons.phone, (info['phone_number']?.toString().isNotEmpty ?? false) ? info['phone_number'] : 'Not Provided'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _darkBadge(Icons.bloodtype, info['blood_type'] ?? 'Unknown', Colors.redAccent),
                  const SizedBox(width: 8),
                  _darkBadge(Icons.medical_information, info['medical_conditions'] ?? 'None', Colors.blueAccent),
                ],
              ),
              const Divider(color: Colors.black12, height: 30),
              _darkField(Icons.local_hospital, 'Emergency: $typeStr'),
              _darkField(Icons.info_outline, 'Status: ${status.toUpperCase()}'),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable Dark Widgets ──────────────────────────────────────────
  Widget _darkField(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _darkBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      width: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          backgroundColor: color.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
