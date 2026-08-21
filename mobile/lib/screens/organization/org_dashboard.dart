// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

class OrgDashboard extends ConsumerStatefulWidget {
  const OrgDashboard({super.key});

  @override
  ConsumerState<OrgDashboard> createState() => _OrgDashboardState();
}

class _OrgDashboardState extends ConsumerState<OrgDashboard> {
  int _currentTabIndex = 0; // 0: SOS Radar, 1: Blood Hub, 2: Volunteers, 3: Coverage & Profile

  // ── SOS Emergencies State ──────────────────────────────────────────
  final List<Map<String, dynamic>> _emergencies = [];
  final List<Map<String, dynamic>> _history = [];
  bool _loadingEmergencies = true;
  bool _loadingHistory = true;
  String _sosSearchQuery = '';
  final _sosSearchCtrl = TextEditingController();
  String _selectedSosFilter = 'ALL'; // 'ALL', 'PENDING', 'ACTIVE', 'COMPLETED'
  String _selectedSosType = 'ALL'; // 'ALL', 'FIRE', 'MEDICAL', 'ACCIDENT', 'NATURAL_DISASTER'
  int _sosSubTab = 0; // 0: Live Calls, 1: Mission History

  // ── Blood Donations State ──────────────────────────────────────────
  final List<Map<String, dynamic>> _bloodDonations = [];
  bool _loadingBlood = true;
  String _bloodSearchQuery = '';
  String _selectedBloodFilter = 'ALL'; // 'ALL', 'PENDING', 'ACCEPTED', 'COMPLETED'
  final _bloodSearchCtrl = TextEditingController();

  // ── Volunteers State ───────────────────────────────────────────────
  final List<Map<String, dynamic>> _volunteers = [];
  bool _loadingVolunteers = true;
  String _volunteerSearchQuery = '';
  final _volunteerSearchCtrl = TextEditingController();

  // ── Organization Profile & Coverage State ──────────────────────────
  bool _loadingProfile = true;
  bool _savingProfile = false;
  Map<String, dynamic>? _orgProfile;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _regionsCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '50.0');
  final _regNumCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  double _coverageRadiusKm = 50.0;
  String _selectedCategory = 'Medical';

  // Bank & MMQR fields
  final _bankNameCtrl = TextEditingController();
  final _bankAccNumCtrl = TextEditingController();
  final _bankAccNameCtrl = TextEditingController();
  final _kbzPhoneCtrl = TextEditingController();
  final _wavePhoneCtrl = TextEditingController();
  final _mmqrPayloadCtrl = TextEditingController();
  final _mmqrImageUrlCtrl = TextEditingController();

  StreamSubscription? _wsSub;
  StreamSubscription? _locSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initRealtimeTracking();
    _fetchAllData();
    _listenForEvents();

    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchEmergencies(silent: true);
      _fetchBloodDonations(silent: true);
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
    _sosSearchCtrl.dispose();
    _bloodSearchCtrl.dispose();
    _volunteerSearchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _regionsCtrl.dispose();
    _radiusCtrl.dispose();
    _regNumCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccNumCtrl.dispose();
    _bankAccNameCtrl.dispose();
    _kbzPhoneCtrl.dispose();
    _wavePhoneCtrl.dispose();
    _mmqrPayloadCtrl.dispose();
    _mmqrImageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    _fetchEmergencies();
    _fetchHistory();
    _fetchBloodDonations();
    _fetchVolunteers();
    _fetchOrgProfile();
  }

  bool get _isMm => ref.read(settingsProvider).locale.languageCode == 'my';

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATA FETCHING & WEBSOCKETS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchEmergencies({bool silent = false}) async {
    if (!silent) setState(() => _loadingEmergencies = true);
    try {
      final res = await ApiService().getVolunteerAlerts();
      if (mounted) {
        setState(() {
          _emergencies.clear();
          _emergencies.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingEmergencies = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loadingEmergencies = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService().getResponderHistory();
      if (mounted) {
        setState(() {
          _history.clear();
          _history.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _fetchBloodDonations({bool silent = false}) async {
    if (!silent) setState(() => _loadingBlood = true);
    try {
      final res = await ApiService().getOrgBloodDonations();
      if (mounted) {
        setState(() {
          _bloodDonations.clear();
          _bloodDonations.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingBlood = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _loadingBlood = false);
    }
  }

  Future<void> _fetchVolunteers() async {
    setState(() => _loadingVolunteers = true);
    try {
      final res = await ApiService().listVolunteers();
      if (mounted) {
        setState(() {
          _volunteers.clear();
          _volunteers.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingVolunteers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVolunteers = false);
    }
  }

  Future<void> _fetchOrgProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final res = await ApiService().getProfile();
      if (mounted) {
        _orgProfile = res.data;
        _nameCtrl.text = _orgProfile?['org_name'] ?? _orgProfile?['full_name'] ?? '';
        _emailCtrl.text = _orgProfile?['email'] ?? ref.read(authProvider).email ?? '';
        _phoneCtrl.text = _orgProfile?['phone_number'] ?? '';
        _addressCtrl.text = _orgProfile?['headquarters_address'] ?? '';
        _regionsCtrl.text = _orgProfile?['operating_regions'] ?? '';
        _regNumCtrl.text = _orgProfile?['registration_number'] ?? '';

        final rad = (_orgProfile?['coverage_radius_km'] as num?)?.toDouble() ?? 50.0;
        _coverageRadiusKm = rad.clamp(5.0, 100.0);
        _radiusCtrl.text = _coverageRadiusKm.toStringAsFixed(1);

        if (_orgProfile?['location_lat'] != null) {
          _latCtrl.text = '${_orgProfile!['location_lat']}';
        }
        if (_orgProfile?['location_lng'] != null) {
          _lngCtrl.text = '${_orgProfile!['location_lng']}';
        }

        final cat = (_orgProfile?['category'] ?? '').toString().toLowerCase();
        if (cat.contains('fire')) {
          _selectedCategory = 'Fire';
        } else if (cat.contains('volunt')) {
          _selectedCategory = 'Local Voluntary Org';
        } else {
          _selectedCategory = 'Medical';
        }

        _loadingProfile = false;
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _listenForEvents() {
    final auth = ref.read(authProvider.notifier);
    _wsSub = auth.ws.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event'];
      if (eventType == 'SOS_CREATED') {
        _fetchEmergencies(silent: true);
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
        _fetchEmergencies(silent: true);
      } else if (eventType == 'NEW_BLOOD_DONATION_REQUEST') {
        _fetchBloodDonations(silent: true);
        NotificationService().showEmergencyAlert(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🩸 New Blood Donation Request!',
          body: 'Donor ${event['donor_name']} (${event['blood_type']}) requested appointment.',
        );
      } else if (eventType == 'EMERGENCY_COMPLETED' || eventType == 'SOS_CANCELLED') {
        setState(() {
          _emergencies.removeWhere((e) => e['emergency_id'] == event['emergency_id']);
        });
        _fetchHistory();
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOS ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _respond(String emergencyId, String action) async {
    try {
      await ApiService().respondToEmergency(emergencyId, action);
      if (mounted) {
        if (action == 'accept') {
          setState(() {
            final idx = _emergencies.indexWhere((e) => e['emergency_id'] == emergencyId);
            if (idx != -1) _emergencies[idx]['status'] = 'accepted';
          });
          _snack(_isMm ? '✅ အရေးပေါ် အမှုတွဲကို လက်ခံပြီး ကယ်ဆယ်ရေး စတင်ပါပြီ' : '✅ Case Accepted — Rescue Dispatched!', AppTheme.secondaryGreen);
        } else {
          setState(() {
            _emergencies.removeWhere((e) => e['emergency_id'] == emergencyId);
          });
          _snack(_isMm ? 'အရေးပေါ် ခေါ်ဆိုမှုကို ပယ်ဖျက်ပြီး အခြားသို့ လွှဲပြောင်းလိုက်ပါသည်' : 'Emergency Rejected / Dismissed', Colors.orange);
        }
      }
    } catch (_) {
      _snack(_isMm ? 'အရေးပေါ် အခြေအနေ ပြင်ဆင်ရန် မအောင်မြင်ပါ' : 'Failed to update emergency status', Colors.red);
    }
  }

  Future<void> _completeEmergency(String emergencyId) async {
    try {
      await ApiService().completeEmergency(emergencyId);
      if (mounted) {
        setState(() {
          _emergencies.removeWhere((e) => e['emergency_id'] == emergencyId);
        });
        _fetchHistory();
        _snack(_isMm ? 'ကယ်ဆယ်ရေး တာဝန် အောင်မြင်စွာ ပြီးစီးပါပြီ' : 'Mission Completed. Record archived.', AppTheme.secondaryGreen);
      }
    } catch (e) {
      _snack(_isMm ? 'တာဝန်ပြီးစီးမှု သတ်မှတ်ရန် မအောင်မြင်ပါ' : 'Failed to complete emergency', Colors.red);
    }
  }

  Future<void> _assignVolunteerModal(Map<String, dynamic> emergency) async {
    final eid = (emergency['emergency_id'] ?? emergency['id'] ?? '').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_volunteers.isEmpty) {
      await _fetchVolunteers();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryRed),
            const SizedBox(width: 10),
            Text(_isMm ? 'စေတနာ့ဝန်ထမ်း တာဝန်ပေးအပ်ခြင်း' : 'Assign First Responder', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _volunteers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_isMm ? 'မှတ်ပုံတင်ထားသော စေတနာ့ဝန်ထမ်း မရှိသေးပါ' : 'No registered volunteers found for your organization.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _volunteers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final v = _volunteers[i];
                    final vid = (v['account_id'] ?? v['id'] ?? '').toString();
                    final vName = v['full_name'] ?? (_isMm ? 'စေတနာ့ဝန်ထမ်း' : 'Volunteer');
                    final vPhone = v['phone_number'] ?? '';
                    final isActive = v['is_active'] == true;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                        child: Icon(Icons.person, color: isActive ? Colors.green.shade800 : Colors.grey),
                      ),
                      title: Text(vName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(vPhone, style: const TextStyle(fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await ApiService().assignEmergencyToVolunteer(eid, vid);
                            _snack(_isMm ? '$vName အား အောင်မြင်စွာ တာဝန်ပေးအပ်ပြီးပါပြီ' : 'Assigned to $vName successfully!', AppTheme.secondaryGreen);
                            if (mounted) {
                              setState(() {
                                final idx = _emergencies.indexWhere((em) => (em['emergency_id'] ?? em['id'])?.toString() == eid);
                                if (idx != -1) {
                                  _emergencies[idx]['status'] = 'accepted';
                                  _emergencies[idx]['assigned_volunteer_id'] = vid;
                                  _emergencies[idx]['assigned_volunteer_name'] = vName;
                                }
                              });
                            }
                            _fetchEmergencies(silent: true);
                          } catch (_) {
                            _snack(_isMm ? 'စေတနာ့ဝန်ထမ်း တာဝန်ပေးရန် မအောင်မြင်ပါ' : 'Failed to assign volunteer', Colors.red);
                          }
                        },
                        child: Text(_isMm ? 'တာဝန်ပေး' : 'ASSIGN', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'CANCEL')),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(' ', '').replaceAll('-', '');
    final Uri uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COVERAGE & PROFILE SAVE ACTION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveOrganizationProfile() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');

    if (name.isEmpty) {
      _snack(_isMm ? 'အဖွဲ့အစည်း အမည် ထည့်သွင်းရန် လိုအပ်ပါသည်' : 'Organization name is required', Colors.red);
      return;
    }

    if (phone.isNotEmpty && !RegExp(r'^(?:\+959|09)\d{7,10}$').hasMatch(phone)) {
      _snack(_isMm ? 'ဖုန်းနံပါတ် မမှန်ကန်ပါ (+959 သို့မဟုတ် 09 ဖြင့် စတင်ပါ)' : 'Invalid phone format (must start with +959 or 09)', Colors.red);
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && (!email.contains('@') || !email.contains('.'))) {
      _snack(_isMm ? 'မှန်ကန်သော အီးမေးလ်လိပ်စာ ထည့်သွင်းပါ' : 'Please enter a valid email address', Colors.red);
      return;
    }

    setState(() => _savingProfile = true);

    final payload = <String, dynamic>{
      'org_name': name,
      'full_name': name,
      'phone_number': phone,
      if (email.isNotEmpty) 'email': email,
      'category': _selectedCategory,
      'operating_regions': _regionsCtrl.text.trim(),
      'headquarters_address': _addressCtrl.text.trim(),
      'registration_number': _regNumCtrl.text.trim(),
      'coverage_radius_km': _coverageRadiusKm,
    };

    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat != null && lng != null) {
      payload['location_lat'] = lat;
      payload['location_lng'] = lng;
    }

    try {
      await ApiService().updateProfile(payload);
      _snack(_isMm ? '✅ အဖွဲ့အစည်း အချက်အလက်နှင့် လွှမ်းခြုံဧရိယာ (${_coverageRadiusKm.toStringAsFixed(1)} KM) အောင်မြင်စွာ သိမ်းဆည်းပြီးပါပြီ' : '✅ Coverage & Profile updated! Radius: ${_coverageRadiusKm.toStringAsFixed(1)} KM is active for SOS routing.', AppTheme.secondaryGreen);
      setState(() => _savingProfile = false);
      _fetchOrgProfile();
    } catch (e) {
      setState(() => _savingProfile = false);
      _snack(_isMm ? 'အချက်အလက် သိမ်းဆည်းရန် မအောင်မြင်ပါ' : 'Failed to update organization profile', Colors.red);
    }
  }

  Future<void> _pickLocationOnMap() async {
    double? initLat = double.tryParse(_latCtrl.text);
    double? initLng = double.tryParse(_lngCtrl.text);
    LatLng pickedPoint = LatLng(initLat ?? 16.8661, initLng ?? 96.1951);
    final mapController = MapController();

    if (initLat == null || initLng == null) {
      try {
        final pos = await LocationService.getCurrentLocation();
        pickedPoint = LatLng(pos.latitude, pos.longitude);
      } catch (_) {}
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMapState) => Dialog(
          backgroundColor: dialogBg,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_drop, color: AppTheme.primaryRed, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📍 Lat: ${pickedPoint.latitude.toStringAsFixed(5)}, Lng: ${pickedPoint.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: pickedPoint,
                      initialZoom: 13.5,
                      onTap: (tapPos, latLng) {
                        setMapState(() => pickedPoint = latLng);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.khunyikalsal.emergency',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: pickedPoint,
                            radius: _coverageRadiusKm * 1000,
                            useRadiusInMeter: true,
                            color: AppTheme.primaryRed.withValues(alpha: 0.15),
                            borderColor: AppTheme.primaryRed,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickedPoint,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppTheme.primaryRed,
                              size: 46,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('SET LOCATION'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _latCtrl.text = pickedPoint.latitude.toStringAsFixed(6);
                              _lngCtrl.text = pickedPoint.longitude.toStringAsFixed(6);
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD & BOTTOM NAVIGATION
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    final pendingCount = _emergencies.where((e) => e['status'] != 'accepted').length;
    final activeCount = _emergencies.where((e) => e['status'] == 'accepted').length;
    final pendingBloodCount = _bloodDonations.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'pending').length;

    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded, color: AppTheme.primaryRed, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (isMm ? 'အဖွဲ့အစည်း ကွပ်ကဲရေး' : 'ORGANIZATION CONSOLE'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    _getTabSubtitle(isMm),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildSosRadarTab(),
          _buildBloodHubTab(),
          _buildVolunteersTab(),
          _buildCoverageSettingsTab(),
          _buildOrgServicesTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: borderCol, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.radar_outlined,
                  activeIcon: Icons.radar_rounded,
                  label: isMm ? 'အရေးပေါ်' : 'SOS Radar',
                  badgeCount: (pendingCount + activeCount) > 0 ? (pendingCount + activeCount) : null,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.water_drop_outlined,
                  activeIcon: Icons.water_drop_rounded,
                  label: isMm ? 'သွေးလှူဒါန်း' : 'Blood Hub',
                  badgeCount: pendingBloodCount > 0 ? pendingBloodCount : null,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_alt_rounded,
                  label: isMm ? 'စေတနာ့ဝန်ထမ်း' : 'Volunteers',
                  badgeCount: _volunteers.isNotEmpty ? _volunteers.length : null,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.tune_outlined,
                  activeIcon: Icons.tune_rounded,
                  label: isMm ? 'ဧရိယာ' : 'Coverage',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                  label: isMm ? 'ဝန်ဆောင်မှု' : 'Services',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _currentTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppTheme.primaryRed;
    final inactiveColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badgeCount != null && badgeCount > 0,
                label: Text('$badgeCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: AppTheme.primaryRed,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTabSubtitle(bool isMm) {
    switch (_currentTabIndex) {
      case 0:
        return isMm ? 'တိုက်ရိုက် SOS အရေးပေါ် ခေါ်ဆိုမှုများ' : 'Live SOS Emergency Radar & Dispatch';
      case 1:
        return isMm ? 'သွေးလှူဒါန်းမှု စီမံခန့်ခွဲရေးစင်တာ' : 'Emergency Blood Donation & Supply Hub';
      case 2:
        return isMm ? 'ကယ်ဆယ်ရေး စေတနာ့ဝန်ထမ်း အဖွဲ့ဝင်များ' : 'First Responder & Volunteer Force';
      case 3:
        return isMm ? 'ကာကွယ်စောင့်ရှောက်မှု ဧရိယာ သတ်မှတ်ခြင်း' : 'Coverage Radius & Area Settings';
      case 4:
        return isMm ? 'အကောင့်၊ ဘာသာစကားနှင့် ဆက်တင်များ' : 'Profile, Settings & Security';
      default:
        return isMm ? 'ကွပ်ကဲရေးစင်တာ' : 'Command Console';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0: SOS RADAR & DISPATCH
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSosRadarTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    final pending = _emergencies.where((e) => e['status'] != 'accepted').toList();
    final active = _emergencies.where((e) => e['status'] == 'accepted').toList();
    final completed = _history.where((h) => h['status'] == 'completed').toList();

    List<Map<String, dynamic>> displayedList;
    if (_sosSubTab == 1) {
      displayedList = _history;
    } else {
      if (_selectedSosFilter == 'PENDING') {
        displayedList = pending;
      } else if (_selectedSosFilter == 'ACTIVE') {
        displayedList = active;
      } else {
        displayedList = _emergencies;
      }
    }

    // Type filter
    if (_selectedSosType != 'ALL') {
      displayedList = displayedList.where((e) {
        final t = (e['type'] ?? '').toString().toUpperCase();
        return t == _selectedSosType;
      }).toList();
    }

    // Search filter
    if (_sosSearchQuery.isNotEmpty) {
      final q = _sosSearchQuery.toLowerCase();
      displayedList = displayedList.where((e) {
        final u = e['user_info'] as Map<String, dynamic>? ?? {};
        final name = (u['full_name'] ?? '').toString().toLowerCase();
        final phone = (u['phone_number'] ?? '').toString().toLowerCase();
        final type = (e['type'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || type.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // ── Stat Boxes Row ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statBox(
                  isMm ? 'စောင့်ဆိုင်းဆဲ' : 'PENDING',
                  '${pending.length}',
                  const Color(0xFFF59E0B),
                  isSelected: _sosSubTab == 0 && _selectedSosFilter == 'PENDING',
                  onTap: () => setState(() {
                    _sosSubTab = 0;
                    _selectedSosFilter = _selectedSosFilter == 'PENDING' ? 'ALL' : 'PENDING';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  isMm ? 'လက်ခံပြီး' : 'ACTIVE',
                  '${active.length}',
                  AppTheme.primaryRed,
                  isSelected: _sosSubTab == 0 && _selectedSosFilter == 'ACTIVE',
                  onTap: () => setState(() {
                    _sosSubTab = 0;
                    _selectedSosFilter = _selectedSosFilter == 'ACTIVE' ? 'ALL' : 'ACTIVE';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  isMm ? 'မှတ်တမ်း' : 'HISTORY',
                  '${completed.length}',
                  const Color(0xFF06B6D4),
                  isSelected: _sosSubTab == 1,
                  onTap: () => setState(() {
                    _sosSubTab = 1;
                    _selectedSosFilter = 'ALL';
                  }),
                ),
              ),
            ],
          ),
        ),

        // ── Sub Tab Toggle (Live vs History) ───────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _sosSubTab = 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _sosSubTab == 0 ? AppTheme.primaryRed : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isMm ? 'တိုက်ရိုက် ခေါ်ဆိုမှု (${_emergencies.length})' : 'Live Calls (${_emergencies.length})',
                        style: TextStyle(
                          color: _sosSubTab == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _sosSubTab = 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _sosSubTab == 1 ? AppTheme.primaryRed : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isMm ? 'ကယ်ဆယ်ရေး မှတ်တမ်း (${_history.length})' : 'Mission History (${_history.length})',
                        style: TextStyle(
                          color: _sosSubTab == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Search Field ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _sosSearchCtrl,
            decoration: InputDecoration(
              hintText: isMm ? 'လူနာအမည်၊ ဖုန်းနံပါတ်၊ အမျိုးအစား ရှာရန်...' : 'Search victim, phone number, type...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _sosSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _sosSearchCtrl.clear();
                        setState(() => _sosSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _sosSearchQuery = val.trim()),
          ),
        ),

        // ── Filter Chips ───────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _typeChip('ALL', isMm ? 'အားလုံး' : 'All Types', Icons.all_inclusive),
              const SizedBox(width: 6),
              _typeChip('FIRE', isMm ? 'မီးလောင်မှု' : 'Fire', Icons.local_fire_department, const Color(0xFFFF6B35)),
              const SizedBox(width: 6),
              _typeChip('MEDICAL', isMm ? 'ဆေးဘက်ဆိုင်ရာ' : 'Medical', Icons.medical_services, AppTheme.primaryRed),
              const SizedBox(width: 6),
              _typeChip('ACCIDENT', isMm ? 'ယာဉ်တိုက်မှု' : 'Accident', Icons.car_crash, const Color(0xFFE65100)),
              const SizedBox(width: 6),
              _typeChip('NATURAL_DISASTER', isMm ? 'သဘာဝဘေး' : 'Disaster', Icons.flood, const Color(0xFF00897B)),
            ],
          ),
        ),

        // ── Cards List ─────────────────────────────────────────────────
        Expanded(
          child: _loadingEmergencies || (_sosSubTab == 1 && _loadingHistory)
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : displayedList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _sosSubTab == 1 ? Icons.history_rounded : Icons.radar_outlined,
                            size: 56,
                            color: isDark ? Colors.white30 : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _sosSubTab == 1
                                ? (isMm ? 'ကယ်ဆယ်ရေး မှတ်တမ်း မရှိသေးပါ' : 'No mission history records')
                                : (isMm ? 'လက်ရှိ အရေးပေါ် ခေါ်ဆိုမှု မရှိပါ' : 'No emergency calls in this view'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMm
                                ? 'မိမိတို့၏ ${_coverageRadiusKm.toStringAsFixed(0)} ကီလိုမီတာ ပတ်လည်မှ အရေးပေါ်ခေါ်ဆိုမှုများ ဤနေရာတွင် တိုက်ရိုက်ပေါ်လာပါမည်။'
                                : 'Incoming alerts within your ${_coverageRadiusKm.toStringAsFixed(0)} KM radius will ping here in real time.',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _sosSubTab == 1 ? _fetchHistory : () => _fetchEmergencies(),
                      color: AppTheme.primaryRed,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: displayedList.length,
                        itemBuilder: (_, i) => _buildEmergencyCard(displayedList[i], isHistory: _sosSubTab == 1),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _typeChip(String typeKey, String label, IconData icon, [Color? color]) {
    final isSelected = _selectedSosType == typeKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? AppTheme.primaryRed;

    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : accent),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      selectedColor: accent,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => setState(() => _selectedSosType = typeKey),
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> e, {bool isHistory = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    final info = e['user_info'] as Map<String, dynamic>? ?? {};
    final typeStr = (e['type'] ?? 'EMERGENCY').toString().toUpperCase();
    final status = (e['status'] ?? 'pending').toString().toLowerCase();
    final eid = (e['emergency_id'] ?? e['id'] ?? '').toString();
    final phone = info['phone_number'] ?? '';
    final isCompleted = status == 'completed';
    final hasAssignedVolunteer = (e['assigned_volunteer_id'] != null &&
            e['assigned_volunteer_id'].toString().isNotEmpty &&
            e['assigned_volunteer_id'].toString() != 'null') ||
        (e['assigned_volunteer_name'] != null &&
            e['assigned_volunteer_name'].toString().isNotEmpty &&
            e['assigned_volunteer_name'].toString() != 'null');
    final assignedVolunteerName = (e['assigned_volunteer_name'] ?? (isMm ? 'စေတနာ့ဝန်ထမ်း' : 'Volunteer')).toString();
    final isAccepted = status == 'accepted' || hasAssignedVolunteer;

    Color accentColor = const Color(0xFF3B82F6);
    IconData icon = Icons.shield;
    String typeLabel = typeStr;
    if (typeStr.contains('FIRE')) {
      accentColor = const Color(0xFFFF6B35);
      icon = Icons.local_fire_department;
      typeLabel = isMm ? 'မီးလောင်မှု' : 'FIRE';
    } else if (typeStr.contains('MEDIC')) {
      accentColor = AppTheme.primaryRed;
      icon = Icons.medical_services;
      typeLabel = isMm ? 'ဆေးဘက်ဆိုင်ရာ' : 'MEDICAL';
    } else if (typeStr.contains('ACCIDENT')) {
      accentColor = const Color(0xFFE65100);
      icon = Icons.car_crash_rounded;
      typeLabel = isMm ? 'ယာဉ်တိုက်မှု' : 'ACCIDENT';
    } else if (typeStr.contains('DISASTER')) {
      accentColor = const Color(0xFF00897B);
      icon = Icons.flood_rounded;
      typeLabel = isMm ? 'သဘာဝဘေး' : 'NATURAL DISASTER';
    }

    final lat = (e['location']?['lat'] ?? e['location_lat'] as num?)?.toDouble();
    final lng = (e['location']?['lng'] ?? e['location_lng'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAccepted ? AppTheme.primaryRed : (isCompleted ? AppTheme.secondaryGreen : cardBorder),
          width: isAccepted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm ? '$typeLabel အရေးပေါ်' : '$typeLabel EMERGENCY',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (e['created_at'] != null)
                        Text(
                          DateFormat('MMM d, y • hh:mm a').format(DateTime.tryParse(e['created_at'])?.toLocal() ?? DateTime.now()),
                          style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.secondaryGreen
                        : (isAccepted ? AppTheme.primaryRed : Colors.orange),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCompleted
                        ? (isMm ? 'ပြီးစီး' : 'COMPLETED')
                        : (hasAssignedVolunteer
                            ? (isMm ? 'ကယ်ဆယ်ဆဲ' : 'ACTIVE RESCUE')
                            : (isAccepted ? (isMm ? 'တာဝန်ပို့ပြီး' : 'DISPATCHED') : (isMm ? 'စောင့်ဆိုင်းဆဲ' : status.toUpperCase()))),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      info['full_name'] ?? (isMm ? 'အကူအညီတောင်းခံသူ' : 'Citizen Victim'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    if (info['blood_type'] != null && info['blood_type'] != 'Unknown')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          isMm ? 'သွေး: ${info['blood_type']}' : 'Blood: ${info['blood_type']}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                        ),
                      ),
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(phone, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
                if (info['medical_conditions'] != null && info['medical_conditions'] != 'None') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.medical_information, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isMm ? 'ရောဂါအခြေအနေ: ${info['medical_conditions']}' : 'Condition: ${info['medical_conditions']}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Assigned Volunteer status strip
                if (hasAssignedVolunteer) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGreen.withValues(alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_run_rounded, size: 16, color: AppTheme.secondaryGreen),
                        const SizedBox(width: 6),
                        Text(
                          isMm ? 'တာဝန်ကျ ကယ်ဆယ်ရေး: ' : 'Responder: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            assignedVolunteerName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.secondaryGreen,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Action Buttons Row
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      SizedBox(
                        height: 42,
                        width: 42,
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.call, color: AppTheme.secondaryGreen, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: isMm ? 'ခေါ်ဆိုမည် ($phone)' : 'Call Victim ($phone)',
                          onPressed: () => _makeCall(phone),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (lat != null && lng != null) ...[
                      SizedBox(
                        height: 42,
                        width: 42,
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.map_rounded, color: Colors.blue, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: isMm ? 'မြေပုံကြည့်မည်' : 'View Target on Map',
                          onPressed: () {
                            context.push('/mission-map', extra: {
                              'lat': lat,
                              'lng': lng,
                              'title': isMm ? '$typeLabel အရေးပေါ်: ${info['full_name'] ?? 'လူနာ'}' : '$typeStr Emergency: ${info['full_name'] ?? 'Victim'}',
                              'returnRoute': '/org-dashboard',
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!isHistory && !isCompleted) ...[
                      if (hasAssignedVolunteer) ...[
                        // Volunteer already accepted / assigned: Only COMPLETE button is needed
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_rounded, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isMm ? 'တာဝန်ပြီးစီးသတ်မှတ်မည်' : 'COMPLETE MISSION',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 1.5,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _completeEmergency(eid),
                            ),
                          ),
                        ),
                      ] else ...[
                        // No volunteer assigned yet: Org can ASSIGN VOLUNTEER or COMPLETE directly (or dismiss)
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isMm ? 'တာဝန်ပေးမည်' : 'ASSIGN VOLUNTEER',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryRed,
                                side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _assignVolunteerModal(e),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isMm ? 'ပြီးစီး' : 'COMPLETE',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 1,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _completeEmergency(eid),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 42,
                          width: 42,
                          child: IconButton.outlined(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                            style: IconButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            tooltip: isMm ? 'ပယ်ဖျက် / အခြားသို့လွှဲမည်' : 'Dismiss / Reroute Call',
                            onPressed: () => _respond(eid, 'reject'),
                          ),
                        ),
                      ],
                    ] else if (isCompleted) ...[
                      Expanded(
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.secondaryGreen),
                              const SizedBox(width: 6),
                              Text(
                                isMm ? 'တာဝန်ပြီးစီးကြောင်း မှတ်တမ်းတင်ပြီး' : 'MISSION COMPLETED',
                                style: const TextStyle(
                                  color: AppTheme.secondaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: BLOOD REQUESTS HUB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBloodHubTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final pending = _bloodDonations.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'pending').toList();
    final accepted = _bloodDonations.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'accepted').toList();
    final completed = _bloodDonations.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'completed').toList();

    List<Map<String, dynamic>> filteredList = _bloodDonations;
    if (_selectedBloodFilter == 'PENDING') {
      filteredList = pending;
    } else if (_selectedBloodFilter == 'ACCEPTED') {
      filteredList = accepted;
    } else if (_selectedBloodFilter == 'COMPLETED') {
      filteredList = completed;
    }

    if (_bloodSearchQuery.isNotEmpty) {
      final q = _bloodSearchQuery.toLowerCase();
      filteredList = filteredList.where((b) {
        final donor = (b['donor_name'] ?? '').toString().toLowerCase();
        final patient = (b['patient_name'] ?? '').toString().toLowerCase();
        final bType = (b['blood_type'] ?? '').toString().toLowerCase();
        final hosp = (b['hospital_name'] ?? b['target_location_name'] ?? '').toString().toLowerCase();
        return donor.contains(q) || patient.contains(q) || bType.contains(q) || hosp.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // Stat counters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statBox(
                  'PENDING',
                  '${pending.length}',
                  Colors.orange,
                  isSelected: _selectedBloodFilter == 'PENDING',
                  onTap: () => setState(() => _selectedBloodFilter = _selectedBloodFilter == 'PENDING' ? 'ALL' : 'PENDING'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  'SCHEDULED',
                  '${accepted.length}',
                  AppTheme.secondaryGreen,
                  isSelected: _selectedBloodFilter == 'ACCEPTED',
                  onTap: () => setState(() => _selectedBloodFilter = _selectedBloodFilter == 'ACCEPTED' ? 'ALL' : 'ACCEPTED'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  'COMPLETED',
                  '${completed.length}',
                  Colors.blue,
                  isSelected: _selectedBloodFilter == 'COMPLETED',
                  onTap: () => setState(() => _selectedBloodFilter = _selectedBloodFilter == 'COMPLETED' ? 'ALL' : 'COMPLETED'),
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _bloodSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search donor, patient, blood type or hospital...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _bloodSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _bloodSearchCtrl.clear();
                        setState(() => _bloodSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _bloodSearchQuery = val.trim()),
          ),
        ),

        // List
        Expanded(
          child: _loadingBlood
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.water_drop_outlined, size: 56, color: isDark ? Colors.white30 : Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No blood donation records', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          Text('Incoming blood donation pledges will appear here.', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBloodDonations,
                      color: AppTheme.primaryRed,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filteredList.length,
                        itemBuilder: (_, i) => _buildBloodDonationCard(filteredList[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildBloodDonationCard(Map<String, dynamic> d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;

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
    final hospital = d['hospital_name'] ?? d['target_location_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRequest
              ? (isAccepted ? AppTheme.secondaryGreen : Colors.red.shade300)
              : (isPending ? Colors.orange.shade300 : cardBorder),
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    bloodType,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryRed, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRequest ? 'BLOOD SUPPLY REQUEST' : 'DONATION PLEDGE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: isRequest ? Colors.red.shade700 : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                      Text(
                        isRequest ? 'Patient: ${patientName ?? donorName} ($units Units)' : 'Donor: $donorName ($units Units)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAccepted ? AppTheme.secondaryGreen : (isPending ? Colors.orange : Colors.blue),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAccepted ? 'SCHEDULED' : status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (phone.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(phone, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRequest ? 'Hospital: $hospital' : 'Preferred Date: $preferredDate',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (isAccepted && (apptDate != null || apptLoc != null)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  '📅 Appointment: ${apptDate ?? 'Confirmed'} at ${apptLoc ?? 'Center'}',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (phone.isNotEmpty)
                  IconButton.filledTonal(
                    icon: const Icon(Icons.call, color: AppTheme.secondaryGreen, size: 18),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.15)),
                    onPressed: () => _makeCall(phone),
                  ),
                const SizedBox(width: 8),
                if (isPending)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: const Text('ACCEPT & SCHEDULE APPOINTMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openScheduleAppointmentModal(d),
                    ),
                  )
                else if (isAccepted)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.done_all, size: 16, color: Colors.blue),
                      label: Text(_isMm ? 'ပြီးစီးကြောင်း သတ်မှတ်မည်' : 'MARK FULFILLED / COMPLETED', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        await ApiService().updateBloodDonationStatus(id, 'Completed');
                        _fetchBloodDonations(silent: true);
                        _snack(_isMm ? 'သွေးမှတ်တမ်း ပြီးစီးကြောင်း သတ်မှတ်ပြီးပါပြီ' : 'Blood record marked as completed!', AppTheme.secondaryGreen);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openScheduleAppointmentModal(Map<String, dynamic> donation) {
    final reqType = (donation['request_type'] ?? 'donate').toString().toLowerCase();
    final isRequest = reqType == 'request';
    final dateCtrl = TextEditingController(text: 'Tomorrow at 10:00 AM');
    final locCtrl = TextEditingController(text: 'Blood Donation Center, Main Hospital Wing Room 102');
    final notesCtrl = TextEditingController(text: 'Please bring your NRC / ID card and arrive 15 minutes early.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isRequest ? (_isMm ? 'သွေးထောက်ပံ့မှု ပေးအပ်မည်' : 'Provide Blood Supply') : (_isMm ? 'သွေးလှူဒါန်းမှု အတည်ပြုမည်' : 'Confirm Blood Donation'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locCtrl,
                decoration: InputDecoration(
                  labelText: _isMm ? 'ရက်ချိန်း နေရာ / ဌာန' : 'Appointment Location / Counter',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateCtrl,
                decoration: InputDecoration(
                  labelText: _isMm ? 'ရက်စွဲနှင့် အချိန်' : 'Date & Time',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _isMm ? 'ညွှန်ကြားချက် / မှတ်ချက်' : 'Instructions / Notes',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
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
                  _fetchBloodDonations(silent: true);
                  _snack(_isMm ? 'ရက်ချိန်း အတည်ပြုပြီး အသုံးပြုသူထံ အကြောင်းကြားလိုက်ပါပြီ' : 'Appointment confirmed and sent to user!', AppTheme.secondaryGreen);
                } catch (_) {
                  _snack(_isMm ? 'ရက်ချိန်း သတ်မှတ်ရန် မအောင်မြင်ပါ' : 'Failed to schedule appointment', Colors.red);
                }
              }
            },
            child: Text(_isMm ? 'အတည်ပြုပြီး အကြောင်းကြားမည်' : 'CONFIRM & NOTIFY'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: VOLUNTEERS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildVolunteersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final onlineVolunteers = _volunteers.where((v) => v['is_active'] == true).length;

    List<Map<String, dynamic>> filteredList = _volunteers;
    if (_volunteerSearchQuery.isNotEmpty) {
      final q = _volunteerSearchQuery.toLowerCase();
      filteredList = filteredList.where((v) {
        final name = (v['full_name'] ?? '').toString().toLowerCase();
        final phone = (v['phone_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // Header stats & Add Volunteer button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statBox('TOTAL SQUAD', '${_volunteers.length}', Colors.deepPurple),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('ACTIVE ON DUTY', '$onlineVolunteers', AppTheme.secondaryGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('STANDBY', '${_volunteers.length - onlineVolunteers}', Colors.grey),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'First Responders Team (${_volunteers.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('ADD VOLUNTEER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openAddVolunteerDialog,
              ),
            ],
          ),
        ),

        // Search Volunteer Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _volunteerSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search volunteer name or phone...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _volunteerSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _volunteerSearchCtrl.clear();
                        setState(() => _volunteerSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _volunteerSearchQuery = val.trim()),
          ),
        ),

        // Volunteers List
        Expanded(
          child: _loadingVolunteers
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 56, color: isDark ? Colors.white30 : Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No volunteers in your team yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          const Text('Tap "+ ADD VOLUNTEER" above to recruit responders.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchVolunteers,
                      color: AppTheme.primaryRed,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filteredList.length,
                        itemBuilder: (_, i) {
                          final v = filteredList[i];
                          final id = v['account_id'] ?? v['id'] ?? '';
                          final name = v['full_name'] ?? 'Volunteer';
                          final phone = v['phone_number'] ?? '';
                          final isActive = v['is_active'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isActive ? Colors.green.withValues(alpha: 0.4) : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                                  child: Icon(Icons.person, color: isActive ? Colors.green.shade800 : Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(phone.isNotEmpty ? phone : 'No phone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                if (phone.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.call, color: AppTheme.secondaryGreen, size: 20),
                                    onPressed: () => _makeCall(phone),
                                  ),
                                Switch(
                                  value: isActive,
                                  activeThumbColor: AppTheme.secondaryGreen,
                                  onChanged: (_) async {
                                    await ApiService().toggleVolunteerStatus(id);
                                    _fetchVolunteers();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _openAddVolunteerDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isMm ? 'စေတနာ့ဝန်ထမ်း အကောင့် အသစ်ဖွင့်မည်' : 'Add New Volunteer', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: _isMm ? 'အမည် အပြည့်အစုံ' : 'Full Name')),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, decoration: InputDecoration(labelText: _isMm ? 'အီးမေးလ် လိပ်စာ' : 'Email Address')),
              const SizedBox(height: 10),
              TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(labelText: _isMm ? 'လျှို့ဝှက်နံပါတ် (အနည်းဆုံး ၆ လုံး)' : 'Password (min 6 chars)')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: _isMm ? 'ဖုန်းနံပါတ် (+959...)' : 'Phone Number (+959...)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
            onPressed: () async {
              if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                _snack(_isMm ? 'လိုအပ်သော အချက်အလက်များ အားလုံး ဖြည့်သွင်းပါ' : 'Please fill in all required fields', Colors.red);
                return;
              }
              try {
                await ApiService().createVolunteer({
                  'email': emailCtrl.text.trim(),
                  'password': passCtrl.text,
                  'full_name': nameCtrl.text.trim(),
                  'phone_number': phoneCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchVolunteers();
                _snack(_isMm ? 'စေတနာ့ဝန်ထမ်း အကောင့် အသစ် ထည့်သွင်းပြီးပါပြီ' : 'Volunteer added to your team!', AppTheme.secondaryGreen);
              } catch (_) {
                _snack(_isMm ? 'စေတနာ့ဝန်ထမ်း အကောင့် ဖွင့်ရန် မအောင်မြင်ပါ' : 'Failed to create volunteer account', Colors.red);
              }
            },
            child: Text(_isMm ? 'အကောင့်ဖွင့်မည်' : 'CREATE'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: COVERAGE & ORGANIZATION SETTINGS (CORE REQUIREMENT)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCoverageSettingsTab() {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final coverageAreaSqKm = math.pi * _coverageRadiusKm * _coverageRadiusKm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SOS Dispatch Impact Callout Banner ───────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF7F1D1D).withValues(alpha: 0.4), const Color(0xFF1E293B)]
                    : [Colors.red.shade50, Colors.orange.shade50],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar_rounded, color: AppTheme.primaryRed, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm ? 'တိုက်ရိုက် SOS တည်နေရာ လွှမ်းခြုံမှု' : 'Live SOS Geolocation Coverage',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryRed),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isMm
                            ? 'မိမိတို့၏ လွှမ်းခြုံဧရိယာ (${_coverageRadiusKm.toStringAsFixed(1)} ကီလိုမီတာ) အတွင်း ပြည်သူများမှ အရေးပေါ် SOS ခေါ်ဆိုပါက စနစ်မှ တိုက်ရိုက် ဦးစားပေး ချိတ်ဆက်ပေးပါမည်။'
                            : 'When citizens trigger SOS alerts within your coverage radius (${_coverageRadiusKm.toStringAsFixed(1)} KM), our geolocation dispatcher prioritizes and routes the emergency directly to your command console.',
                        style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Interactive Coverage Radius Card ─────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMm ? 'ကူညီနိုင်သော အကွာအဝေး (ကီလိုမီတာ)' : 'Coverage Radius (KM)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_coverageRadiusKm.toStringAsFixed(1)} KM',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isMm
                      ? 'စုစုပေါင်း ကာကွယ်မှုဇုန် - ရုံးချုပ်ပတ်လည် ~${coverageAreaSqKm.toStringAsFixed(0)} စတုရန်းကီလိုမီတာ'
                      : 'Total Protected Zone: ~${coverageAreaSqKm.toStringAsFixed(0)} sq km around headquarters',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 16),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryRed,
                    thumbColor: AppTheme.primaryRed,
                    overlayColor: AppTheme.primaryRed.withValues(alpha: 0.2),
                    valueIndicatorColor: AppTheme.primaryRed,
                  ),
                  child: Slider(
                    value: _coverageRadiusKm,
                    min: 5.0,
                    max: 100.0,
                    divisions: 19,
                    label: '${_coverageRadiusKm.toStringAsFixed(0)} KM',
                    onChanged: (val) {
                      setState(() {
                        _coverageRadiusKm = val;
                        _radiusCtrl.text = val.toStringAsFixed(1);
                      });
                    },
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isMm ? '၅ ကီလိုမီတာ (ရပ်ကွက်)' : '5 KM (Local Hub)', style: TextStyle(fontSize: 11, color: textSecondary)),
                    Text(isMm ? '၅၀ ကီလိုမီတာ (မြို့နယ်)' : '50 KM (City)', style: TextStyle(fontSize: 11, color: textSecondary)),
                    Text(isMm ? '၁၀၀ ကီလိုမီတာ (တိုင်းဒေသ)' : '100 KM (Regional)', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Headquarters Base GPS Coordinates ────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMm ? 'ရုံးချုပ် အခြေစိုက် GPS တည်နေရာ' : 'Base GPS Coordinates',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  isMm ? 'အရေးပေါ် ကွပ်ကဲရေးစခန်း၏ တိကျသော လတ္တီတွဒ်နှင့် လောင်ဂျီတွဒ်' : 'Exact latitude and longitude of your dispatch station',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isMm ? 'လတ္တီတွဒ် (Latitude)' : 'Latitude',
                          prefixIcon: const Icon(Icons.my_location, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isMm ? 'လောင်ဂျီတွဒ် (Longitude)' : 'Longitude',
                          prefixIcon: const Icon(Icons.location_searching, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.gps_fixed, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isMm ? 'လက်ရှိ GPS သုံးမည်' : 'Use Current GPS',
                            maxLines: 1,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryRed,
                          side: const BorderSide(color: AppTheme.primaryRed),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          try {
                            final pos = await LocationService.getCurrentLocation();
                            setState(() {
                              _latCtrl.text = pos.latitude.toStringAsFixed(6);
                              _lngCtrl.text = pos.longitude.toStringAsFixed(6);
                            });
                            _snack(isMm ? 'လက်ရှိ GPS တည်နေရာ ထည့်သွင်းပြီးပါပြီ' : 'Updated with current GPS coordinates!', AppTheme.secondaryGreen);
                          } catch (_) {
                            _snack(isMm ? 'GPS ရယူရန် မအောင်မြင်ပါ' : 'Failed to fetch GPS coordinates', Colors.red);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isMm ? 'မြေပုံပေါ်တွင် ရွေးမည်' : 'Pick on Map',
                            maxLines: 1,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _pickLocationOnMap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Organization Basic Information ───────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMm ? 'အဖွဲ့အစည်း အချက်အလက်များ' : 'Organization Profile',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: isMm ? 'အဖွဲ့အစည်း အမည်' : 'Organization Name',
                    prefixIcon: const Icon(Icons.business_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isMm ? 'တရားဝင် အီးမေးလ် (Gmail)' : 'Official Email (Gmail)',
                    helperText: isMm ? 'အကောင့်ဝင်ရန်နှင့် အရေးပေါ် မှတ်တမ်းများအတွက် သုံးသည်' : 'Used for login and emergency broadcast records',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isMm ? 'အရေးပေါ် ဖုန်းနံပါတ်' : 'Hotline Phone Number',
                    helperText: isMm ? '+959 သို့မဟုတ် 09 ဖြင့် စတင်ရပါမည် (ဥပမာ 09123456789)' : 'Must start with +959 or 09 (e.g. 09123456789)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: isMm ? 'အဖွဲ့အစည်း အမျိုးအစား' : 'Organization Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'Medical', child: Text(isMm ? 'ဆေးဘက်ဆိုင်ရာနှင့် လူနာတင်ယာဉ်' : 'Medical & Ambulance')),
                    DropdownMenuItem(value: 'Fire', child: Text(isMm ? 'မီးသတ်နှင့် သဘာဝဘေး ကယ်ဆယ်ရေး' : 'Fire & Disaster Rescue')),
                    DropdownMenuItem(value: 'Local Voluntary Org', child: Text(isMm ? 'ဒေသခံ ပရဟိတ လူမှုကူညီရေးအသင်း' : 'Local Voluntary Org')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: isMm ? 'ရုံးချုပ် လိပ်စာ' : 'Headquarters Address',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _regionsCtrl,
                  decoration: InputDecoration(
                    labelText: isMm ? 'တာဝန်ထမ်းဆောင်သည့် မြို့နယ် / ဒေသများ' : 'Operating Regions / Townships',
                    helperText: isMm ? 'ဥပမာ - ကမာရွတ်၊ လှည်းတန်း၊ စမ်းချောင်း၊ ဗဟန်း၊ ရန်ကုန်' : 'e.g. Kamaryut, Hledan, Sanchaung, Bahan, Yangon',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _regNumCtrl,
                  decoration: InputDecoration(
                    labelText: isMm ? 'တရားဝင် မှတ်ပုံတင်အမှတ်' : 'Official Registration Number',
                    prefixIcon: const Icon(Icons.verified_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Save Button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _savingProfile
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _savingProfile
                      ? (isMm ? 'သိမ်းဆည်းနေပါသည်...' : 'SAVING...')
                      : (isMm ? 'အချက်အလက် သိမ်းဆည်းမည်' : 'SAVE PROFILE & COVERAGE'),
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _savingProfile ? null : _saveOrganizationProfile,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Stat Box Widget ────────────────────────────────────────────────
  Widget _statBox(
    String label,
    String val,
    Color color, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                val,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 4: SERVICES, PROFILE, SETTINGS & LOGOUT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOrgServicesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    final orgName = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (_orgProfile?['org_name'] ?? 'Rescue Organization');
    final orgEmail = _emailCtrl.text.isNotEmpty ? _emailCtrl.text : (auth.email ?? '');
    final orgPhone = _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : (_orgProfile?['phone_number'] ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Organization Profile Banner ─────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _currentTabIndex = 3), // Navigate to Coverage & Profile tab
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Icon(Icons.shield_rounded, color: AppTheme.primaryRed, size: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                orgName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedCategory.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          orgEmail.isNotEmpty ? orgEmail : (orgPhone.isNotEmpty ? orgPhone : 'Organization Account'),
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                        if (orgPhone.isNotEmpty && orgEmail.isNotEmpty)
                          Text(
                            'Hotline: $orgPhone',
                            style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Quick Organization Actions ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_note_rounded, color: AppTheme.primaryRed, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isMm ? 'အဖွဲ့အချက်အလက် ပြင်မည်' : 'Edit Profile & Email',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.radar_rounded, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_coverageRadiusKm.toStringAsFixed(0)} KM Coverage',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Account & Security ──────────────────────────────────────
          Text(
            isMm ? 'အကောင့်နှင့် လုံခြုံရေး' : 'Account & Security',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardBg,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: isDark ? Colors.amber : Colors.amber.shade900, size: 22),
                  ),
                  title: Text(
                    isMm ? 'စကားဝှက် ပြောင်းလဲရန်' : 'Change Password',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  subtitle: Text(
                    isMm ? 'စကားဝှက်အသစ် သတ်မှတ်ပါ' : 'Set a new secure password',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: textSecondary.withValues(alpha: 0.5), size: 20),
                  onTap: () => context.push('/change-password'),
                ),
                Divider(height: 1, color: cardBorder),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.devices_rounded, color: Colors.blue, size: 22),
                  ),
                  title: Text(
                    isMm ? 'ချိတ်ဆက်ထားသော စက်ပစ္စည်းများ' : 'Logged-in Devices',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  subtitle: Text(
                    isMm ? 'ဝင်ရောက်ထားသော စက်များ စီမံခန့်ခွဲရန်' : 'Manage active login sessions',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: textSecondary.withValues(alpha: 0.5), size: 20),
                  onTap: () => context.push('/settings/devices'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── App Appearance & Theme ──────────────────────────────────
          Text(
            isMm ? 'အသွင်အပြင် (Theme Mode)' : 'Appearance & Theme',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardBg,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  secondary: const Icon(Icons.light_mode_outlined, color: Colors.amber),
                  title: Text(
                    isMm ? 'အလင်းမုဒ် (Light Mode)' : 'Light Mode',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                ),
                Divider(height: 1, color: cardBorder),
                RadioListTile<ThemeMode>(
                  secondary: const Icon(Icons.dark_mode_outlined, color: Colors.indigoAccent),
                  title: Text(
                    isMm ? 'အမှောင်မုဒ် (Dark Mode)' : 'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                ),
                Divider(height: 1, color: cardBorder),
                RadioListTile<ThemeMode>(
                  secondary: Icon(Icons.settings_brightness_outlined, color: textSecondary),
                  title: Text(
                    isMm ? 'စနစ်သုံး မုဒ် (System Default)' : 'System Default',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                  ),
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setThemeMode(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Language Preferences ────────────────────────────────────
          Text(
            isMm ? 'ဘာသာစကား (Language)' : 'Language Preferences',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardBg,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  secondary: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                  title: Text('English', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                  value: 'en',
                  groupValue: settings.locale.languageCode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setLocale(val);
                  },
                ),
                Divider(height: 1, color: cardBorder),
                RadioListTile<String>(
                  secondary: const Text('🇲🇲', style: TextStyle(fontSize: 22)),
                  title: Text('မြန်မာ (Myanmar)', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                  value: 'my',
                  groupValue: settings.locale.languageCode,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (val) {
                    if (val != null) settingsNotifier.setLocale(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Refresh Action ──────────────────────────────────────────
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cardBorder),
            ),
            tileColor: cardBg,
            leading: const Icon(Icons.refresh_rounded, color: AppTheme.primaryRed),
            title: Text(
              isMm ? 'ဒေတာများ ပြန်လည်ရယူရန်' : 'Refresh All System Data',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
            ),
            subtitle: Text(
              isMm ? 'အရေးပေါ်၊ သွေးလှူဒါန်းမှုနှင့် စေတနာ့ဝန်ထမ်း ဒေတာများကို အသစ်ရယူပါ' : 'Reload all organization dispatch and volunteer records',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            onTap: () {
              _fetchAllData();
              _snack('All organization data refreshed', AppTheme.secondaryGreen);
            },
          ),

          const SizedBox(height: 28),

          // ── Logout Button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isMm ? 'အဖွဲ့အစည်း အကောင့်မှ ထွက်မည်' : 'SIGN OUT OF ORGANIZATION',
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _confirmOrgLogout(isMm),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _confirmOrgLogout(bool isMm) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isMm ? 'အဖွဲ့အစည်း အကောင့်မှ ထွက်ခွာမည်လား?' : 'Log Out Organization?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isMm
              ? 'သင်သည် အဖွဲ့အစည်း ကွပ်ကဲရေးစနစ်မှ ထွက်ခွာရန် သေချာပါသလား?'
              : 'Are you sure you want to end your organization command session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isMm ? 'မထွက်ပါ' : 'CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isMm ? 'ထွက်မည်' : 'LOG OUT'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/login');
    }
  }
}
