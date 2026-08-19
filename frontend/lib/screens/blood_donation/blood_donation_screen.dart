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

  // Donation Form Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _medCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Request Form Controllers (Patient Requisition)
  final _patientNameCtrl = TextEditingController();
  final _reqContactNameCtrl = TextEditingController();
  final _reqContactPhoneCtrl = TextEditingController();
  final _reqHospitalCtrl = TextEditingController();
  final _reqDiagnosisCtrl = TextEditingController();

  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];
  String? _selectedBloodType;
  String? _selectedGender;
  int _donateUnits = 1;
  String _preferredDate = 'As soon as possible';

  // Request form state
  String? _reqBloodType;
  int _reqUnits = 1;
  String _reqUrgency = 'Emergency / Immediate';
  LatLng? _reqCoords;

  // Organization centers for donation
  List<Map<String, dynamic>> _nearbyOrgs = [];
  Map<String, dynamic>? _selectedOrg;

  bool _loadingProfile = true;
  bool _submitting = false;
  bool _loadingHistory = false;
  List<dynamic> _myRecords = [];

  // Full-Screen Onboarding Guidelines State & Search Filter
  bool _showGuidelines = true;
  final _recordSearchCtrl = TextEditingController();
  String _recordFilterQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _medCtrl.dispose();
    _notesCtrl.dispose();
    _patientNameCtrl.dispose();
    _reqContactNameCtrl.dispose();
    _reqContactPhoneCtrl.dispose();
    _reqHospitalCtrl.dispose();
    _reqDiagnosisCtrl.dispose();
    _recordSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadNearbyOrgs(),
      _loadMyRecords(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    try {
      final res = await ApiService().getProfile();
      if (mounted) {
        final data = res.data;
        final bType = data['blood_type'] as String?;
        final fName = (data['full_name'] ?? '').toString();
        final phone = (data['phone_number'] ?? '').toString();
        setState(() {
          _nameCtrl.text = fName;
          _phoneCtrl.text = phone;
          _reqContactNameCtrl.text = fName;
          _reqContactPhoneCtrl.text = phone;
          _medCtrl.text = (data['medical_conditions'] ?? '').toString();
          if (bType != null && _bloodTypes.contains(bType)) {
            _selectedBloodType = bType;
            _reqBloodType = bType;
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
        final medicals = list.where((o) {
          final cat = (o['category'] ?? '').toString().toLowerCase();
          final name = (o['org_name'] ?? '').toString().toLowerCase();
          return cat.contains('medical') ||
              cat.contains('hospital') ||
              cat.contains('voluntary') ||
              cat.contains('volunteer') ||
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

  Future<void> _loadMyRecords() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService().getMyBloodDonations();
      if (mounted) {
        setState(() {
          _myRecords = res.data as List;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _pickHospitalLocationOnMap() async {
    double initLat = 16.8661;
    double initLng = 96.1951;
    try {
      final pos = await LocationService.getCurrentLocation();
      initLat = pos.latitude;
      initLng = pos.longitude;
    } catch (_) {}

    LatLng pickedPoint = _reqCoords ?? LatLng(initLat, initLng);
    final mapController = MapController();

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;

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
                  decoration: BoxDecoration(
                    color: dialogBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pick Hospital Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: textPrimary),
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
                            _reqCoords = pickedPoint;
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
    final cleanPhone = phoneNumber.replaceAll(' ', '').replaceAll('-', '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _confirmCancelRecord(Map<String, dynamic> item, bool isMm) async {
    final reqType = (item['request_type'] ?? 'donate').toString().toLowerCase();
    final isRequest = reqType == 'request';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRequest
                    ? (isMm ? 'သွေးတောင်းခံမှု ပယ်ဖျက်မည်လား?' : 'Cancel Blood Request?')
                    : (isMm ? 'သွေးလှူဒါန်းမှု ပယ်ဖျက်မည်လား?' : 'Cancel Donation Pledge?'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          isRequest
              ? (isMm
                  ? 'လူနာ ${item['patient_name'] ?? 'အတွက်'} သွေးတောင်းခံထားမှုကို ပယ်ဖျက်ရန် သေချာပါသလား?'
                  : 'Are you sure you want to cancel this emergency blood request for ${item['patient_name'] ?? 'the patient'}?')
              : (isMm
                  ? 'သွေးလှူဒါန်းရန် လျှောက်ထားချက်ကို ပယ်ဖျက်ရန် သေချာပါသလား?'
                  : 'Are you sure you want to cancel your blood donation pledge?'),
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isMm ? 'မလုပ်တော့ပါ' : 'Keep',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isMm ? 'ပယ်ဖျက်မည်' : 'Yes, Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final id = item['id'].toString();
        await ApiService().updateBloodDonationStatus(id, 'Cancelled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRequest
                    ? (isMm ? 'သွေးတောင်းခံမှုကို ပယ်ဖျက်ပြီးပါပြီ' : 'Blood request cancelled successfully')
                    : (isMm ? 'သွေးလှူဒါန်းမှုကို ပယ်ဖျက်ပြီးပါပြီ' : 'Blood donation pledge cancelled successfully'),
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
          _loadMyRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMm ? 'ပယ်ဖျက်ရန် မအောင်မြင်ပါ' : 'Failed to cancel record: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── SUBMIT BLOOD DONATION PLEDGE ──────────────────────────────────────────
  Future<void> _submitDonation() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      _snack('Please fill in Donor Name and Phone Number', Colors.orange);
      return;
    }
    if (_selectedBloodType == null) {
      _snack('Please select your Blood Type', Colors.orange);
      return;
    }

    String locationName = _selectedOrg != null
        ? (_selectedOrg!['org_name'] ?? 'Local Rescue Hospital')
        : 'Nearest Available Hospital';
    String? targetOrgId = _selectedOrg != null ? _selectedOrg!['account_id'] : null;
    double? lat = (_selectedOrg?['geo_lat'] as num?)?.toDouble();
    double? lng = (_selectedOrg?['geo_lng'] as num?)?.toDouble();

    setState(() => _submitting = true);

    try {
      final payload = {
        'request_type': 'donate',
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
        'units': _donateUnits,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      await ApiService().createBloodDonation(payload);
      _snack('Blood donation pledge submitted successfully!', AppTheme.secondaryGreen);

      await _loadMyRecords();
      if (mounted) {
        setState(() => _submitting = false);
        _tabController.animateTo(2);
      }
    } catch (e) {
      setState(() => _submitting = false);
      _snack('Failed to submit donation pledge. Please check connection.', Colors.red);
    }
  }

  // ── SUBMIT BLOOD SUPPLY REQUEST (FOR PATIENT IN NEED) ─────────────────────
  Future<void> _submitBloodRequest() async {
    if (_patientNameCtrl.text.trim().isEmpty) {
      _snack('Please enter Patient Name', Colors.orange);
      return;
    }
    if (_reqContactPhoneCtrl.text.trim().isEmpty) {
      _snack('Please enter Contact Phone Number', Colors.orange);
      return;
    }
    if (_reqBloodType == null) {
      _snack('Please select Required Blood Type', Colors.orange);
      return;
    }
    if (_reqHospitalCtrl.text.trim().isEmpty) {
      _snack('Please enter Hospital / Clinic Name & Ward', Colors.orange);
      return;
    }

    double lat = 16.8661;
    double lng = 96.1951;
    if (_reqCoords != null) {
      lat = _reqCoords!.latitude;
      lng = _reqCoords!.longitude;
    } else {
      try {
        final pos = await LocationService.getCurrentLocation();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
    }

    setState(() => _submitting = true);

    try {
      final payload = {
        'request_type': 'request',
        'patient_name': _patientNameCtrl.text.trim(),
        'donor_name': _reqContactNameCtrl.text.trim().isNotEmpty
            ? _reqContactNameCtrl.text.trim()
            : _patientNameCtrl.text.trim(),
        'donor_phone': _reqContactPhoneCtrl.text.trim(),
        'blood_type': _reqBloodType!,
        'hospital_name': _reqHospitalCtrl.text.trim(),
        'target_location_name': _reqHospitalCtrl.text.trim(),
        'urgency_level': _reqUrgency,
        'units': _reqUnits,
        'medical_notes': _reqDiagnosisCtrl.text.trim().isNotEmpty ? _reqDiagnosisCtrl.text.trim() : null,
        'target_lat': lat,
        'target_lng': lng,
        'preferred_date': _reqUrgency,
      };

      await ApiService().createBloodDonation(payload);
      _snack('Emergency blood request broadcasted to nearest hospitals & rescue groups!', AppTheme.secondaryGreen);

      await _loadMyRecords();
      if (mounted) {
        setState(() => _submitting = false);
        _tabController.animateTo(2);
      }
    } catch (e) {
      setState(() => _submitting = false);
      _snack('Failed to broadcast blood request. Please check connection.', Colors.red);
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

  Widget _buildGuidelineCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.grey.shade50;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenGuidelines(bool isMm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isMm ? 'သွေးမလှူမီ သိကောင်းစရာများ' : 'Blood Donor Preparation Guide',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD32F2F), Color(0xFFC2185B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isMm ? 'သွေးလှူရှင်များ လိုက်နာရမည့် စည်းကမ်းချက်များ' : 'Donor Eligibility & Health Checklist',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isMm
                                ? 'ကျန်းမာသော သွေးတစ်ပုလင်းသည် အရေးပေါ်လူနာအတွက် အသက်ကယ်ဆေးဖြစ်ပါသည်။'
                                : 'Ensure safe blood donation for both your health and the patient.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      isMm ? 'အဓိက သတ်မှတ်ချက်များ' : 'Key Preparation Rules',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildGuidelineCard(
                      icon: Icons.cake_outlined,
                      iconColor: Colors.orange,
                      title: isMm ? 'အသက်အပိုင်းအခြား' : 'Age Criteria',
                      subtitle: isMm
                          ? 'အသက် (၁၈) မှ (၆၀) နှစ်ကြား ဖြစ်ရပါမည်။'
                          : 'Age must be between 18 and 60 years old.',
                    ),
                    const SizedBox(height: 10),
                    _buildGuidelineCard(
                      icon: Icons.monitor_weight_outlined,
                      iconColor: Colors.blue,
                      title: isMm ? 'ကိုယ်အလေးချိန်' : 'Body Weight',
                      subtitle: isMm
                          ? 'အနည်းဆုံး ပေါင် (၁၀၀) သို့မဟုတ် ၄၅ ကီလိုဂရမ် ရှိရပါမည်။'
                          : 'Weight must be at least 45 kg (100 lbs).',
                    ),
                    const SizedBox(height: 10),
                    _buildGuidelineCard(
                      icon: Icons.bedtime_outlined,
                      iconColor: Colors.indigo,
                      title: isMm ? 'လုံလောက်စွာ အိပ်စက်အနားယူခြင်း' : 'Adequate Sleep & Rest',
                      subtitle: isMm
                          ? 'သွေးမလှူမီ ညတွင် အနည်းဆုံး (၇-၈) နာရီ ကောင်းစွာ အိပ်စက်ပါ။'
                          : 'Sleep well for at least 7-8 hours before donating.',
                    ),
                    const SizedBox(height: 10),
                    _buildGuidelineCard(
                      icon: Icons.water_drop_outlined,
                      iconColor: Colors.teal,
                      title: isMm ? 'ရေလုံလောက်စွာ သောက်သုံးခြင်း' : 'Hydration',
                      subtitle: isMm
                          ? 'သွေးမလှူမီ ရေ (အနည်းဆုံး ၅၀၀ မီလီလီတာ) သောက်သုံးပေးပါ။'
                          : 'Drink plenty of water (at least 500ml before donation).',
                    ),
                    const SizedBox(height: 10),
                    _buildGuidelineCard(
                      icon: Icons.no_drinks_outlined,
                      iconColor: Colors.red,
                      title: isMm ? 'အရက်သေစာ ရှောင်ကြဉ်ခြင်း' : 'Avoid Alcohol',
                      subtitle: isMm
                          ? 'သွေးမလှူမီ (၂၄) နာရီအတွင်း အရက်သေစာ လုံးဝမသောက်ပါနှင့်။'
                          : 'Avoid alcohol for 24 hours prior to donation.',
                    ),
                    const SizedBox(height: 10),
                    _buildGuidelineCard(
                      icon: Icons.restaurant_outlined,
                      iconColor: Colors.green,
                      title: isMm ? 'ကျန်းမာသော အစားအသောက်' : 'Healthy Light Meal',
                      subtitle: isMm
                          ? 'အဆီအစိမ့်များ ရှောင်ကြဉ်ပြီး ပေါ့ပေါ့ပါးပါး အစာစားသုံးထားပါ။'
                          : 'Eat a healthy, light meal (avoid fatty foods before donation).',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Continue / Next Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bottomBarBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    setState(() {
                      _showGuidelines = false;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMm ? 'ရှေ့သို့ ဆက်သွားမည် (NEXT)' : 'CONTINUE TO BLOOD HUB',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    if (_showGuidelines) {
      return _buildFullScreenGuidelines(isMm);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'သွေးလှူဒါန်းခြင်းနှင့် ရယူခြင်း' : 'Blood Bank & Donation Hub',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Donor Tips',
            onPressed: () => setState(() => _showGuidelines = true),
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            Tab(
              icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
              text: isMm ? 'သွေးလှူမည်' : 'Donate',
            ),
            Tab(
              icon: const Icon(Icons.add_alert_rounded, size: 18),
              text: isMm ? 'သွေးတောင်းခံမည်' : 'Request Blood',
            ),
            Tab(
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              text: isMm ? 'မှတ်တမ်း (${_myRecords.length})' : 'Records (${_myRecords.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDonationForm(isMm),
          _buildRequestBloodForm(isMm),
          _buildRecordsList(isMm),
        ],
      ),
    );
  }

  // ── TAB 1: DONATE BLOOD FORM ──────────────────────────────────────────────
  Widget _buildDonationForm(bool isMm) {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mission Banner
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
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6) : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue.shade800, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMm
                            ? 'ဤပုံစံရှိ အချက်အလက်များကို ပြင်ဆင်နိုင်ပြီး အကောင့်ပရိုဖိုင် အချက်အလက်ကို ထိခိုက်ခြင်း မရှိပါ။'
                            : 'You can customize your details here for this request without affecting your registered account profile.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Donor Info
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
              initialValue: _selectedBloodType,
              dropdownColor: Theme.of(context).cardColor,
              decoration: InputDecoration(
                labelText: isMm ? 'သွေးအမျိုးအစား' : 'Blood Type',
                prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppTheme.primaryRed),
                filled: true,
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
                    initialValue: _selectedGender,
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: isMm ? 'ကျား/မ' : 'Gender',
                      filled: true,
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

          // Destination
          Text(
            isMm ? '၂။ သွေးလှူဒါန်းမည့် ဆေးရုံ/အဖွဲ့' : '2. Donation Center / Hospital',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (_nearbyOrgs.isEmpty)
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_searching, color: isDark ? Colors.white60 : Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isMm ? 'အနီးဆုံး ဆေးရုံ/အဖွဲ့များ ရှာဖွေနေပါသည်...' : 'Locating nearest rescue hospitals & centers...',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: _selectedOrg,
                dropdownColor: Theme.of(context).cardColor,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: isMm ? 'ဆေးရုံ/ကယ်ဆယ်ရေးအဖွဲ့ ရွေးချယ်ပါ' : 'Select Target Hospital / Org',
                  prefixIcon: const Icon(Icons.local_hospital, color: AppTheme.secondaryGreen),
                  filled: true,
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

          const SizedBox(height: 8),

          // Schedule & Units Row
          Text(
            isMm ? '၃။ လှူဒါန်းမည့် အချိန်နှင့် ပမာဏ' : '3. Schedule & Units',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _preferredDate,
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: isMm ? 'ဦးစားပေး အချိန်' : 'Preferred Time',
                      prefixIcon: const Icon(Icons.access_time, color: Colors.blue),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                flex: 2,
                child: _buildUnitsCounterBox(
                  units: _donateUnits,
                  label: isMm ? 'ပုလင်း' : 'Units',
                  onMinus: _donateUnits > 1 ? () => setState(() => _donateUnits--) : null,
                  onPlus: _donateUnits < 4 ? () => setState(() => _donateUnits++) : null,
                ),
              ),
            ],
          ),

          _input(_notesCtrl, isMm ? 'အပိုဆောင်း မှတ်ချက်များ (ရွေးချယ်ခွင့်)' : 'Additional Notes (Optional)',
              Icons.edit_note, maxLines: 2),

          const SizedBox(height: 20),

          // Submit Button
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
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _submitting
                      ? (isMm ? 'ပေးပို့နေပါသည်...' : 'SUBMITTING PLEDGE...')
                      : (isMm ? 'သွေးလှူဒါန်းရန် ပေးပို့မည်' : 'CONFIRM DONATION PLEDGE'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
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

  // ── TAB 2: REQUEST BLOOD FORM (PATIENT EMERGENCY NEED) ────────────────────
  Widget _buildRequestBloodForm(bool isMm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Request Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFE65100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withValues(alpha: 0.3),
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
                  child: const Icon(Icons.emergency, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm ? 'လူနာအတွက် သွေးအကူအညီတောင်းခံခြင်း' : 'Emergency Blood Supply Request',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isMm
                            ? 'အနီးဆုံးရှိ ဆေးရုံများနှင့် ပရဟိတကယ်ဆယ်ရေးအဖွဲ့များအားလုံးသို့ ချက်ချင်း သတိပေးချက် ပေးပို့ပါမည်။'
                            : 'Broadcasts instantly to all nearest Medical Centers & Local Voluntary Rescue Groups.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
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
          const SizedBox(height: 18),

          // 1. Patient & Required Blood
          Text(
            isMm ? '၁။ လူနာနှင့် လိုအပ်သော သွေးအမျိုးအစား' : '1. Patient & Required Blood',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _input(_patientNameCtrl, isMm ? 'လူနာအမည်' : 'Patient Full Name', Icons.person_add_alt_1),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _reqBloodType,
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: isMm ? 'လိုအပ်သော သွေး' : 'Blood Needed',
                      prefixIcon: const Icon(Icons.water_drop, color: AppTheme.primaryRed),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _bloodTypes.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _reqBloodType = val),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildUnitsCounterBox(
                  units: _reqUnits,
                  label: isMm ? 'ပုလင်း' : 'Units',
                  onMinus: _reqUnits > 1 ? () => setState(() => _reqUnits--) : null,
                  onPlus: _reqUnits < 10 ? () => setState(() => _reqUnits++) : null,
                ),
              ),
            ],
          ),

          // Urgency Level Dropdown
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
              initialValue: _reqUrgency,
              dropdownColor: Theme.of(context).cardColor,
              decoration: InputDecoration(
                labelText: isMm ? 'အရေးတကြီး လိုအပ်မှု အဆင့်' : 'Urgency Level',
                prefixIcon: const Icon(Icons.timer_outlined, color: Colors.deepOrange),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                'Emergency / Immediate',
                'Within 24 Hours',
                'Scheduled Surgery',
                'Normal',
              ].map((u) {
                Color color = Colors.black87;
                if (u.contains('Emergency')) color = AppTheme.primaryRed;
                if (u.contains('24 Hours')) color = Colors.deepOrange;
                return DropdownMenuItem(
                  value: u,
                  child: Text(u, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _reqUrgency = val);
              },
            ),
          ),

          const SizedBox(height: 10),

          // 2. Hospital & Contact Person
          Text(
            isMm ? '၂။ လူနာရှိသော ဆေးရုံနှင့် ဆက်သွယ်ရန်' : '2. Hospital Location & Contact',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _input(_reqHospitalCtrl, isMm ? 'ဆေးရုံအမည်၊ အဆောင်နှင့် ကုတင်နံပါတ်' : 'Hospital Name, Ward & Bed No.',
              Icons.local_hospital_outlined),

          _input(_reqContactNameCtrl, isMm ? 'ဆက်သွယ်ရမည့်သူ အမည်' : 'Contact Person Name', Icons.person_outline),
          _input(_reqContactPhoneCtrl, isMm ? 'ဆက်သွယ်ရမည့် ဖုန်းနံပါတ်' : 'Contact Phone Number',
              Icons.phone_outlined, keyboardType: TextInputType.phone),

          _input(_reqDiagnosisCtrl, isMm ? 'ရောဂါအခြေအနေ / အထူးမှတ်ချက် (ရွေးချယ်ခွင့်)' : 'Diagnosis / Doctor Order Notes (Optional)',
              Icons.medical_information_outlined, maxLines: 2),

          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.pin_drop_outlined, color: AppTheme.primaryRed),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _reqCoords != null
                        ? (isMm ? 'ဆေးရုံတည်နေရာ မှတ်သားပြီး' : 'Hospital Location Pinned')
                        : (isMm ? 'ဆေးရုံတည်နေရာ မြေပုံပေါ်တွင် ရွေးချယ်မည်' : 'Pin Hospital on Map (Optional)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed, fontSize: 13),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pickHospitalLocationOnMap,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Submit Broadcast Request Button
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
                  : const Icon(Icons.cell_tower_rounded, color: Colors.white),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _submitting
                      ? (isMm ? 'အဖွဲ့များသို့ ပေးပို့နေပါသည်...' : 'BROADCASTING TO ORGS...')
                      : (isMm ? 'သွေးတောင်းခံလွှာ ပေးပို့မည်' : 'BROADCAST BLOOD REQUEST'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _submitting ? null : _submitBloodRequest,
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 3: RECORDS & PICKUPS LIST ─────────────────────────────────────────
  Widget _buildRecordsList(bool isMm) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    final filteredRecords = _myRecords.where((item) {
      if (_recordFilterQuery.isEmpty) return true;
      final q = _recordFilterQuery.toLowerCase();
      final pName = (item['patient_name'] ?? '').toString().toLowerCase();
      final dName = (item['donor_name'] ?? '').toString().toLowerCase();
      final bType = (item['blood_type'] ?? '').toString().toLowerCase();
      final status = (item['status'] ?? '').toString().toLowerCase();
      final loc = (item['target_location_name'] ?? item['hospital_name'] ?? '').toString().toLowerCase();
      return pName.contains(q) || dName.contains(q) || bType.contains(q) || status.contains(q) || loc.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadMyRecords,
      color: AppTheme.primaryRed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: _recordSearchCtrl,
              decoration: InputDecoration(
                hintText: isMm ? 'မှတ်တမ်းများ ရှာဖွေရန်...' : 'Search records by name, blood type, status...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                suffixIcon: _recordFilterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _recordSearchCtrl.clear();
                          setState(() => _recordFilterQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) => setState(() => _recordFilterQuery = val.trim()),
            ),
          ),

          if (filteredRecords.isEmpty)
            Center(
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
                      _recordFilterQuery.isNotEmpty
                          ? (isMm ? 'ကိုက်ညီသော မှတ်တမ်း မရှိပါ' : 'No Matching Records')
                          : (isMm ? 'သွေးမှတ်တမ်း မရှိသေးပါ' : 'No Blood Records Yet'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recordFilterQuery.isNotEmpty
                          ? (isMm ? 'အခြားသော အချက်အလက်ဖြင့် ပြန်လည် ရှာဖွေကြည့်ပါ။' : 'Try searching with another query.')
                          : (isMm
                              ? 'သွေးလှူဒါန်းရန် သို့မဟုတ် လူနာအတွက် သွေးတောင်းခံရန် အပေါ်ရှိ Tab များမှ လျှောက်ထားနိုင်ပါသည်။'
                              : 'Submit a blood donation pledge or an emergency blood request to view status and pickup locations.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredRecords.map((item) {
          final reqType = (item['request_type'] ?? 'donate').toString().toLowerCase();
          final isRequest = reqType == 'request';
          final status = (item['status'] ?? 'Pending').toString();
          final isAccepted = status.toLowerCase() == 'accepted';
          final isCompleted = status.toLowerCase() == 'completed';
          final bloodType = item['blood_type'] ?? '';
          final date = item['preferred_date'] ?? '';
          final loc = item['target_location_name'] ?? item['hospital_name'] ?? '';
          final apptDate = item['appointment_date'];
          final apptLoc = item['appointment_location'];
          final apptNotes = item['appointment_notes'];
          final pickupMsg = item['pickup_location_message'];
          final orgName = item['accepted_org_name'] ?? item['target_org_name'];
          final orgPhone = item['accepted_org_phone'] ?? item['target_org_phone'];
          final patientName = item['patient_name'];
          final urgency = item['urgency_level'];

          Color badgeColor = Colors.orange;
          if (isAccepted) badgeColor = AppTheme.secondaryGreen;
          if (isCompleted) badgeColor = Colors.blue;
          if (status.toLowerCase() == 'cancelled') badgeColor = Colors.grey.shade600;

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAccepted
                      ? AppTheme.secondaryGreen.withValues(alpha: isDark ? 0.8 : 0.6)
                      : (isDark
                          ? const Color(0xFF334155)
                          : (isRequest ? Colors.red.shade200 : Colors.grey.shade300)),
                  width: isAccepted ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isAccepted
                        ? AppTheme.secondaryGreen.withValues(alpha: isDark ? 0.2 : 0.1)
                        : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isRequest
                          ? (isAccepted
                              ? AppTheme.secondaryGreen.withValues(alpha: isDark ? 0.2 : 0.08)
                              : (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50))
                          : (isDark ? badgeColor.withValues(alpha: 0.2) : badgeColor.withValues(alpha: 0.08)),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withValues(alpha: isDark ? 0.25 : 0.15),
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
                                    isRequest ? 'Blood Request' : 'Blood Donation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: isRequest ? AppTheme.primaryRed : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  if (urgency != null && urgency.toString().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: isDark ? Border.all(color: Colors.red.shade400) : null,
                                      ),
                                      child: Text(
                                        urgency.toString(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isRequest
                                    ? 'Patient: ${patientName ?? item['donor_name']} (${item['units'] ?? 1} Units)'
                                    : 'Donor: ${item['donor_name']} (${item['units'] ?? 1} Units)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                            isAccepted
                                ? (isMm ? 'လက်ခံပြီး' : 'ACCEPTED')
                                : (status.toLowerCase() == 'cancelled'
                                    ? (isMm ? 'ပယ်ဖျက်ပြီး' : 'CANCELLED')
                                    : (status.toLowerCase() == 'completed'
                                        ? (isMm ? 'ပြီးစီး' : 'COMPLETED')
                                        : status.toUpperCase())),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body Info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white60 : Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isRequest ? 'Hospital: $loc' : 'Center: $loc',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 15, color: isDark ? Colors.white60 : Colors.grey),
                            const SizedBox(width: 6),
                            Text('Contact: ${item['donor_phone'] ?? ''}',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey)),
                          ],
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 15, color: isDark ? Colors.white60 : Colors.grey),
                              const SizedBox(width: 6),
                              Text('Time / Urgency: $date',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey)),
                            ],
                          ),
                        ],

                        // ── CONFIRMED / ACCEPTED BANNER ────
                        if (isAccepted) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF059669) : Colors.green.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified, color: AppTheme.secondaryGreen, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isRequest
                                            ? (isMm ? 'လက်ခံပြီး • သွေးထုတ်ယူရန် အချက်အလက်' : 'Confirmed Pickup Details')
                                            : (isMm ? 'အတည်ပြုပြီး ရက်ချိန်း အချက်အလက်' : 'Confirmed Appointment Details'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (isRequest && pickupMsg != null && pickupMsg.toString().isNotEmpty) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, size: 15, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Where to get blood: $pickupMsg',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (apptDate != null && apptDate.toString().isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 15, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Time: $apptDate',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (!isRequest && apptLoc != null && apptLoc.toString().isNotEmpty) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, size: 15, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Where to come: $apptLoc',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.grey.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (apptNotes != null && apptNotes.toString().isNotEmpty) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.note_alt_outlined, size: 15, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Notes: $apptNotes',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (orgName != null && orgName.toString().isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.local_hospital, size: 15, color: AppTheme.secondaryGreen),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Organization: $orgName',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF6EE7B7) : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                  isMm ? 'ဆေးရုံ/အဖွဲ့သို့ ဖုန်းခေါ်မည် ($orgPhone)' : 'Call Hospital / Org ($orgPhone)',
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
                              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFFD97706) : Colors.amber.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.hourglass_top, color: isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isRequest
                                        ? (isMm
                                            ? 'အနီးဆုံး ဆေးရုံများနှင့် ကယ်ဆယ်ရေးအဖွဲ့များထံမှ တုံ့ပြန်မှုကို စောင့်ဆိုင်းနေပါသည်...'
                                            : 'Broadcasting to nearest hospitals & rescue groups... Waiting for response.')
                                        : (isMm
                                            ? 'ဆေးရုံမှ ရက်ချိန်းနှင့် လာရောက်ရမည့် နေရာကို အတည်ပြုရန် စောင့်ဆိုင်းနေပါသည်...'
                                            : 'Waiting for hospital to confirm appointment date & room location...'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (status.toLowerCase() == 'cancelled') ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.red.withValues(alpha: 0.12) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.red.withValues(alpha: 0.3) : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isRequest
                                        ? (isMm ? 'ဤသွေးတောင်းခံမှုကို ပယ်ဖျက်ထားပါသည်' : 'This blood request was cancelled.')
                                        : (isMm ? 'ဤသွေးလှူဒါန်းမှု လျှောက်ထားချက်ကို ပယ်ဖျက်ထားပါသည်' : 'This donation pledge was cancelled.'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── CANCEL ACTION BUTTON FOR ACTIVE PENDING / ACCEPTED RECORDS ────
                        if (status.toLowerCase() != 'completed' && status.toLowerCase() != 'cancelled') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isRequest
                                      ? (isMm ? 'သွေးတောင်းခံမှု ပယ်ဖျက်မည်' : 'CANCEL BLOOD REQUEST')
                                      : (isMm ? 'သွေးလှူဒါန်းမှု ပယ်ဖျက်မည်' : 'CANCEL DONATION PLEDGE'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                backgroundColor: isDark
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.red.shade50.withValues(alpha: 0.5),
                              ),
                              onPressed: () => _confirmCancelRecord(item, isMm),
                            ),
                          ),
                        ],
                      ],
                  ),
                ),
              ],
            ),
          );
        }),
        ],
      ),
    );
  }

  // ── REFINED PIXEL-PERFECT UNITS COUNTER BOX WIDGET ────────────────────────
  Widget _buildUnitsCounterBox({
    required int units,
    required String label,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Minus Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onMinus,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: onMinus != null
                      ? AppTheme.primaryRed.withValues(alpha: isDark ? 0.2 : 0.1)
                      : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: onMinus != null
                      ? AppTheme.primaryRed
                      : (isDark ? Colors.white30 : Colors.grey.shade400),
                ),
              ),
            ),
          ),

          // Count & Label
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$units',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Plus Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPlus,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: onPlus != null
                      ? AppTheme.primaryRed.withValues(alpha: isDark ? 0.2 : 0.1)
                      : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: onPlus != null
                      ? AppTheme.primaryRed
                      : (isDark ? Colors.white30 : Colors.grey.shade400),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryRed, size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }
}
