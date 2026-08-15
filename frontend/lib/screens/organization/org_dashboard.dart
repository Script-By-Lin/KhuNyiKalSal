import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  final List<Map<String, dynamic>> _bloodDonations = [];
  bool _loading = true;
  bool _historyLoading = true;
  bool _bloodLoading = true;
  StreamSubscription? _wsSub;
  StreamSubscription? _locSub;
  Timer? _pollTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initRealtimeTracking();
    _loadAlerts();
    _loadHistory();
    _loadBloodDonations();
    _listenForEvents();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadAlerts();
      _loadBloodDonations();
    });
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
    _bloodSearchCtrl.dispose();
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

  Future<void> _loadBloodDonations() async {
    try {
      final res = await ApiService().getOrgBloodDonations();
      if (mounted) {
        setState(() {
          _bloodDonations.clear();
          _bloodDonations.addAll(List<Map<String, dynamic>>.from(res.data));
          _bloodLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _bloodLoading = false);
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
      } else if (eventType == 'NEW_BLOOD_DONATION_REQUEST') {
        _loadBloodDonations();
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🩸 New Blood Donation Request!',
          body: 'Donor ${event['donor_name']} (${event['blood_type']}) has requested a blood donation appointment.',
        );
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
          _snack('Emergency Rejected', Colors.orange);
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
        _snack('Mission Completed. Record saved.', AppTheme.primaryRed);
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
      _snack(errMsg, Colors.red);
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
                  _topAction(Icons.edit_note_rounded, _openEditOrgProfileModal),
                  _topAction(Icons.refresh, () {
                    _loadAlerts();
                    _loadHistory();
                    _loadBloodDonations();
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
                    Tab(text: 'Blood (${_bloodDonations.where((b) => b['status'] == 'Pending' || b['status'] == 'Accepted').length})'),
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
                    _buildBloodDonationsList(),
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

  // ── Edit Organization Profile Modal ────────────────────────────────
  Future<void> _openEditOrgProfileModal() async {
    Map<String, dynamic>? profile;
    try {
      final res = await ApiService().getProfile();
      profile = res.data;
    } catch (_) {}

    if (!mounted) return;

    final nameCtrl = TextEditingController(text: profile?['org_name'] ?? profile?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: profile?['phone_number'] ?? '');
    final addressCtrl = TextEditingController(text: profile?['headquarters_address'] ?? '');
    final regionsCtrl = TextEditingController(text: profile?['operating_regions'] ?? '');
    final radiusCtrl = TextEditingController(text: profile?['coverage_radius_km'] != null ? '${profile!['coverage_radius_km']}' : '50.0');
    final regNumCtrl = TextEditingController(text: profile?['registration_number'] ?? '');
    final latCtrl = TextEditingController(text: profile?['location_lat'] != null ? '${profile!['location_lat']}' : '');
    final lngCtrl = TextEditingController(text: profile?['location_lng'] != null ? '${profile!['location_lng']}' : '');

    String selectedCategory = 'Medical';
    final existingCat = profile?['category'] as String?;
    if (existingCat != null && existingCat.isNotEmpty) {
      if (existingCat.toLowerCase().contains('fire')) {
        selectedCategory = 'Fire';
      } else if (existingCat.toLowerCase().contains('volunt')) {
        selectedCategory = 'Local Voluntary Org';
      } else {
        selectedCategory = 'Medical';
      }
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.apartment_rounded, color: AppTheme.primaryRed, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Edit Organization Profile',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Org Name
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Organization Name',
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Hotline
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Hotline Phone Number',
                    helperText: 'Must start with +959 or 09 (e.g. 09123456789)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Organization Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Medical', child: Text('Medical & Ambulance')),
                    DropdownMenuItem(value: 'Fire', child: Text('Fire & Disaster Rescue')),
                    DropdownMenuItem(value: 'Local Voluntary Org', child: Text('Local Voluntary Org')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                // Headquarters Address
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Headquarters Address',
                    prefixIcon: Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Operating Regions
                TextField(
                  controller: regionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Operating Regions',
                    helperText: 'e.g. Kamaryut, Hledan, Sanchaung, Bahan',
                    prefixIcon: Icon(Icons.map_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                // Coverage & Registration
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: radiusCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Coverage (KM)',
                          prefixIcon: Icon(Icons.radar_outlined),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: regNumCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reg Number',
                          prefixIcon: Icon(Icons.verified_outlined),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Coordinates Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: Icon(Icons.my_location, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: Icon(Icons.location_searching, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Get Current GPS Location button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: const Text('Use Current GPS Coordinates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryRed,
                      side: const BorderSide(color: AppTheme.primaryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      try {
                        final pos = await LocationService.getCurrentLocation();
                        setModalState(() {
                          latCtrl.text = pos.latitude.toStringAsFixed(6);
                          lngCtrl.text = pos.longitude.toStringAsFixed(6);
                        });
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Failed to get GPS location'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');

                            if (name.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Organization name is required'), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            if (phone.isNotEmpty && !RegExp(r'^(?:\+959|09)\d{7,10}$').hasMatch(phone)) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Invalid phone format (must start with +959 or 09)'), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);

                            final payload = <String, dynamic>{
                              'org_name': name,
                              'full_name': name,
                              'phone_number': phone,
                              'category': selectedCategory,
                              'operating_regions': regionsCtrl.text.trim(),
                              'headquarters_address': addressCtrl.text.trim(),
                              'registration_number': regNumCtrl.text.trim(),
                            };

                            final rad = double.tryParse(radiusCtrl.text.trim());
                            if (rad != null) payload['coverage_radius_km'] = rad;

                            final lat = double.tryParse(latCtrl.text.trim());
                            final lng = double.tryParse(lngCtrl.text.trim());
                            if (lat != null && lng != null) {
                              payload['location_lat'] = lat;
                              payload['location_lng'] = lng;
                            }

                            try {
                              await ApiService().updateProfile(payload);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _snack('Organization profile updated successfully!', AppTheme.secondaryGreen);
                              _loadAlerts();
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Failed to update organization profile'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SAVE ORGANIZATION PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
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

  // ── Blood Donation & Supply Request Management ─────────────────────────
  final _bloodSearchCtrl = TextEditingController();
  String _bloodFilterQuery = '';

  Widget _buildBloodDonationsList() {
    if (_bloodLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    final filteredDonations = _bloodDonations.where((d) {
      if (_bloodFilterQuery.isEmpty) return true;
      final q = _bloodFilterQuery.toLowerCase();
      final pName = (d['patient_name'] ?? '').toString().toLowerCase();
      final dName = (d['donor_name'] ?? '').toString().toLowerCase();
      final bType = (d['blood_type'] ?? '').toString().toLowerCase();
      final status = (d['status'] ?? '').toString().toLowerCase();
      final hosp = (d['hospital_name'] ?? d['target_location_name'] ?? '').toString().toLowerCase();
      return pName.contains(q) || dName.contains(q) || bType.contains(q) || status.contains(q) || hosp.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadBloodDonations,
      color: AppTheme.primaryRed,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Search Input Bar
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _bloodSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search patient, donor, blood type...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                suffixIcon: _bloodFilterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _bloodSearchCtrl.clear();
                          setState(() => _bloodFilterQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) => setState(() => _bloodFilterQuery = val.trim()),
            ),
          ),

          if (filteredDonations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.water_drop_outlined, size: 48, color: AppTheme.primaryRed),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _bloodFilterQuery.isNotEmpty ? 'No Matching Blood Records' : 'No Blood Records',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bloodFilterQuery.isNotEmpty
                          ? 'Try searching with a different term.'
                          : 'Incoming blood donation pledges & emergency blood requests will appear here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredDonations.map((d) {
              final id = d['id'] ?? '';
              final reqType = (d['request_type'] ?? 'donate').toString().toLowerCase();
              final isRequest = reqType == 'request';
              final donorName = d['donor_name'] ?? 'Citizen Donor';
              final patientName = d['patient_name'];
              final phone = d['donor_phone'] ?? '';
              final bloodType = d['blood_type'] ?? '';
              final preferredDate = d['preferred_date'] ?? 'ASAP';
              final units = d['units'] ?? 1;
              final status = (d['status'] ?? 'Pending').toString();
              final isAccepted = status.toLowerCase() == 'accepted';
              final isPending = status.toLowerCase() == 'pending';
              final apptDate = d['appointment_date'];
              final apptLoc = d['appointment_location'];
              final pickupMsg = d['pickup_location_message'];
              final medNotes = d['medical_notes'];
              final urgency = d['urgency_level'];
              final hospital = d['hospital_name'] ?? d['target_location_name'] ?? '';

              Color badgeColor = Colors.orange;
              if (isAccepted) badgeColor = AppTheme.secondaryGreen;
              if (status.toLowerCase() == 'completed') badgeColor = Colors.blue;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRequest
                        ? (isAccepted ? AppTheme.secondaryGreen.withValues(alpha: 0.5) : Colors.red.shade300)
                        : (isPending ? Colors.orange.shade300 : Colors.grey.shade200),
                    width: (isPending || isRequest) ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRequest
                                  ? Colors.red.shade100
                                  : AppTheme.primaryRed.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              bloodType,
                              style: TextStyle(
                                color: isRequest ? const Color(0xFFB71C1C) : AppTheme.primaryRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      isRequest ? 'BLOOD REQUEST' : 'DONATION PLEDGE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: isRequest ? const Color(0xFFB71C1C) : Colors.black87,
                                      ),
                                    ),
                                    if (urgency != null && urgency.toString().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          urgency.toString(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isRequest
                                      ? 'Patient: ${patientName ?? donorName} ($units Units)'
                                      : 'Donor: $donorName ($units Units)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('Contact: $phone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAccepted ? AppTheme.secondaryGreen : badgeColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAccepted ? 'ACCEPTED' : status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Icon(Icons.local_hospital_outlined, size: 15, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isRequest ? 'Hospital / Location: $hospital' : 'Preferred: $preferredDate',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (medNotes != null && medNotes.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.medical_information_outlined, size: 15, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Notes: $medNotes',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ],

                      if (isAccepted) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isRequest && pickupMsg != null && pickupMsg.toString().isNotEmpty)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on, size: 15, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Pickup at: $pickupMsg',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              if (apptDate != null && apptDate.toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 15, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Time: $apptDate',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                              if (!isRequest && apptLoc != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 15, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Where to come: $apptLoc',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (phone.isNotEmpty)
                            IconButton.filledTonal(
                              icon: const Icon(Icons.call, color: AppTheme.secondaryGreen, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                              ),
                              onPressed: () => _makePhoneCall(phone),
                            ),
                          const SizedBox(width: 8),
                          if (isPending)
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: Text(
                                  isRequest ? 'PROVIDE BLOOD & SET PICKUP' : 'ACCEPT & SCHEDULE',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isRequest ? const Color(0xFFB71C1C) : AppTheme.primaryRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _openAcceptAppointmentModal(d),
                              ),
                            )
                          else if (isAccepted)
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.done_all, size: 18, color: Colors.blue),
                                label: const Text('MARK COMPLETED',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.blue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  await ApiService().updateBloodDonationStatus(id, 'Completed');
                                  _loadBloodDonations();
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openAcceptAppointmentModal(Map<String, dynamic> donation) {
    final reqType = (donation['request_type'] ?? 'donate').toString().toLowerCase();
    final isRequest = reqType == 'request';

    final dateCtrl = TextEditingController(
      text: isRequest ? 'Immediately available / Today' : 'Tomorrow at 10:00 AM',
    );
    final locCtrl = TextEditingController(
      text: isRequest
          ? 'Hospital Blood Bank Desk Room 102, 1st Floor'
          : 'Blood Donation Center, Main Hospital Wing Room 102',
    );
    final notesCtrl = TextEditingController(
      text: isRequest
          ? 'Please bring patient crossmatch sample and hospital blood requisition form.'
          : 'Please bring your NRC / ID card and arrive 15 minutes before your scheduled appointment.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isRequest ? Icons.bloodtype : Icons.calendar_month,
              color: AppTheme.primaryRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isRequest
                    ? 'Provide Blood for ${donation['patient_name'] ?? donation['donor_name']}'
                    : 'Schedule Appointment for ${donation['donor_name']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRequest ? 'Blood Request Details:' : 'Donor Information:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                'Blood Type: ${donation['blood_type']} • Units: ${donation['units']} • Location: ${donation['hospital_name'] ?? donation['target_location_name']}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: locCtrl,
                decoration: InputDecoration(
                  labelText: isRequest ? 'Where to Pick Up Blood (Room / Counter)' : 'Where to Come (Room / Location)',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: dateCtrl,
                decoration: InputDecoration(
                  labelText: isRequest ? 'Pickup Available Time' : 'Appointment Date & Time',
                  prefixIcon: const Icon(Icons.access_time, size: 20),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: isRequest ? 'Instructions for Requester' : 'Hospital Notes / Instructions',
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isRequest ? const Color(0xFFB71C1C) : AppTheme.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final id = donation['id'];
              if (id != null) {
                try {
                  await ApiService().acceptBloodDonation(id, {
                    'appointment_date': dateCtrl.text.trim(),
                    'appointment_location': locCtrl.text.trim(),
                    'pickup_location_message': locCtrl.text.trim(),
                    'appointment_notes': notesCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadBloodDonations();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isRequest
                            ? 'Blood supply request accepted and pickup location sent to patient!'
                            : 'Blood donation appointment confirmed and sent to donor!'),
                        backgroundColor: AppTheme.secondaryGreen,
                      ),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to schedule appointment'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: Text(isRequest ? 'CONFIRM & SEND PICKUP LOCATION' : 'CONFIRM & NOTIFY DONOR'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}
