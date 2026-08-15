import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../providers/settings_provider.dart';

class BloodDonationScreen extends ConsumerStatefulWidget {
  const BloodDonationScreen({super.key});

  @override
  ConsumerState<BloodDonationScreen> createState() => _BloodDonationScreenState();
}

class _BloodDonationScreenState extends ConsumerState<BloodDonationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _medCtrl = TextEditingController();
  final _customLocCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];
  String? _selectedBloodType;
  String? _selectedGender;
  int _units = 1;
  String _preferredDate = 'As soon as possible';

  // Destination mode
  bool _useNearest = true;
  List<Map<String, dynamic>> _nearbyOrgs = [];
  Map<String, dynamic>? _selectedOrg;
  LatLng? _customCoords;

  bool _loadingProfile = true;
  bool _submitting = false;
  bool _loadingHistory = false;
  List<dynamic> _myDonations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _medCtrl.dispose();
    _customLocCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadNearbyOrgs(),
      _loadMyDonations(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    try {
      final res = await ApiService().getProfile();
      if (mounted) {
        final data = res.data;
        final bType = data['blood_type'] as String?;
        setState(() {
          _nameCtrl.text = (data['full_name'] ?? '').toString();
          _phoneCtrl.text = (data['phone_number'] ?? '').toString();
          _medCtrl.text = (data['medical_conditions'] ?? '').toString();
          if (bType != null && _bloodTypes.contains(bType)) {
            _selectedBloodType = bType;
          }
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadNearbyOrgs() async {
    double lat = 16.8661;
    double lng = 96.1951;
    try {
      final pos = await LocationService.getCurrentLocation();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    try {
      final res = await ApiService().getAllOrgs(lat: lat, lng: lng);
      if (mounted) {
        final list = List<Map<String, dynamic>>.from(res.data);
        // Filter or prioritize medical/hospital orgs
        final medicals = list.where((o) {
          final cat = (o['category'] ?? '').toString().toLowerCase();
          final name = (o['org_name'] ?? '').toString().toLowerCase();
          return cat.contains('medical') ||
              name.contains('hospital') ||
              name.contains('ဆေး') ||
              name.contains('blood') ||
              name.contains('သွေး');
        }).toList();

        final displayList = medicals.isNotEmpty ? medicals : list;
        setState(() {
          _nearbyOrgs = displayList;
          if (displayList.isNotEmpty) {
            _selectedOrg = displayList.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMyDonations() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService().getMyBloodDonations();
      if (mounted) {
        setState(() {
          _myDonations = res.data as List;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _pickLocationOnMap() async {
    double initLat = 16.8661;
    double initLng = 96.1951;
    try {
      final pos = await LocationService.getCurrentLocation();
      initLat = pos.latitude;
      initLng = pos.longitude;
    } catch (_) {}

    LatLng pickedPoint = _customCoords ?? LatLng(initLat, initLng);
    final mapController = MapController();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMapState) => Dialog(
          backgroundColor: Colors.white,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pick Blood Donation Center',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
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
                      initialZoom: 14.5,
                      onTap: (tapPosition, point) {
                        setMapState(() {
                          pickedPoint = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.khunyikalsal.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickedPoint,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: AppTheme.primaryRed,
                              size: 44,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('CONFIRM PIN LOCATION',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          setState(() {
                            _customCoords = pickedPoint;
                            if (_customLocCtrl.text.isEmpty) {
                              _customLocCtrl.text =
                                  'Custom Location (${pickedPoint.latitude.toStringAsFixed(4)}, ${pickedPoint.longitude.toStringAsFixed(4)})';
                            }
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _submitDonation() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      _snack('Please fill in Donor Name and Phone Number', Colors.orange);
      return;
    }
    if (_selectedBloodType == null) {
      _snack('Please select your Blood Type', Colors.orange);
      return;
    }

    String locationName = '';
    String? targetOrgId;
    double? lat;
    double? lng;

    if (_useNearest) {
      if (_selectedOrg != null) {
        locationName = _selectedOrg!['org_name'] ?? 'Local Rescue Hospital';
        targetOrgId = _selectedOrg!['account_id'];
        lat = (_selectedOrg!['geo_lat'] as num?)?.toDouble();
        lng = (_selectedOrg!['geo_lng'] as num?)?.toDouble();
      } else {
        locationName = 'Nearest Available Hospital';
      }
    } else {
      locationName = _customLocCtrl.text.trim().isNotEmpty
          ? _customLocCtrl.text.trim()
          : 'Specified Blood Donation Center';
      lat = _customCoords?.latitude;
      lng = _customCoords?.longitude;
    }

    setState(() => _submitting = true);

    try {
      final payload = {
        'donor_name': _nameCtrl.text.trim(),
        'donor_phone': _phoneCtrl.text.trim(),
        'blood_type': _selectedBloodType!,
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _selectedGender,
        'medical_notes': _medCtrl.text.trim().isNotEmpty ? _medCtrl.text.trim() : null,
        'target_org_id': targetOrgId,
        'target_location_name': locationName,
        'target_lat': lat,
        'target_lng': lng,
        'preferred_date': _preferredDate,
        'units': _units,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      await ApiService().createBloodDonation(payload);
      _snack('🎉 Blood donation request submitted successfully!', AppTheme.secondaryGreen);

      await _loadMyDonations();
      if (mounted) {
        setState(() => _submitting = false);
        _tabController.animateTo(1);
      }
    } catch (e) {
      setState(() => _submitting = false);
      _snack('Failed to submit donation request. Please check connection.', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTipsDialog(bool isMm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: AppTheme.primaryRed),
            const SizedBox(width: 10),
            Text(isMm ? 'သွေးမလှူမီ သိကောင်းစရာများ' : 'Blood Donor Preparation Tips',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMm
                    ? '• အသက် (၁၈) မှ (၆၀) နှစ်ကြား ဖြစ်ရမည်။\n'
                      '• ကိုယ်အလေးချိန် အနည်းဆုံး ပေါင် (၁၀၀) / ၄၅ ကီလို ရှိရမည်။\n'
                      '• သွေးမလှူမီ အနည်းဆုံး (၇) နာရီ ကောင်းစွာ အိပ်စက်အနားယူပါ။\n'
                      '• ရေများများ (အနည်းဆုံး ၅၀၀ မီလီလီတာ) သောက်သုံးပါ။\n'
                      '• သွေးမလှူမီ ၂၄ နာရီအတွင်း အရက်သေစာ မသောက်စားပါနှင့်။\n'
                      '• အဆီများသော အစားအစာများ ရှောင်ကြဉ်ပြီး ပေါ့ပါးသော အစာစားပါ။'
                    : '• Age must be between 18 and 60 years old.\n'
                      '• Weight must be at least 45 kg (100 lbs).\n'
                      '• Sleep well for at least 7-8 hours before donating.\n'
                      '• Drink plenty of water (at least 500ml before donation).\n'
                      '• Avoid alcohol for 24 hours prior to donation.\n'
                      '• Eat a healthy, light meal (avoid fatty foods before donation).',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isMm ? 'နားလည်ပါပြီ' : 'Got it',
                style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isMm ? 'သွေးလှူဒါန်းရန်' : 'Blood Donation',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Donor Tips',
            onPressed: () => _showTipsDialog(isMm),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRed,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryRed,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.volunteer_activism_rounded, size: 20),
              text: isMm ? 'သွေးလှူရန်ပုံစံ' : 'Donate Form',
            ),
            Tab(
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              text: isMm ? 'ရက်ချိန်းနှင့်မှတ်တမ်း' : 'My Appointments (${_myDonations.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDonationForm(isMm),
          _buildAppointmentsList(isMm),
        ],
      ),
    );
  }

  Widget _buildDonationForm(bool isMm) {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mission Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFC2185B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bloodtype, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm ? 'သွေးလှူရှင်အဖြစ် ပါဝင်ပါ' : 'Give the Gift of Life',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isMm
                            ? 'သင်၏ သွေးတစ်ပုလင်းသည် အရေးပေါ် လူနာ (၃) ဦး၏ အသက်ကို ကယ်တင်နိုင်ပါသည်။'
                            : 'A single donation can save up to 3 lives in emergency rescue.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Form Note Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade800, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMm
                        ? 'ဤပုံစံရှိ အချက်အလက်များကို ပြင်ဆင်နိုင်ပြီး အကောင့်ပရိုဖိုင် အချက်အလက်ကို ထိခိုက်ခြင်း မရှိပါ။'
                        : 'You can customize your details here for this request without affecting your registered account profile.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Section 1: Donor Info ──────────────────────────────────
          Text(
            isMm ? '၁။ သွေးလှူရှင် အချက်အလက်' : '1. Donor Details',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _input(_nameCtrl, isMm ? 'နာမည်အပြည့်အစုံ' : 'Full Name', Icons.person_outline),
          _input(_phoneCtrl, isMm ? 'ဖုန်းနံပါတ်' : 'Phone Number', Icons.phone_outlined,
              keyboardType: TextInputType.phone),

          // Blood Type Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
              value: _selectedBloodType,
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                labelText: isMm ? 'သွေးအမျိုးအစား' : 'Blood Type',
                prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppTheme.primaryRed),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _bloodTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, color: AppTheme.primaryRed, size: 18),
                      const SizedBox(width: 8),
                      Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedBloodType = val),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: _input(_ageCtrl, isMm ? 'အသက်' : 'Age', Icons.cake_outlined,
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      labelText: isMm ? 'ကျား/မ' : 'Gender',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Male', 'Female', 'Other'].map((g) {
                      return DropdownMenuItem(value: g, child: Text(g));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                ),
              ),
            ],
          ),

          _input(_medCtrl, isMm ? 'ကျန်းမာရေး အခြေအနေ / ဆေးဝါးမှတ်ချက်' : 'Medical Notes / Allergies (Optional)',
              Icons.medical_information_outlined, maxLines: 2),

          const SizedBox(height: 16),

          // ── Section 2: Donation Destination ────────────────────────
          Text(
            isMm ? '၂။ သွေးလှူဒါန်းမည့် နေရာ ရွေးချယ်ပါ' : '2. Donation Center / Hospital',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Toggle: Nearest Org vs Custom Location
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      isMm ? 'အနီးဆုံး ဆေးရုံ/အဖွဲ့' : 'Nearest Org / Hospital',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _useNearest ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  selected: _useNearest,
                  selectedColor: AppTheme.primaryRed,
                  onSelected: (val) => setState(() => _useNearest = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      isMm ? 'စိတ်ကြိုက်နေရာ/မြေပုံ' : 'Custom / Pick on Map',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: !_useNearest ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  selected: !_useNearest,
                  selectedColor: AppTheme.primaryRed,
                  onSelected: (val) => setState(() => _useNearest = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_useNearest) ...[
            if (_nearbyOrgs.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_searching, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMm ? 'အနီးဆုံး အဖွဲ့များ ရှာဖွေနေပါသည်...' : 'Locating nearest rescue hospitals...',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedOrg,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: isMm ? 'အနီးဆုံး ဆေးရုံ/ကယ်ဆယ်ရေးအဖွဲ့' : 'Select Target Hospital / Org',
                    prefixIcon: const Icon(Icons.local_hospital, color: AppTheme.secondaryGreen),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _nearbyOrgs.map((org) {
                    final name = (org['org_name'] ?? 'Hospital').toString();
                    final dist = (org['distance_km'] as num?)?.toDouble();
                    final distStr = dist != null ? ' (${dist.toStringAsFixed(1)} km)' : '';
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: org,
                      child: Text(
                        '$name$distStr',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedOrg = val),
                ),
              ),
          ] else ...[
            _input(_customLocCtrl, isMm ? 'ဆေးရုံ သို့မဟုတ် သွေးလှူဘဏ် အမည်' : 'Hospital / Blood Center Name',
                Icons.business_outlined),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pin_drop, color: AppTheme.primaryRed),
                  label: Text(
                    _customCoords != null
                        ? (isMm ? '📍 တည်နေရာ မှတ်သားပြီး' : '📍 Location Pinned on Map')
                        : (isMm ? '📍 မြေပုံပေါ်တွင် တည်နေရာ ရွေးချယ်မည်' : '📍 Pick Location on Map'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickLocationOnMap,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── Section 3: Appointment Preference & Units ───────────────
          Text(
            isMm ? '၃။ လှူဒါန်းမည့် အချိန်နှင့် ပမာဏ' : '3. Schedule & Units',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _preferredDate,
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      labelText: isMm ? 'ဦးစားပေး အချိန်' : 'Preferred Time',
                      prefixIcon: const Icon(Icons.access_time, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      'As soon as possible',
                      'Today',
                      'Tomorrow',
                      'This Weekend',
                      'Next Week',
                      'Emergency Need Only',
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _preferredDate = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Column(
                    children: [
                      Text(isMm ? 'ပုလင်း/ယူနစ်' : 'Units',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _units > 1 ? () => setState(() => _units--) : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_units',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _units < 4 ? () => setState(() => _units++) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          _input(_notesCtrl, isMm ? 'အပိုဆောင်း မှတ်ချက်များ (ရွေးချယ်ခွင့်)' : 'Additional Notes (Optional)',
              Icons.edit_note, maxLines: 2),

          const SizedBox(height: 20),

          // ── Submit Button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.favorite, color: Colors.white),
              label: Text(
                _submitting
                    ? (isMm ? 'ပေးပို့နေပါသည်...' : 'SUBMITTING REQUEST...')
                    : (isMm ? 'သွေးလှူဒါန်းရန် တောင်းဆိုမှု ပေးပို့မည်' : 'SUBMIT BLOOD DONATION REQUEST'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _submitting ? null : _submitDonation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(bool isMm) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    if (_myDonations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_outlined, size: 54, color: AppTheme.primaryRed),
              ),
              const SizedBox(height: 16),
              Text(
                isMm ? 'သွေးလှူဒါန်းမှု မှတ်တမ်း မရှိသေးပါ' : 'No Blood Donations Yet',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isMm
                    ? 'သွေးလှူဒါန်းရန် ပုံစံတွင် အချက်အလက်များ ဖြည့်သွင်း၍ ရက်ချိန်း ရယူနိုင်ပါသည်။'
                    : 'Submit a blood donation request to receive a scheduled appointment and hospital location.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(isMm ? 'သွေးလှူရန် လျှောက်ထားမည်' : 'Create Donation Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyDonations,
      color: AppTheme.primaryRed,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: _myDonations.length,
        itemBuilder: (context, index) {
          final item = _myDonations[index];
          final status = (item['status'] ?? 'Pending').toString();
          final isAccepted = status.toLowerCase() == 'accepted';
          final isCompleted = status.toLowerCase() == 'completed';
          final bloodType = item['blood_type'] ?? '';
          final date = item['preferred_date'] ?? '';
          final loc = item['target_location_name'] ?? '';
          final apptDate = item['appointment_date'];
          final apptLoc = item['appointment_location'];
          final apptNotes = item['appointment_notes'];
          final orgName = item['target_org_name'];
          final orgPhone = item['target_org_phone'];

          Color badgeColor = Colors.orange;
          if (isAccepted) badgeColor = AppTheme.secondaryGreen;
          if (isCompleted) badgeColor = Colors.blue;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAccepted ? AppTheme.secondaryGreen.withValues(alpha: 0.5) : Colors.grey.shade300,
                width: isAccepted ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isAccepted
                      ? AppTheme.secondaryGreen.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          bloodType,
                          style: const TextStyle(
                            color: AppTheme.primaryRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['donor_name'] ?? 'Donor',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              '📞 ${item['donor_phone'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Center: $loc',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('Preferred Time: $date (${item['units'] ?? 1} Unit)',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),

                      // ── CONFIRMED APPOINTMENT BANNER (When Org Accepted) ──
                      if (isAccepted && apptDate != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.shade300, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: AppTheme.secondaryGreen, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isMm ? 'အတည်ပြုပြီး ရက်ချိန်း အချက်အလက်' : 'Confirmed Appointment Details',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '📅 Appointment: $apptDate',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (apptLoc != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '📍 Where to come: $apptLoc',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade900),
                                ),
                              ],
                              if (apptNotes != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '📝 Hospital Notes: $apptNotes',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                              if (orgName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '🏥 Accepted by: $orgName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (orgPhone != null && orgPhone.toString().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.phone, size: 18),
                              label: Text(
                                isMm ? 'ဆေးရုံသို့ ဖုန်းခေါ်မည် ($orgPhone)' : 'Call Hospital ($orgPhone)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _makeCall(orgPhone),
                            ),
                          ),
                        ],
                      ] else if (status.toLowerCase() == 'pending') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_top, color: Colors.amber.shade800, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isMm
                                      ? 'ဆေးရုံမှ ရက်ချိန်းနှင့် လာရောက်ရမည့် နေရာကို အတည်ပြုရန် စောင့်ဆိုင်းနေပါသည်...'
                                      : 'Waiting for hospital to confirm appointment date & room location...',
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _input(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryRed, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
