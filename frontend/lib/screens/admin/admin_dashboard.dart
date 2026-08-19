import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _currentTabIndex = 1; // Default to SOS Radar

  // ── Organizations State ──────────────────────────────────────────
  final List<Map<String, dynamic>> _orgs = [];
  bool _loadingOrgs = true;
  String _orgSearchQuery = '';
  String _selectedOrgCategory = 'ALL';
  String _selectedOrgStatus = 'ALL';
  int _orgPage = 1;

  // ── SOS Emergencies & Abuse Radar State ──────────────────────────
  final List<Map<String, dynamic>> _emergencies = [];
  bool _loadingEmergencies = true;
  String _emergencySearchQuery = '';
  String _selectedSosFilter = 'ALL'; // 'ALL', 'ABUSE', 'PENDING', 'RESOLVED', 'CANCELLED'
  String _selectedSosType = 'ALL';
  int _emergencyPage = 1;

  // ── Announcements State ─────────────────────────────────────────
  final List<Map<String, dynamic>> _announcements = [];
  bool _loadingAnnouncements = true;
  String _announcementSearchQuery = '';
  String _selectedAnnouncementCategory = 'ALL';
  int _announcementPage = 1;

  // ── Support & Donation State ────────────────────────────────────
  bool _loadingSupport = true;
  bool _savingSupport = false;

  final _kbzNameCtrl = TextEditingController();
  final _kbzPhoneCtrl = TextEditingController();
  final _waveNameCtrl = TextEditingController();
  final _wavePhoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccNumCtrl = TextEditingController();
  final _bankAccNameCtrl = TextEditingController();
  final _mmqrPayloadCtrl = TextEditingController();
  final _mmqrImageUrlCtrl = TextEditingController();
  final _supportNoteCtrl = TextEditingController();

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  @override
  void dispose() {
    _kbzNameCtrl.dispose();
    _kbzPhoneCtrl.dispose();
    _waveNameCtrl.dispose();
    _wavePhoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccNumCtrl.dispose();
    _bankAccNameCtrl.dispose();
    _mmqrPayloadCtrl.dispose();
    _mmqrImageUrlCtrl.dispose();
    _supportNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    _fetchOrgs();
    _fetchEmergencies();
    _fetchAnnouncements();
    _fetchSupportInfo();
  }

  bool get _isMm => ref.read(settingsProvider).locale.languageCode == 'my';

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

  // ══════════════════════════════════════════════════════════════════════════
  // 1. ORGANIZATIONS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchOrgs() async {
    setState(() => _loadingOrgs = true);
    try {
      final res = await ApiService().getAdminOrgs();
      if (mounted) {
        setState(() {
          _orgs.clear();
          _orgs.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingOrgs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingOrgs = false);
        _snack(_isMm ? 'အဖွဲ့အစည်းများ ရယူရန် မအောင်မြင်ပါ' : 'Failed to load organizations', Colors.red);
      }
    }
  }

  Future<void> _deleteOrg(String accountId, String orgName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(_isMm ? 'အဖွဲ့အစည်း ဖျက်မည်လား?' : 'Delete Organization?', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(_isMm ? '"$orgName" အား ဖျက်ရန် သေချာပါသလား? ချိတ်ဆက်ထားသော ဒေတာများ အားလုံး ဖျက်ပစ်ပါမည်။' : 'Are you sure you want to remove "$orgName"? All linked records will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isMm ? 'ဖျက်မည်' : 'DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteAdminOrg(accountId);
      _snack(_isMm ? 'အဖွဲ့အစည်း အကောင့် အောင်မြင်စွာ ဖျက်ပြီးပါပြီ' : 'Organization deleted successfully', AppTheme.secondaryGreen);
      _fetchOrgs();
    } catch (e) {
      _snack(_isMm ? 'အဖွဲ့အစည်း ဖျက်ရန် မအောင်မြင်ပါ' : 'Failed to delete organization', Colors.red);
    }
  }

  Future<void> _pickLocationOnMap(TextEditingController latCtrl, TextEditingController lngCtrl) async {
    double? initLat = double.tryParse(latCtrl.text);
    double? initLng = double.tryParse(lngCtrl.text);
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
                        icon: const Icon(Icons.close, color: Colors.white),
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
                      initialZoom: 14.0,
                      onTap: (tapPos, point) {
                        setMapState(() => pickedPoint = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.khunyikalsal.emergency',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickedPoint,
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.location_on, color: AppTheme.primaryRed, size: 48),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('CONFIRM LOCATION', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        latCtrl.text = pickedPoint.latitude.toStringAsFixed(6);
                        lngCtrl.text = pickedPoint.longitude.toStringAsFixed(6);
                        Navigator.pop(ctx);
                      },
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

  void _openEditOrgModal(Map<String, dynamic> org) {
    final nameCtrl = TextEditingController(text: org['org_name'] ?? '');
    final phoneCtrl = TextEditingController(text: org['phone_number'] ?? '');
    final latCtrl = TextEditingController(text: org['geo_lat']?.toString() ?? '');
    final lngCtrl = TextEditingController(text: org['geo_lng']?.toString() ?? '');
    final regionCtrl = TextEditingController(text: org['operating_regions'] ?? '');
    final addressCtrl = TextEditingController(text: org['headquarters_address'] ?? '');
    String selectedCategory = org['category'] ?? 'Medical';
    final categories = ['Medical', 'Fire', 'Local Voluntary Org'];
    bool isActive = org['is_active'] ?? true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isMm ? 'အဖွဲ့အစည်း အကောင့် ပြင်ဆင်မည်' : 'Edit Organization Account',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _input(nameCtrl, _isMm ? 'အဖွဲ့အစည်း အမည်' : 'Organization Name'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: categories.contains(selectedCategory) ? selectedCategory : 'Medical',
                      decoration: InputDecoration(
                        labelText: _isMm ? 'အဖွဲ့အစည်း အမျိုးအစား' : 'Category',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: categories.map((cat) {
                        String label = cat;
                        if (_isMm) {
                          if (cat == 'Medical') label = 'ဆေးဘက်ဆိုင်ရာနှင့် လူနာတင်ယာဉ်';
                          if (cat == 'Fire') label = 'မီးသတ်နှင့် သဘာဝဘေး';
                          if (cat == 'Local Voluntary Org') label = 'ဒေသခံ ပရဟိတ လူမှုကူညီရေးအသင်း';
                        }
                        return DropdownMenuItem(value: cat, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                  ),
                  _input(phoneCtrl, _isMm ? 'အရေးပေါ် ဖုန်းနံပါတ်' : 'Hotline Phone Number', keyboardType: TextInputType.phone),
                  _input(regionCtrl, _isMm ? 'တာဝန်ထမ်းဆောင်သည့် ဒေသများ' : 'Operating Regions (e.g. Yangon, Bago)'),
                  _input(addressCtrl, _isMm ? 'ရုံးချုပ် လိပ်စာ' : 'Headquarters Address', maxLines: 2),
                  Row(
                    children: [
                      Expanded(child: _input(latCtrl, _isMm ? 'လတ္တီတွဒ်' : 'Latitude', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      const SizedBox(width: 8),
                      Expanded(child: _input(lngCtrl, _isMm ? 'လောင်ဂျီတွဒ်' : 'Longitude', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      IconButton(
                        icon: const Icon(Icons.map, color: AppTheme.primaryRed, size: 30),
                        onPressed: () => _pickLocationOnMap(latCtrl, lngCtrl),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: Text(_isMm ? 'အကောင့် အခြေအနေ (Active)' : 'Account Active Status', style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: isActive,
                    activeThumbColor: AppTheme.secondaryGreen,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        try {
                          await ApiService().updateAdminOrg(org['account_id'], {
                            'org_name': nameCtrl.text.trim(),
                            'phone_number': phoneCtrl.text.trim(),
                            'category': selectedCategory,
                            'operating_regions': regionCtrl.text.trim(),
                            'headquarters_address': addressCtrl.text.trim(),
                            'geo_lat': double.tryParse(latCtrl.text) ?? org['geo_lat'],
                            'geo_lng': double.tryParse(lngCtrl.text) ?? org['geo_lng'],
                            'is_active': isActive,
                          });
                          nav.pop();
                          _snack(_isMm ? 'အဖွဲ့အစည်း အချက်အလက် အောင်မြင်စွာ ပြင်ဆင်ပြီးပါပြီ' : 'Organization updated successfully', AppTheme.secondaryGreen);
                          _fetchOrgs();
                        } catch (e) {
                          _snack(_isMm ? 'အဖွဲ့အစည်း အချက်အလက် ပြင်ဆင်ရန် မအောင်မြင်ပါ' : 'Failed to update organization', Colors.red);
                        }
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isMm ? 'အချက်အလက် သိမ်းဆည်းမည်' : 'SAVE CHANGES',
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. SOS RADAR & ABUSE DETECTION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchEmergencies() async {
    setState(() => _loadingEmergencies = true);
    try {
      final res = await ApiService().getAdminEmergencies();
      if (mounted) {
        setState(() {
          _emergencies.clear();
          _emergencies.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingEmergencies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmergencies = false);
    }
  }

  Future<void> _cancelEmergency(String emergencyId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Cancel SOS Alert?'),
          ],
        ),
        content: const Text('This will forcefully mark this SOS emergency as Cancelled and notify responders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('FORCE CANCEL'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().adminCancelEmergency(emergencyId);
      _snack(_isMm ? 'အက်ဒမင်မှ အရေးပေါ် ခေါ်ဆိုမှုအား ပယ်ဖျက်ပြီးပါပြီ' : 'SOS Emergency cancelled by Admin', AppTheme.secondaryGreen);
      _fetchEmergencies();
    } catch (e) {
      _snack(_isMm ? 'အရေးပေါ် ခေါ်ဆိုမှု ပယ်ဖျက်ရန် မအောင်မြင်ပါ' : 'Failed to cancel emergency', Colors.red);
    }
  }

  Future<void> _banUser(String userId, String userName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(_isMm ? 'အကောင့်အား ပိတ်ပင် (Ban) မည်လား?' : 'Ban Abusive Account?'),
          ],
        ),
        content: Text(_isMm ? '"$userName" ၏ အကောင့်အား ပိတ်ပင်ရန် သေချာပါသလား?\n\nလက်ရှိ ဝင်ရောက်ထားသော စက်အားလုံးမှ အလိုအလျောက် ထွက်သွားမည် ဖြစ်ပြီး အကောင့်ဝင်ရောက်ခွင့် ပိတ်ပါမည်။' : 'Are you sure you want to ban "$userName"?\n\nAll active device sessions will be immediately terminated and login will be blocked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isMm ? 'အကောင့်ပိတ်မည်' : 'BAN ACCOUNT'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().adminBanUser(userId);
      _snack(_isMm ? 'အကောင့်အား ပိတ်ပင်ပြီး စက်အားလုံးမှ အကောင့်ထွက်လိုက်ပါပြီ' : 'User account banned and sessions revoked', Colors.red);
      _fetchEmergencies();
    } catch (e) {
      _snack(_isMm ? 'အကောင့် ပိတ်ပင်ရန် မအောင်မြင်ပါ' : 'Failed to ban user account', Colors.red);
    }
  }

  Future<void> _unbanUser(String userId, String userName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.secondaryGreen, size: 24),
            const SizedBox(width: 8),
            Text(_isMm ? 'အကောင့် ပိတ်ပင်မှုကို ပြန်ဖွင့်မည်လား?' : 'Unban User Account?'),
          ],
        ),
        content: Text(_isMm ? '"$userName" ၏ အရေးပေါ် စနစ် သုံးစွဲခွင့်ကို ပြန်လည်ဖွင့်ပေးမည်လား?' : 'Restore emergency system access for "$userName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isMm ? 'ပြန်လည်ဖွင့်ပေးမည်' : 'RESTORE ACCESS'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().adminUnbanUser(userId);
      _snack(_isMm ? 'အကောင့် အသုံးပြုခွင့်ကို အောင်မြင်စွာ ပြန်လည်ဖွင့်ပေးပြီးပါပြီ' : 'User account restored successfully', AppTheme.secondaryGreen);
      _fetchEmergencies();
    } catch (e) {
      _snack(_isMm ? 'အကောင့် ပြန်ဖွင့်ရန် မအောင်မြင်ပါ' : 'Failed to restore user', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. ANNOUNCEMENTS BULLETIN
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchAnnouncements() async {
    setState(() => _loadingAnnouncements = true);
    try {
      final res = await ApiService().getAnnouncements();
      if (mounted) {
        setState(() {
          _announcements.clear();
          _announcements.addAll(List<Map<String, dynamic>>.from(res.data));
          _loadingAnnouncements = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAnnouncements = false);
    }
  }

  void _openAnnouncementModal([Map<String, dynamic>? item]) {
    final titleCtrl = TextEditingController(text: item?['title'] ?? '');
    final contentCtrl = TextEditingController(text: item?['content'] ?? '');
    final authorCtrl = TextEditingController(text: item?['author_name'] ?? 'Emergency Command Center');
    String selectedCategory = item?['category'] ?? 'General';
    bool isPinned = item?['is_pinned'] == true;
    final categories = ['General', 'Urgent', 'Weather/Disaster', 'Blood Drive'];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item == null
                        ? (_isMm ? '📢 သတင်းကြေညာချက် အသစ်ထုတ်ပြန်မည်' : '📢 Post New Announcement')
                        : (_isMm ? 'သတင်းကြေညာချက် ပြင်ဆင်မည်' : 'Edit Announcement'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _input(titleCtrl, _isMm ? 'သတင်း ခေါင်းစဉ် (Headline)' : 'Announcement Title (Headline)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: categories.contains(selectedCategory) ? selectedCategory : 'General',
                      decoration: InputDecoration(
                        labelText: _isMm ? 'အမျိုးအစား' : 'Category',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: categories.map((c) {
                        String label = c;
                        if (_isMm) {
                          if (c == 'General') label = 'အထွေထွေ';
                          if (c == 'Urgent') label = 'အရေးပေါ်';
                          if (c == 'Weather/Disaster') label = 'ရာသီဥတု / သဘာဝဘေး';
                          if (c == 'Blood Drive') label = 'သွေးလှူဒါန်းမှု';
                        }
                        return DropdownMenuItem(value: c, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                  ),
                  _input(authorCtrl, _isMm ? 'ဌာန / ထုတ်ပြန်သူ (ဥပမာ အရေးပေါ် ကွပ်ကဲရေး စင်တာ)' : 'Author / Department (e.g. Disaster Relief Command)'),
                  _input(contentCtrl, _isMm ? 'အသေးစိတ် အကြောင်းအရာ' : 'Announcement Content / Details', maxLines: 4),
                  SwitchListTile(
                    title: Text(
                      _isMm ? 'အပေါ်ဆုံးတွင် အမြဲပြသထားမည် (Pin to Top)' : 'Pin to Top (Featured Bulletin)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: isPinned,
                    activeThumbColor: Colors.amber.shade900,
                    onChanged: (v) => setModalState(() => isPinned = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item == null
                              ? (_isMm ? 'သတင်းကြေညာချက် ထုတ်ပြန်မည်' : 'BROADCAST ANNOUNCEMENT')
                              : (_isMm ? 'အချက်အလက် သိမ်းဆည်းမည်' : 'SAVE CHANGES'),
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(ctx);
                        if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                          _snack(_isMm ? 'ခေါင်းစဉ်နှင့် အကြောင်းအရာ ဖြည့်သွင်းပါ' : 'Please provide title and content', Colors.red);
                          return;
                        }
                        try {
                          if (item == null) {
                            await ApiService().createAnnouncement({
                              'title': titleCtrl.text.trim(),
                              'content': contentCtrl.text.trim(),
                              'category': selectedCategory,
                              'author_name': authorCtrl.text.trim(),
                              'is_pinned': isPinned,
                            });
                            _snack(_isMm ? 'သတင်းကြေညာချက် အောင်မြင်စွာ ထုတ်ပြန်ပြီးပါပြီ' : 'Announcement broadcasted successfully', AppTheme.secondaryGreen);
                          } else {
                            await ApiService().updateAnnouncement(item['id'], {
                              'title': titleCtrl.text.trim(),
                              'content': contentCtrl.text.trim(),
                              'category': selectedCategory,
                              'author_name': authorCtrl.text.trim(),
                              'is_pinned': isPinned,
                            });
                            _snack(_isMm ? 'သတင်းကြေညာချက် ပြင်ဆင်ပြီးပါပြီ' : 'Announcement updated successfully', AppTheme.secondaryGreen);
                          }
                          nav.pop();
                          _fetchAnnouncements();
                        } catch (e) {
                          _snack(_isMm ? 'သတင်းကြေညာချက် သိမ်းဆည်းရန် မအောင်မြင်ပါ' : 'Failed to save announcement', Colors.red);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(_isMm ? 'သတင်းကြေညာချက် ဖျက်မည်လား?' : 'Delete Announcement?'),
        content: Text(_isMm ? 'ဤသတင်းကြေညာချက်အား ဖျက်ရန် သေချာပါသလား?' : 'Are you sure you want to remove this announcement bulletin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_isMm ? 'မလုပ်တော့ပါ' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isMm ? 'ဖျက်မည်' : 'DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteAnnouncement(id);
      _snack(_isMm ? 'သတင်းကြေညာချက် ဖျက်ပြီးပါပြီ' : 'Announcement deleted', AppTheme.secondaryGreen);
      _fetchAnnouncements();
    } catch (e) {
      _snack(_isMm ? 'သတင်းကြေညာချက် ဖျက်ရန် မအောင်မြင်ပါ' : 'Failed to delete announcement', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. SUPPORT US & DONATION SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchSupportInfo() async {
    setState(() => _loadingSupport = true);
    try {
      final res = await ApiService().getSupportInfo();
      if (mounted) {
        final d = res.data;
        setState(() {
          _kbzNameCtrl.text = d['kbz_pay_name'] ?? '';
          _kbzPhoneCtrl.text = d['kbz_pay_phone'] ?? '';
          _waveNameCtrl.text = d['wave_pay_name'] ?? '';
          _wavePhoneCtrl.text = d['wave_pay_phone'] ?? '';
          _bankNameCtrl.text = d['bank_name'] ?? '';
          _bankAccNumCtrl.text = d['bank_account_number'] ?? '';
          _bankAccNameCtrl.text = d['bank_account_name'] ?? '';
          _mmqrPayloadCtrl.text = d['mmqr_payload'] ?? '';
          _mmqrImageUrlCtrl.text = d['mmqr_image_url'] ?? '';
          _supportNoteCtrl.text = d['note_message'] ?? '';
          _loadingSupport = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSupport = false);
    }
  }

  Future<void> _saveSupportInfo() async {
    setState(() => _savingSupport = true);
    try {
      await ApiService().updateSupportInfo({
        'kbz_pay_name': _kbzNameCtrl.text.trim(),
        'kbz_pay_phone': _kbzPhoneCtrl.text.trim(),
        'wave_pay_name': _waveNameCtrl.text.trim(),
        'wave_pay_phone': _wavePhoneCtrl.text.trim(),
        'bank_name': _bankNameCtrl.text.trim(),
        'bank_account_number': _bankAccNumCtrl.text.trim(),
        'bank_account_name': _bankAccNameCtrl.text.trim(),
        'mmqr_payload': _mmqrPayloadCtrl.text.trim(),
        'mmqr_image_url': _mmqrImageUrlCtrl.text.trim(),
        'note_message': _supportNoteCtrl.text.trim(),
      });
      _snack(_isMm ? 'လှူဒါန်းထောက်ပံ့မှု အချက်အလက်များ သိမ်းဆည်းပြီးပါပြီ' : 'Support & Donation details updated successfully', AppTheme.secondaryGreen);
      setState(() => _savingSupport = false);
      _fetchSupportInfo();
    } catch (e) {
      setState(() => _savingSupport = false);
      _snack(_isMm ? 'အချက်အလက် သိမ်းဆည်းရန် မအောင်မြင်ပါ' : 'Failed to update support info', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    // Badges calculation
    final activeAlerts = _emergencies.where((e) => e['status'] == 'pending' || e['status'] == 'accepted').length;
    final abuseAlerts = _emergencies.where((e) => e['is_suspected_abuse'] == true).length;
    final urgentAlertBadge = activeAlerts + abuseAlerts;

    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryRed, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMm ? 'အက်ဒမင် ကွပ်ကဲရေး' : 'Super Admin Command',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Text(
                    _getTabSubtitle(isMm),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
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
          _buildOrganizationsTab(),
          _buildEmergenciesAndAbuseTab(),
          _buildAnnouncementsTab(),
          _buildSupportTab(),
          _buildAdminServicesTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: borderCol, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
                  icon: Icons.apartment_outlined,
                  activeIcon: Icons.apartment_rounded,
                  label: isMm ? 'အဖွဲ့များ' : 'Orgs',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.radar_outlined,
                  activeIcon: Icons.radar_rounded,
                  label: isMm ? 'အရေးပေါ်' : 'SOS Radar',
                  badgeCount: urgentAlertBadge > 0 ? urgentAlertBadge : null,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign_rounded,
                  label: isMm ? 'သတင်းလွှာ' : 'Bulletins',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.volunteer_activism_outlined,
                  activeIcon: Icons.volunteer_activism_rounded,
                  label: isMm ? 'အလှူငွေ' : 'Support',
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

  String _getTabSubtitle(bool isMm) {
    switch (_currentTabIndex) {
      case 0:
        return isMm ? 'အဖွဲ့အစည်းများနှင့် အကောင့်များ' : 'Organization Registry & Accounts';
      case 1:
        return isMm ? 'SOS အရေးပေါ်နှင့် လုံခြုံရေး စောင့်ကြည့်မှု' : 'SOS Radar & Abuse Intelligence';
      case 2:
        return isMm ? 'တရားဝင် သတင်းလွှာများ စီမံခန့်ခွဲမှု' : 'Official Broadcast Bulletins';
      case 3:
        return isMm ? 'အလှူငွေနှင့် ဘဏ်အကောင့် ဆက်တင်များ' : 'Donation & Bank Info Settings';
      case 4:
        return isMm ? 'အကောင့်၊ ဘာသာစကားနှင့် ဆက်တင်များ' : 'Profile, Settings & Security';
      default:
        return isMm ? 'ကွပ်ကဲရေးစင်တာ' : 'Command Center';
    }
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _currentTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryRed.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? AppTheme.primaryRed : AppTheme.subtleGrey,
                    size: 22,
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryRed : AppTheme.subtleGrey,
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

  // ── Tab 1: Organizations ────────────────────────────────────────────────
  Widget _buildOrganizationsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : Colors.black87;

    final filteredOrgs = _orgs.where((o) {
      // Category filter
      if (_selectedOrgCategory != 'ALL' && (o['category'] ?? '') != _selectedOrgCategory) {
        return false;
      }
      // Status filter
      if (_selectedOrgStatus == 'ACTIVE' && o['is_active'] == false) return false;
      if (_selectedOrgStatus == 'INACTIVE' && o['is_active'] != false) return false;

      // Search query
      if (_orgSearchQuery.trim().isEmpty) return true;
      final name = (o['org_name'] ?? '').toString().toLowerCase();
      final region = (o['operating_regions'] ?? '').toString().toLowerCase();
      final category = (o['category'] ?? '').toString().toLowerCase();
      final phone = (o['phone_number'] ?? '').toString().toLowerCase();
      final query = _orgSearchQuery.trim().toLowerCase();
      return name.contains(query) || region.contains(query) || category.contains(query) || phone.contains(query);
    }).toList();

    // Pagination slice
    final totalItems = filteredOrgs.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final safePage = totalPages == 0 ? 1 : _orgPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final pageOrgs = totalItems == 0 ? <Map<String, dynamic>>[] : filteredOrgs.skip(startIndex).take(_pageSize).toList();

    return Column(
      children: [
        // Filter & Search Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _orgSearchQuery = val;
                          _orgPage = 1;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search organizations by name, region, phone...',
                        hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await context.push('/admin/create-org');
                      _fetchOrgs();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in ['ALL', 'Medical', 'Fire', 'Local Voluntary Org'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat == 'ALL' ? 'All Types' : cat, style: const TextStyle(fontSize: 11)),
                          selected: _selectedOrgCategory == cat,
                          selectedColor: AppTheme.primaryRed,
                          labelStyle: TextStyle(
                            color: _selectedOrgCategory == cat ? Colors.white : textPrimary,
                            fontWeight: _selectedOrgCategory == cat ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedOrgCategory = cat;
                                _orgPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(height: 20, width: 1, color: borderCol),
                    const SizedBox(width: 8),
                    for (final status in ['ALL', 'ACTIVE', 'INACTIVE'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status == 'ALL' ? 'All Status' : status, style: const TextStyle(fontSize: 11)),
                          selected: _selectedOrgStatus == status,
                          selectedColor: status == 'ACTIVE' ? AppTheme.secondaryGreen : Colors.grey.shade700,
                          labelStyle: TextStyle(
                            color: _selectedOrgStatus == status ? Colors.white : textPrimary,
                            fontWeight: _selectedOrgStatus == status ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedOrgStatus = status;
                                _orgPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List & Content
        Expanded(
          child: _loadingOrgs
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : totalItems == 0
                  ? const Center(child: Text('No organizations found matching query'))
                  : RefreshIndicator(
                      onRefresh: _fetchOrgs,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageOrgs.length,
                        itemBuilder: (ctx, i) {
                          final org = pageOrgs[i];
                          final orgName = org['org_name'] ?? 'Unknown Org';
                          final category = org['category'] ?? 'Rescue';
                          final phone = org['phone_number'] ?? 'N/A';
                          final regions = org['operating_regions'] ?? 'Myanmar';
                          final address = org['headquarters_address'] ?? 'No Address Specified';
                          final isActive = org['is_active'] ?? true;
                          final accountId = org['account_id'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderCol),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.apartment_rounded, color: AppTheme.primaryRed, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              orgName,
                                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$category  •  Regions: $regions',
                                              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? AppTheme.secondaryGreen.withValues(alpha: 0.15)
                                              : Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isActive ? 'ACTIVE' : 'INACTIVE',
                                          style: TextStyle(
                                            color: isActive ? AppTheme.secondaryGreen : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '📞 Hotline: $phone',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '📍 $address',
                                    style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: borderCol),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('EDIT ORG', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _openEditOrgModal(org),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.delete_outline, size: 14),
                                        label: const Text('DELETE', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _deleteOrg(accountId, orgName),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),

        // Pagination Bar
        _buildPaginationBar(
          currentPage: safePage,
          totalItems: totalItems,
          pageSize: _pageSize,
          onPageChanged: (newPage) => setState(() => _orgPage = newPage),
        ),
      ],
    );
  }

  // ── Tab 2: SOS & Abuse Radar ────────────────────────────────────────────
  Widget _buildEmergenciesAndAbuseTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : Colors.black87;

    final totalAlerts = _emergencies.length;
    final pendingCount = _emergencies.where((e) => e['status'] == 'pending' || e['status'] == 'accepted').length;
    final abuseCount = _emergencies.where((e) => e['is_suspected_abuse'] == true).length;
    final completedCount = _emergencies.where((e) => e['status'] == 'completed' || e['status'] == 'resolved').length;

    // Filter emergencies
    final filteredEmergencies = _emergencies.where((e) {
      // Status filter
      if (_selectedSosFilter == 'ABUSE' && e['is_suspected_abuse'] != true) {
        return false;
      } else if (_selectedSosFilter == 'PENDING' && (e['status'] != 'pending' && e['status'] != 'accepted')) {
        return false;
      } else if (_selectedSosFilter == 'RESOLVED' && (e['status'] != 'completed' && e['status'] != 'resolved')) {
        return false;
      } else if (_selectedSosFilter == 'CANCELLED' && e['status'] != 'cancelled') {
        return false;
      }

      // Type filter
      if (_selectedSosType != 'ALL') {
        final typeUpper = (e['type'] ?? '').toString().toUpperCase();
        if (typeUpper != _selectedSosType) return false;
      }

      // Search query
      if (_emergencySearchQuery.trim().isEmpty) return true;
      final name = (e['user_name'] ?? '').toString().toLowerCase();
      final phone = (e['user_phone'] ?? '').toString().toLowerCase();
      final type = (e['type'] ?? '').toString().toLowerCase();
      final status = (e['status'] ?? '').toString().toLowerCase();
      final orgName = (e['assigned_org_name'] ?? '').toString().toLowerCase();
      final q = _emergencySearchQuery.trim().toLowerCase();
      return name.contains(q) || phone.contains(q) || type.contains(q) || status.contains(q) || orgName.contains(q);
    }).toList();

    // Pagination slice
    final totalItems = filteredEmergencies.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final safePage = totalPages == 0 ? 1 : _emergencyPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final pageAlerts = totalItems == 0 ? <Map<String, dynamic>>[] : filteredEmergencies.skip(startIndex).take(_pageSize).toList();

    return Column(
      children: [
        // Interactive Quick Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _statBox(
                  'TOTAL SOS',
                  '$totalAlerts',
                  AppTheme.primaryRed,
                  isSelected: _selectedSosFilter == 'ALL',
                  onTap: () => setState(() {
                    _selectedSosFilter = 'ALL';
                    _emergencyPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  'ACTIVE / PENDING',
                  '$pendingCount',
                  Colors.orange,
                  isSelected: _selectedSosFilter == 'PENDING',
                  onTap: () => setState(() {
                    _selectedSosFilter = 'PENDING';
                    _emergencyPage = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox(
                  '🚨 ABUSE FLAGGED',
                  '$abuseCount',
                  Colors.purple,
                  isSelected: _selectedSosFilter == 'ABUSE',
                  onTap: () => setState(() {
                    _selectedSosFilter = 'ABUSE';
                    _emergencyPage = 1;
                  }),
                ),
              ),
            ],
          ),
        ),

        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  setState(() {
                    _emergencySearchQuery = val;
                    _emergencyPage = 1;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search alerts by citizen name, phone, type, status...',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
                ),
              ),
              const SizedBox(height: 8),
              // Status & Type Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(label: 'All ($totalAlerts)', filterKey: 'ALL'),
                    _filterChip(label: '🚨 Abuse ($abuseCount)', filterKey: 'ABUSE', activeColor: Colors.purple),
                    _filterChip(label: '⏳ Active ($pendingCount)', filterKey: 'PENDING', activeColor: Colors.orange),
                    _filterChip(label: '✅ Resolved ($completedCount)', filterKey: 'RESOLVED', activeColor: AppTheme.secondaryGreen),
                    _filterChip(label: '❌ Cancelled', filterKey: 'CANCELLED', activeColor: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Container(height: 20, width: 1, color: borderCol),
                    const SizedBox(width: 8),
                    // Emergency Type selector
                    for (final type in ['ALL', 'MEDICAL', 'FIRE', 'ACCIDENT', 'NATURAL DISASTER'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(type == 'ALL' ? 'All Types' : type, style: const TextStyle(fontSize: 11)),
                          selected: _selectedSosType == type,
                          selectedColor: Colors.blueGrey,
                          labelStyle: TextStyle(
                            color: _selectedSosType == type ? Colors.white : textPrimary,
                            fontWeight: _selectedSosType == type ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedSosType = type;
                                _emergencyPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List of Emergencies
        Expanded(
          child: _loadingEmergencies
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : totalItems == 0
                  ? const Center(child: Text('No emergency records found matching filters'))
                  : RefreshIndicator(
                      onRefresh: _fetchEmergencies,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageAlerts.length,
                        itemBuilder: (ctx, i) {
                          final e = pageAlerts[i];
                          final emergencyId = e['emergency_id'] ?? '';
                          final userId = e['user_id'] ?? '';
                          final userName = e['user_name'] ?? 'Citizen';
                          final userPhone = e['user_phone'] ?? '';
                          final userActive = e['user_is_active'] != false;
                          final type = (e['type'] ?? '').toString().toUpperCase();
                          final status = (e['status'] ?? '').toString().toUpperCase();
                          final isAbuse = e['is_suspected_abuse'] == true;
                          final abuseReason = e['abuse_flag_reason'] ?? '';
                          final orgName = e['assigned_org_name'] ?? 'Unassigned';
                          final date = (e['created_at'] ?? '').toString().split('T').first;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isAbuse ? Colors.purple.shade400 : borderCol,
                                width: isAbuse ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isAbuse
                                      ? Colors.purple.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.sos_rounded, color: AppTheme.primaryRed, size: 24),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$type EMERGENCY',
                                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textPrimary),
                                          ),
                                          Text(
                                            'Citizen: $userName • 📞 $userPhone',
                                            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (status == 'ACCEPTED' || status == 'COMPLETED')
                                            ? AppTheme.secondaryGreen.withValues(alpha: 0.15)
                                            : (status == 'CANCELLED' ? Colors.grey.shade200 : Colors.orange.withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: (status == 'ACCEPTED' || status == 'COMPLETED')
                                              ? AppTheme.secondaryGreen
                                              : (status == 'CANCELLED' ? Colors.grey.shade700 : Colors.orange),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Assigned: $orgName  •  Date: $date',
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 12),
                                ),

                                if (isAbuse) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.purpleAccent, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'SUSPECTED ABUSE: $abuseReason',
                                            style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                Divider(height: 1, color: borderCol),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (status != 'CANCELLED' && status != 'COMPLETED') ...[
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.cancel_outlined, size: 14),
                                        label: const Text('CANCEL SOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade800,
                                          side: BorderSide(color: Colors.orange.shade800),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () => _cancelEmergency(emergencyId),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (userActive) ...[
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.block, size: 14),
                                        label: const Text('BAN USER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () => _banUser(userId, userName),
                                      ),
                                    ] else ...[
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle_outline, size: 14),
                                        label: const Text('UNBAN USER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.secondaryGreen,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () => _unbanUser(userId, userName),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),

        // Pagination Bar
        _buildPaginationBar(
          currentPage: safePage,
          totalItems: totalItems,
          pageSize: _pageSize,
          onPageChanged: (newPage) => setState(() => _emergencyPage = newPage),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required String filterKey,
    Color activeColor = AppTheme.primaryRed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedSosFilter == filterKey;
    final textPrimary = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        selectedColor: activeColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedSosFilter = filterKey;
              _emergencyPage = 1;
            });
          }
        },
      ),
    );
  }

  // ── Tab 3: Announcements ────────────────────────────────────────────────
  Widget _buildAnnouncementsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : Colors.black87;

    final filteredAnnouncements = _announcements.where((a) {
      if (_selectedAnnouncementCategory != 'ALL' && (a['category'] ?? '') != _selectedAnnouncementCategory) {
        return false;
      }
      if (_announcementSearchQuery.trim().isEmpty) return true;
      final title = (a['title'] ?? '').toString().toLowerCase();
      final content = (a['content'] ?? '').toString().toLowerCase();
      final author = (a['author_name'] ?? '').toString().toLowerCase();
      final q = _announcementSearchQuery.trim().toLowerCase();
      return title.contains(q) || content.contains(q) || author.contains(q);
    }).toList();

    // Pagination slice
    final totalItems = filteredAnnouncements.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final safePage = totalPages == 0 ? 1 : _announcementPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final pageAnnouncements = totalItems == 0 ? <Map<String, dynamic>>[] : filteredAnnouncements.skip(startIndex).take(_pageSize).toList();

    return Column(
      children: [
        // Filter & Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _announcementSearchQuery = val;
                          _announcementPage = 1;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search bulletins...',
                        hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.campaign, size: 18),
                    label: const Text('POST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _openAnnouncementModal(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in ['ALL', 'General', 'Urgent', 'Weather/Disaster', 'Blood Drive'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat == 'ALL' ? 'All Bulletins' : cat, style: const TextStyle(fontSize: 11)),
                          selected: _selectedAnnouncementCategory == cat,
                          selectedColor: AppTheme.primaryRed,
                          labelStyle: TextStyle(
                            color: _selectedAnnouncementCategory == cat ? Colors.white : textPrimary,
                            fontWeight: _selectedAnnouncementCategory == cat ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedAnnouncementCategory = cat;
                                _announcementPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loadingAnnouncements
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : totalItems == 0
                  ? const Center(child: Text('No announcements found'))
                  : RefreshIndicator(
                      onRefresh: _fetchAnnouncements,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageAnnouncements.length,
                        itemBuilder: (ctx, i) {
                          final a = pageAnnouncements[i];
                          final id = a['id'] ?? '';
                          final title = a['title'] ?? 'Notice';
                          final content = a['content'] ?? '';
                          final category = a['category'] ?? 'General';
                          final author = a['author_name'] ?? 'Admin';
                          final isPinned = a['is_pinned'] == true;
                          final date = (a['created_at'] ?? '').toString().split('T').first;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPinned ? Colors.amber.shade600 : borderCol,
                                width: isPinned ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isPinned) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade900,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.push_pin, size: 12, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text('PINNED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          category,
                                          style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        date,
                                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade500, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    title,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    content,
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13, height: 1.4),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '✍️ By $author',
                                    style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 10),
                                  Divider(height: 1, color: borderCol),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('Edit'),
                                        onPressed: () => _openAnnouncementModal(a),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        onPressed: () => _deleteAnnouncement(id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),

        // Pagination Bar
        _buildPaginationBar(
          currentPage: safePage,
          totalItems: totalItems,
          pageSize: _pageSize,
          onPageChanged: (newPage) => setState(() => _announcementPage = newPage),
        ),
      ],
    );
  }

  // ── Tab 4: Support & Bank Info Settings ─────────────────────────────────
  Widget _buildSupportTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    if (_loadingSupport) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.volunteer_activism, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Support Us Channel Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Updates will be broadcasted to all citizens in real-time.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // KBZ Pay
          _supportCard(
            title: 'KBZPay Settings',
            icon: Icons.account_balance_wallet,
            color: Colors.blue.shade700,
            cardBg: cardBg,
            borderCol: borderCol,
            children: [
              _input(_kbzNameCtrl, 'KBZPay Receiver Name (e.g. Khu Nyi Kal Sal Emergency)'),
              _input(_kbzPhoneCtrl, 'KBZPay Account Phone Number (e.g. 09123456789)', keyboardType: TextInputType.phone),
            ],
          ),
          const SizedBox(height: 16),

          // Wave Pay
          _supportCard(
            title: 'WavePay Settings',
            icon: Icons.phone_android,
            color: Colors.amber.shade800,
            cardBg: cardBg,
            borderCol: borderCol,
            children: [
              _input(_waveNameCtrl, 'WavePay Receiver Name'),
              _input(_wavePhoneCtrl, 'WavePay Phone Number', keyboardType: TextInputType.phone),
            ],
          ),
          const SizedBox(height: 16),

          // Bank Transfer
          _supportCard(
            title: 'Direct Bank Transfer',
            icon: Icons.account_balance,
            color: Colors.teal.shade700,
            cardBg: cardBg,
            borderCol: borderCol,
            children: [
              _input(_bankNameCtrl, 'Bank Name (e.g. KBZ Bank, CB Bank, AYA Bank)'),
              _input(_bankAccNumCtrl, 'Bank Account Number'),
              _input(_bankAccNameCtrl, 'Account Holder Name'),
            ],
          ),
          const SizedBox(height: 16),

          // MMQR & Note
          _supportCard(
            title: 'MMQR National Standard & QR Image',
            icon: Icons.qr_code_2_rounded,
            color: Colors.purple.shade700,
            cardBg: cardBg,
            borderCol: borderCol,
            children: [
              _input(
                _mmqrImageUrlCtrl,
                'MMQR QR Code Image URL or Base64 String',
                helperText: 'Enter an HTTPS image link or base64 data URI (data:image/png;base64,...)',
                onChanged: (_) => setState(() {}),
                suffixIcon: _mmqrImageUrlCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _mmqrImageUrlCtrl.clear()),
                      )
                    : null,
              ),
              // Preset & Quick helper buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Use Sample MMQR Link', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          _mmqrImageUrlCtrl.text =
                              'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=00020101021126560010A00000072701260010KBZPAY0112097891234565204000053031045802MM5918KHUNYIKALSAL_FUND6006YANGON6304ABCD';
                          _mmqrPayloadCtrl.text =
                              '00020101021126560010A00000072701260010KBZPAY0112097891234565204000053031045802MM5918KHUNYIKALSAL_FUND6006YANGON6304ABCD';
                        });
                      },
                    ),
                    if (_mmqrImageUrlCtrl.text.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: const Text('Remove Image', style: TextStyle(fontSize: 11, color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => setState(() => _mmqrImageUrlCtrl.clear()),
                      ),
                  ],
                ),
              ),

              // Visual QR Code Live Preview
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Text(
                        'Live MMQR Picture Preview:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildQrImagePreview(_mmqrImageUrlCtrl.text.trim(), isDark),
                    ],
                  ),
                ),
              ),

              _input(_mmqrPayloadCtrl, 'MMQR Raw Payload / String (For copy action & QR parsers)', maxLines: 2),
              _input(_supportNoteCtrl, 'Public Thank You / Donation Note', maxLines: 3),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _savingSupport
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_savingSupport ? 'SAVING DETAILS...' : 'SAVE & BROADCAST CHANGES', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: _savingSupport ? null : _saveSupportInfo,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _supportCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderCol,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMON HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalItems,
    required int pageSize,
    required Function(int) onPageChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

    final totalPages = (totalItems / pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    final startItem = totalItems == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final endItem = (currentPage * pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderCol)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of $totalItems',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                tooltip: 'Previous Page',
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $currentPage of $totalPages',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryRed),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrImagePreview(String src, bool isDark) {
    if (src.isEmpty) {
      return Container(
        height: 160,
        width: 160,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 48, color: isDark ? Colors.white30 : Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              'No QR Picture Set',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    Widget imgWidget;
    if (src.startsWith('data:image') || (!src.startsWith('http://') && !src.startsWith('https://') && src.length > 100)) {
      try {
        final cleanBase64 = src.contains(',') ? src.split(',').last : src;
        final bytes = base64Decode(cleanBase64.trim());
        imgWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Text('Invalid Base64 Image', style: TextStyle(color: Colors.red, fontSize: 11)),
          ),
        );
      } catch (_) {
        imgWidget = const Center(
          child: Text('Invalid Base64 format', style: TextStyle(color: Colors.red, fontSize: 11)),
        );
      }
    } else {
      imgWidget = Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Failed to load image from URL', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 11)),
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryRed));
        },
      );
    }

    return Container(
      height: 170,
      width: 170,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imgWidget,
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 2,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

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
  // 5. SERVICES, PROFILE, SETTINGS & LOGOUT TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAdminServicesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Admin Profile Card ──────────────────────────────────────
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
                    child: Icon(Icons.admin_panel_settings, color: AppTheme.primaryRed, size: 30),
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
                              'Super Administrator',
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
                            child: const Text(
                              'SUPER ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        auth.email ?? 'admin@khunyikalsal.org',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Account & Security ──────────────────────────────────────
          Text(
            isMm ? 'အကောင့် လုံခြုံရေး' : 'Account & Security',
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
                    isMm ? 'စကားဝှက်အသစ် သတ်မှတ်ပါ' : 'Update your administrator password',
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
                    isMm ? 'ဝင်ရောက်ထားသော စက်များ စီမံရန်' : 'Manage active admin sessions',
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
              isMm ? 'အဖွဲ့အစည်းများနှင့် အရေးပေါ် ဒေတာများကို အသစ်ရယူပါ' : 'Reload all organization and emergency telemetry',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            onTap: () {
              _fetchAllData();
              _snack('All data refreshed', AppTheme.secondaryGreen);
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
                  isMm ? 'အက်ဒမင် အကောင့်မှ ထွက်မည်' : 'SIGN OUT OF ADMIN',
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _confirmLogout(isMm),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(bool isMm) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isMm ? 'အကောင့်မှ ထွက်ခွာမည်လား?' : 'Sign Out of Admin?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isMm
              ? 'သင်သည် အက်ဒမင်စနစ်မှ ထွက်ခွာရန် သေချာပါသလား?'
              : 'Are you sure you want to end your administrator session?',
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
            child: Text(isMm ? 'ထွက်မည်' : 'SIGN OUT'),
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
