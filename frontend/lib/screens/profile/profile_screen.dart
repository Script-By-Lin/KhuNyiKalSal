import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _history = [];
  bool _loading = true;
  bool _editing = false;
  bool _isSaving = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedBloodType;

  final List<String> _orgCategories = ['Medical', 'Fire', 'Local Voluntary Group'];
  String? _selectedOrgCategory;

  // General & User Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();

  // Organization Specific Controllers
  final _orgNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _regionsCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _regNumCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  // Volunteer Specific Controllers
  final _nrcCtrl = TextEditingController();
  final _assignedRegionCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await ApiService().getProfile();
      List<dynamic> hist = [];
      try {
        final histRes = await ApiService().getEmergencyHistory();
        hist = histRes.data as List;
      } catch (_) {}

      if (mounted) {
        final data = res.data;
        final bType = data['blood_type'] as String?;
        final cat = data['category'] as String?;

        setState(() {
          _profile = data;
          _history = hist;

          _nameCtrl.text = data['full_name'] ?? data['org_name'] ?? '';
          _phoneCtrl.text = data['phone_number'] ?? '';
          _medicalCtrl.text = data['medical_conditions'] ?? '';
          _selectedBloodType = (bType != null && _bloodTypes.contains(bType)) ? bType : null;

          // Org fields
          _orgNameCtrl.text = data['org_name'] ?? data['full_name'] ?? '';
          _addressCtrl.text = data['headquarters_address'] ?? '';
          _regionsCtrl.text = data['operating_regions'] ?? '';
          _radiusCtrl.text = data['coverage_radius_km'] != null ? '${data['coverage_radius_km']}' : '50.0';
          _regNumCtrl.text = data['registration_number'] ?? '';
          _latCtrl.text = data['location_lat'] != null ? '${data['location_lat']}' : '';
          _lngCtrl.text = data['location_lng'] != null ? '${data['location_lng']}' : '';
          
          if (cat != null && cat.isNotEmpty) {
            final matched = _orgCategories.firstWhere(
              (c) => c.toLowerCase() == cat.toLowerCase() || (cat.toLowerCase().contains('volunt') && c.contains('Voluntary')),
              orElse: () => _orgCategories.first,
            );
            _selectedOrgCategory = matched;
          } else {
            _selectedOrgCategory = _orgCategories.first;
          }

          // Volunteer fields
          _nrcCtrl.text = data['nrc_number'] ?? '';
          _assignedRegionCtrl.text = data['assigned_region'] ?? '';
          _emergencyContactCtrl.text = data['emergency_contact'] ?? '';

          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _medicalCtrl.dispose();
    _orgNameCtrl.dispose();
    _addressCtrl.dispose();
    _regionsCtrl.dispose();
    _radiusCtrl.dispose();
    _regNumCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _nrcCtrl.dispose();
    _assignedRegionCtrl.dispose();
    _emergencyContactCtrl.dispose();
    super.dispose();
  }

  String? _validatePhone(String value) {
    if (value.trim().isEmpty) return null;
    final clean = value.trim().replaceAll(' ', '').replaceAll('-', '');
    final regExp = RegExp(r'^(?:\+959|09)\d{7,10}$');
    if (!regExp.hasMatch(clean)) {
      return 'Phone must start with +959 or 09 followed by valid digits\n(e.g., 09123456789 or +959123456789)';
    }
    return null;
  }

  Future<void> _save() async {
    final phoneErr = _validatePhone(_phoneCtrl.text);
    if (phoneErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $phoneErr'),
          backgroundColor: AppTheme.primaryRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cleanPhone = _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
      final auth = ref.read(authProvider);
      final role = (auth.role ?? _profile?['role'] ?? 'user').toString().toLowerCase();

      final payload = <String, dynamic>{
        'phone_number': cleanPhone,
      };

      if (role == 'organization') {
        payload['org_name'] = _orgNameCtrl.text.trim().isNotEmpty ? _orgNameCtrl.text.trim() : _nameCtrl.text.trim();
        payload['full_name'] = payload['org_name'];
        payload['category'] = _selectedOrgCategory ?? 'Medical';
        payload['operating_regions'] = _regionsCtrl.text.trim();
        payload['headquarters_address'] = _addressCtrl.text.trim();
        payload['registration_number'] = _regNumCtrl.text.trim();
        final radius = double.tryParse(_radiusCtrl.text.trim());
        if (radius != null) {
          payload['coverage_radius_km'] = radius;
        }
        final lat = double.tryParse(_latCtrl.text.trim());
        final lng = double.tryParse(_lngCtrl.text.trim());
        if (lat != null && lng != null) {
          payload['location_lat'] = lat;
          payload['location_lng'] = lng;
        }
      } else if (role == 'volunteer') {
        payload['full_name'] = _nameCtrl.text.trim();
        payload['nrc_number'] = _nrcCtrl.text.trim();
        payload['assigned_region'] = _assignedRegionCtrl.text.trim();
        payload['emergency_contact'] = _emergencyContactCtrl.text.trim();
      } else {
        // Regular User
        payload['full_name'] = _nameCtrl.text.trim();
        payload['blood_type'] = _selectedBloodType ?? '';
        payload['medical_conditions'] = _medicalCtrl.text.trim();
      }

      await ApiService().updateProfile(payload);

      if (mounted) {
        setState(() {
          _editing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.secondaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    } catch (e) {
      String msg = 'Failed to update profile';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      }
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showHistoryModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final itemBg = isDark ? const Color(0xFF0F172A) : AppTheme.surfaceGrey;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : AppTheme.subtleGrey;
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        List<dynamic> sheetHistory = List.from(_history);
        bool isLoadingMore = false;
        bool hasMore = true;
        int currentSkip = sheetHistory.length;
        const int pageSize = 20;

        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) {
                scrollCtrl.addListener(() async {
                  if (scrollCtrl.position.pixels >= scrollCtrl.position.maxScrollExtent - 120 &&
                      !isLoadingMore &&
                      hasMore) {
                    setModalState(() => isLoadingMore = true);
                    try {
                      final nextRes = await ApiService().getEmergencyHistory(
                        skip: currentSkip,
                        limit: pageSize,
                      );
                      final List nextItems = (nextRes.data as List?) ?? [];
                      if (nextItems.length < pageSize) {
                        hasMore = false;
                      }
                      currentSkip += nextItems.length;
                      setModalState(() {
                        sheetHistory.addAll(nextItems);
                        isLoadingMore = false;
                      });
                    } catch (_) {
                      setModalState(() => isLoadingMore = false);
                    }
                  }
                });

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isMm
                                  ? '📜 SOS အရေးပေါ် မှတ်တမ်းများ (${sheetHistory.length})'
                                  : '📜 SOS Emergency History (${sheetHistory.length})',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (sheetHistory.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isMm ? 'အားလုံး' : 'All Records',
                                style: const TextStyle(
                                  color: AppTheme.primaryRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: sheetHistory.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text(
                                      isMm ? 'ယခင် အရေးပေါ် မှတ်တမ်း မရှိသေးပါ' : 'No past emergency records found.',
                                      style: TextStyle(color: textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: sheetHistory.length + (isLoadingMore ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i == sheetHistory.length) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  }

                                  final h = sheetHistory[i];
                                  final type = (h['type'] ?? '').toString().toUpperCase();
                                  final status = (h['status'] ?? '').toString().toUpperCase();
                                  final date = (h['created_at'] ?? '').toString().split('T').first;

                                  Color statusColor = Colors.orange;
                                  if (status == 'ACCEPTED' || status == 'COMPLETED') {
                                    statusColor = AppTheme.secondaryGreen;
                                  } else if (status == 'CANCELLED') {
                                    statusColor = Colors.grey;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: itemBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          type.contains('FIRE')
                                              ? Icons.local_fire_department
                                              : (type.contains('ACCIDENT')
                                                  ? Icons.car_crash_outlined
                                                  : (type.contains('DISASTER')
                                                      ? Icons.flood_outlined
                                                      : Icons.medical_services_outlined)),
                                          color: AppTheme.primaryRed,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$type Emergency',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700, fontSize: 14, color: textPrimary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isMm ? 'ရက်စွဲ - $date' : 'Date: $date',
                                                style: TextStyle(
                                                    fontSize: 12, color: textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
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
                );
              },
            );
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final auth = ref.watch(authProvider);
    final role = (auth.role ?? _profile?['role'] ?? 'user').toString().toLowerCase();

    final isOrg = role == 'organization';
    final isVolunteer = role == 'volunteer';

    final displayName = isOrg
        ? (_orgNameCtrl.text.isNotEmpty ? _orgNameCtrl.text : 'Organization')
        : (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : (isVolunteer ? 'Volunteer' : 'User'));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'ပရိုဖိုင် အချက်အလက်' : (isOrg ? 'Organization Profile' : (isVolunteer ? 'Volunteer Profile' : 'My Profile')),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_editing && !_loading && !isOrg)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'SOS History',
              onPressed: _showHistoryModal,
            ),
          if (!_editing && !_loading)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 160),
              child: Column(
                children: [
                  // ── Avatar & Header ──────────────────────────────────
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: isOrg
                          ? AppTheme.secondaryGreen.withValues(alpha: 0.1)
                          : (isVolunteer
                              ? Colors.orange.withValues(alpha: 0.1)
                              : AppTheme.primaryRed.withValues(alpha: 0.1)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOrg
                            ? AppTheme.secondaryGreen.withValues(alpha: 0.3)
                            : (isVolunteer
                                ? Colors.orange.withValues(alpha: 0.3)
                                : AppTheme.primaryRed.withValues(alpha: 0.3)),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isOrg
                            ? Icons.business_rounded
                            : (isVolunteer ? Icons.volunteer_activism_rounded : Icons.person_rounded),
                        color: isOrg
                            ? AppTheme.secondaryGreen
                            : (isVolunteer ? Colors.orange.shade800 : AppTheme.primaryRed),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOrg
                              ? AppTheme.secondaryGreen.withValues(alpha: 0.15)
                              : (isVolunteer
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : AppTheme.primaryRed.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isOrg
                                ? AppTheme.secondaryGreen
                                : (isVolunteer ? Colors.orange.shade900 : AppTheme.primaryRed),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        auth.email ?? _profile?['email'] ?? '',
                        style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Form Fields by Role ──────────────────────────────
                  if (isOrg) ...[
                    // Organization Form
                    _field(
                      isMm ? 'အဖွဲ့အစည်း အမည်' : 'Organization Name',
                      _orgNameCtrl,
                      Icons.business_outlined,
                    ),
                    _field(
                      isMm ? 'အရေးပေါ် ဖုန်းနံပါတ် / Hotline' : 'Hotline Phone Number',
                      _phoneCtrl,
                      Icons.phone_outlined,
                      helperText: 'Must start with +959 or 09 (e.g. 09123456789)',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedOrgCategory,
                        decoration: InputDecoration(
                          labelText: isMm ? 'အဖွဲ့အစည်း အမျိုးအစား' : 'Organization Category',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                            color: _editing ? AppTheme.primaryRed : AppTheme.subtleGrey,
                          ),
                        ),
                        items: _orgCategories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                        onChanged: _editing ? (val) => setState(() => _selectedOrgCategory = val) : null,
                      ),
                    ),
                    _field(
                      isMm ? 'တာဝန်ယူရာ ဒေသများ' : 'Operating Regions',
                      _regionsCtrl,
                      Icons.map_outlined,
                      helperText: 'e.g. Yangon, Bago, Mandalay',
                    ),
                    _field(
                      isMm ? 'ရုံးချုပ် လိပ်စာ' : 'Headquarters Address',
                      _addressCtrl,
                      Icons.location_city_outlined,
                      maxLines: 2,
                    ),
                    _field(
                      isMm ? 'လွှမ်းခြုံနိုင်သော အကွာအဝေး (ကီလိုမီတာ)' : 'Coverage Radius (KM)',
                      _radiusCtrl,
                      Icons.radar_outlined,
                    ),
                    _field(
                      isMm ? 'တရားဝင် မှတ်ပုံတင်အမှတ်' : 'Registration Number',
                      _regNumCtrl,
                      Icons.verified_outlined,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'Latitude',
                            _latCtrl,
                            Icons.my_location,
                            helperText: 'e.g. 16.8409',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            'Longitude',
                            _lngCtrl,
                            Icons.location_searching,
                            helperText: 'e.g. 96.1735',
                          ),
                        ),
                      ],
                    ),
                    if (_editing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.gps_fixed, size: 16),
                          label: Text(
                            isMm ? 'လက်ရှိ GPS တည်နေရာ အသုံးပြုမည်' : 'Set to Current GPS Location',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Updated to current GPS location!'),
                                    backgroundColor: AppTheme.secondaryGreen,
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to retrieve GPS location. Check permissions.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                  ] else if (isVolunteer) ...[
                    // Volunteer Form
                    _field(
                      isMm ? 'စေတနာ့ဝန်ထမ်း အမည်' : 'Volunteer Full Name',
                      _nameCtrl,
                      Icons.person_outline,
                    ),
                    _field(
                      isMm ? 'ဖုန်းနံပါတ်' : 'Phone Number',
                      _phoneCtrl,
                      Icons.phone_outlined,
                      helperText: 'Must start with +959 or 09',
                    ),
                    _field(
                      isMm ? 'တာဝန်ကျ ဒေသ' : 'Assigned Region',
                      _assignedRegionCtrl,
                      Icons.place_outlined,
                    ),
                    _field(
                      isMm ? 'မှတ်ပုံတင်အမှတ် (NRC)' : 'NRC Number',
                      _nrcCtrl,
                      Icons.badge_outlined,
                    ),
                    _field(
                      isMm ? 'အရေးပေါ် ဆက်သွယ်ရန်ဖုန်း' : 'Emergency Contact Phone',
                      _emergencyContactCtrl,
                      Icons.contact_phone_outlined,
                    ),
                  ] else ...[
                    // Regular Citizen User Form
                    _field(
                      isMm ? 'နာမည်အပြည့်အစုံ' : 'Full Name',
                      _nameCtrl,
                      Icons.person_outline,
                    ),
                    _field(
                      isMm ? 'ဖုန်းနံပါတ်' : 'Phone Number',
                      _phoneCtrl,
                      Icons.phone_outlined,
                      helperText: 'Must start with +959 or 09 (9 or 10 digits total)',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBloodType,
                        decoration: InputDecoration(
                          labelText: isMm ? 'သွေးအမျိုးအစား' : 'Blood Type',
                          hintText: isMm ? 'သွေးအမျိုးအစား ရွေးချယ်ပါ' : 'Select Blood Type',
                          prefixIcon: Icon(
                            Icons.bloodtype_outlined,
                            color: _editing ? AppTheme.primaryRed : AppTheme.subtleGrey,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              isMm ? 'မသိပါ / မသတ်မှတ်ထားပါ' : 'Unknown / Not Specified',
                              style: const TextStyle(color: AppTheme.subtleGrey),
                            ),
                          ),
                          ..._bloodTypes.map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Row(
                                children: [
                                  const Icon(Icons.water_drop, color: AppTheme.primaryRed, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    type,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: _editing
                            ? (val) {
                                setState(() {
                                  _selectedBloodType = val;
                                });
                              }
                            : null,
                      ),
                    ),
                    _field(
                      isMm ? 'ရောဂါအခံနှင့် ဆေးမှတ်တမ်း' : 'Medical Conditions & Allergies',
                      _medicalCtrl,
                      Icons.medical_information_outlined,
                      maxLines: 3,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Action Buttons ──────────────────────────────────
                  if (_editing) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSaving
                              ? (isMm ? 'သိမ်းဆည်းနေပါသည်...' : 'Saving...')
                              : (isMm ? 'အချက်အလက်များ သိမ်းဆည်းမည်' : 'Save Changes'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: _isSaving ? null : _save,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _editing = false);
                          _loadData();
                        },
                        child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
                      ),
                    ),
                  ] else ...[
                    if (!isOrg) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.history),
                          label: Text('View SOS History Records (${_history.length})'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryRed,
                            side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                          ),
                          onPressed: _showHistoryModal,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(isMm ? 'အချက်အလက် ပြင်ဆင်ရန်' : 'Edit Profile Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textDark,
                          side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey, width: 1.5),
                        ),
                        onPressed: () => setState(() => _editing = true),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        enabled: _editing,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: _editing ? helperText : null,
          prefixIcon: Icon(icon, color: _editing ? AppTheme.primaryRed : AppTheme.subtleGrey),
        ),
      ),
    );
  }
}
