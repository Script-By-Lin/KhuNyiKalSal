import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Organizations
  final List<Map<String, dynamic>> _orgs = [];
  bool _loadingOrgs = true;
  String _orgSearchQuery = '';

  // SOS Emergencies & Abuse Detection
  final List<Map<String, dynamic>> _emergencies = [];
  bool _loadingEmergencies = true;
  String _emergencySearchQuery = '';

  // Announcements
  final List<Map<String, dynamic>> _announcements = [];
  bool _loadingAnnouncements = true;

  // Support & Donation
  Map<String, dynamic>? _supportInfo;
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
  final _supportNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kbzNameCtrl.dispose();
    _kbzPhoneCtrl.dispose();
    _waveNameCtrl.dispose();
    _wavePhoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccNumCtrl.dispose();
    _bankAccNameCtrl.dispose();
    _mmqrPayloadCtrl.dispose();
    _supportNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    _fetchOrgs();
    _fetchEmergencies();
    _fetchAnnouncements();
    _fetchSupportInfo();
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
        _snack('Failed to load organizations', Colors.red);
      }
    }
  }

  Future<void> _deleteOrg(String accountId, String orgName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Organization?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "$orgName"? All linked records will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteAdminOrg(accountId);
      _snack('Organization deleted successfully', AppTheme.secondaryGreen);
      _fetchOrgs();
    } catch (e) {
      _snack('Failed to delete organization', Colors.red);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Organization Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _input(nameCtrl, 'Organization Name'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory) ? selectedCategory : 'Medical',
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                ),
                _input(phoneCtrl, 'Hotline Phone Number', keyboardType: TextInputType.phone),
                _input(regionCtrl, 'Operating Regions (e.g. Yangon, Bago)'),
                _input(addressCtrl, 'Headquarters Address', maxLines: 2),
                Row(
                  children: [
                    Expanded(child: _input(latCtrl, 'Latitude', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: _input(lngCtrl, 'Longitude', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    IconButton(
                      icon: const Icon(Icons.map, color: AppTheme.primaryRed, size: 30),
                      onPressed: () => _pickLocationOnMap(latCtrl, lngCtrl),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Account Active Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: isActive,
                  activeColor: AppTheme.secondaryGreen,
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
                        Navigator.pop(ctx);
                        _snack('Organization updated successfully', AppTheme.secondaryGreen);
                        _fetchOrgs();
                      } catch (e) {
                        _snack('Failed to update organization', Colors.red);
                      }
                    },
                    child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
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
      _snack('SOS Emergency cancelled by Admin', AppTheme.secondaryGreen);
      _fetchEmergencies();
    } catch (e) {
      _snack('Failed to cancel emergency', Colors.red);
    }
  }

  Future<void> _banUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Ban Abusive Account?'),
          ],
        ),
        content: Text('Are you sure you want to ban "$userName"?\n\nAll active device sessions will be immediately terminated and login will be blocked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('BAN ACCOUNT'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().adminBanUser(userId);
      _snack('User account has been banned and sessions terminated', AppTheme.secondaryGreen);
      _fetchEmergencies();
    } catch (e) {
      _snack('Failed to ban account', Colors.red);
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      await ApiService().adminUnbanUser(userId);
      _snack('User account unbanned and reactivated', AppTheme.secondaryGreen);
      _fetchEmergencies();
    } catch (e) {
      _snack('Failed to unban account', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. ANNOUNCEMENTS MANAGER
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

  void _openCreateAnnouncementModal([Map<String, dynamic>? item]) {
    final titleCtrl = TextEditingController(text: item?['title'] ?? '');
    final contentCtrl = TextEditingController(text: item?['content'] ?? '');
    final authorCtrl = TextEditingController(text: item?['author_name'] ?? 'Emergency Command Center');
    String selectedCategory = item?['category'] ?? 'General';
    bool isPinned = item?['is_pinned'] == true;
    final categories = ['General', 'Urgent', 'Weather/Disaster', 'Blood Drive'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                  item == null ? '📢 Post New Announcement' : 'Edit Announcement',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _input(titleCtrl, 'Announcement Title (Headline)'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory) ? selectedCategory : 'General',
                    decoration: InputDecoration(
                      labelText: 'Category',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                ),
                _input(authorCtrl, 'Author / Department (e.g. Disaster Relief Command)'),
                _input(contentCtrl, 'Announcement Content / Details', maxLines: 4),
                SwitchListTile(
                  title: const Text('Pin to Top (Featured Bulletin)', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: isPinned,
                  activeColor: Colors.amber.shade900,
                  onChanged: (v) => setModalState(() => isPinned = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: Text(item == null ? 'BROADCAST ANNOUNCEMENT' : 'SAVE CHANGES', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                        _snack('Please provide title and content', Colors.red);
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
                          _snack('Announcement broadcasted successfully', AppTheme.secondaryGreen);
                        } else {
                          await ApiService().updateAnnouncement(item['id'], {
                            'title': titleCtrl.text.trim(),
                            'content': contentCtrl.text.trim(),
                            'category': selectedCategory,
                            'author_name': authorCtrl.text.trim(),
                            'is_pinned': isPinned,
                          });
                          _snack('Announcement updated successfully', AppTheme.secondaryGreen);
                        }
                        Navigator.pop(ctx);
                        _fetchAnnouncements();
                      } catch (e) {
                        _snack('Failed to save announcement', Colors.red);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAnnouncement(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Announcement?'),
        content: const Text('Are you sure you want to remove this announcement bulletin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteAnnouncement(id);
      _snack('Announcement deleted', AppTheme.secondaryGreen);
      _fetchAnnouncements();
    } catch (e) {
      _snack('Failed to delete announcement', Colors.red);
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
          _supportInfo = d;
          _kbzNameCtrl.text = d['kbz_pay_name'] ?? '';
          _kbzPhoneCtrl.text = d['kbz_pay_phone'] ?? '';
          _waveNameCtrl.text = d['wave_pay_name'] ?? '';
          _wavePhoneCtrl.text = d['wave_pay_phone'] ?? '';
          _bankNameCtrl.text = d['bank_name'] ?? '';
          _bankAccNumCtrl.text = d['bank_account_number'] ?? '';
          _bankAccNameCtrl.text = d['bank_account_name'] ?? '';
          _mmqrPayloadCtrl.text = d['mmqr_payload'] ?? '';
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
        'note_message': _supportNoteCtrl.text.trim(),
      });
      _snack('Support & Donation details updated successfully', AppTheme.secondaryGreen);
      setState(() => _savingSupport = false);
      _fetchSupportInfo();
    } catch (e) {
      setState(() => _savingSupport = false);
      _snack('Failed to update support info', Colors.red);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppTheme.primaryRed, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Super Admin Command Center',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryRed,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.primaryRed,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded), text: 'Organizations'),
            Tab(icon: Icon(Icons.radar_rounded), text: 'SOS & Abuse Radar'),
            Tab(icon: Icon(Icons.campaign_rounded), text: 'Announcements'),
            Tab(icon: Icon(Icons.volunteer_activism_rounded), text: 'Support & Bank Info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrganizationsTab(),
          _buildEmergenciesAndAbuseTab(),
          _buildAnnouncementsTab(),
          _buildSupportTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Organizations ────────────────────────────────────────────────
  Widget _buildOrganizationsTab() {
    final filteredOrgs = _orgs.where((o) {
      if (_orgSearchQuery.trim().isEmpty) return true;
      final name = (o['org_name'] ?? '').toString().toLowerCase();
      final region = (o['operating_regions'] ?? '').toString().toLowerCase();
      final category = (o['category'] ?? '').toString().toLowerCase();
      final query = _orgSearchQuery.trim().toLowerCase();
      return name.contains(query) || region.contains(query) || category.contains(query);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
          child: Row(
            children: [
              _statBox('TOTAL ORGS', '${_orgs.length}', AppTheme.primaryRed),
              const SizedBox(width: 10),
              _statBox('ACTIVE', '${_orgs.where((o) => o['is_active'] == true).length}', AppTheme.secondaryGreen),
              const SizedBox(width: 10),
              _statBox('REGIONS', 'Yangon / Bago', Colors.blueGrey),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _orgSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search organization by name or region...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('ADD ORG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final result = await context.push<bool>('/admin/create-org');
                  if (result == true) _fetchOrgs();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingOrgs
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : filteredOrgs.isEmpty
                  ? const Center(child: Text('No rescue organization accounts found'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredOrgs.length,
                      itemBuilder: (ctx, i) {
                        final o = filteredOrgs[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.business, color: AppTheme.primaryRed, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o['org_name'] ?? 'Unknown Org',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('📞 ${o['phone_number']}  •  📍 ${o['operating_regions'] ?? 'Yangon'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.primaryRed),
                                onPressed: () => _openEditOrgModal(o),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                onPressed: () => _deleteOrg(o['account_id'], o['org_name']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Tab 2: SOS Radar & Abuse Control ────────────────────────────────────
  Widget _buildEmergenciesAndAbuseTab() {
    final filteredEmergencies = _emergencies.where((e) {
      if (_emergencySearchQuery.trim().isEmpty) return true;
      final name = (e['user_name'] ?? '').toString().toLowerCase();
      final phone = (e['user_phone'] ?? '').toString().toLowerCase();
      final type = (e['type'] ?? '').toString().toLowerCase();
      final status = (e['status'] ?? '').toString().toLowerCase();
      final q = _emergencySearchQuery.trim().toLowerCase();
      return name.contains(q) || phone.contains(q) || type.contains(q) || status.contains(q);
    }).toList();

    final totalAlerts = _emergencies.length;
    final pendingCount = _emergencies.where((e) => e['status'] == 'pending' || e['status'] == 'accepted').length;
    final abuseCount = _emergencies.where((e) => e['is_suspected_abuse'] == true).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
          child: Row(
            children: [
              _statBox('TOTAL SOS', '$totalAlerts', AppTheme.primaryRed),
              const SizedBox(width: 10),
              _statBox('ACTIVE / PENDING', '$pendingCount', Colors.orange),
              const SizedBox(width: 10),
              _statBox('🚨 ABUSE SUSPECTED', '$abuseCount', Colors.purple),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) => setState(() => _emergencySearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search alerts by citizen name, phone, or status...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        Expanded(
          child: _loadingEmergencies
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : filteredEmergencies.isEmpty
                  ? const Center(child: Text('No emergency records found'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: filteredEmergencies.length,
                      itemBuilder: (ctx, i) {
                        final e = filteredEmergencies[i];
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isAbuse ? Colors.purple.shade300 : Colors.grey.shade200,
                              width: isAbuse ? 2 : 1,
                            ),
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
                                        Text('$type EMERGENCY', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                        Text('Citizen: $userName • 📞 $userPhone', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
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
                              Text('Assigned: $orgName  •  Date: $date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              
                              if (isAbuse) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.purple.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.purple, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'SUSPECTED ABUSE: $abuseReason',
                                          style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
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
                                      onPressed: () => _unbanUser(userId),
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
      ],
    );
  }

  // ── Tab 3: Announcements Manager ─────────────────────────────────────────
  Widget _buildAnnouncementsTab() {
    final pinnedCount = _announcements.where((a) => a['is_pinned'] == true).length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
          child: Row(
            children: [
              _statBox('TOTAL POSTS', '${_announcements.length}', AppTheme.primaryRed),
              const SizedBox(width: 10),
              _statBox('PINNED', '$pinnedCount', Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('NEW POST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _openCreateAnnouncementModal(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingAnnouncements
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
              : _announcements.isEmpty
                  ? const Center(child: Text('No announcements posted yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: _announcements.length,
                      itemBuilder: (ctx, i) {
                        final a = _announcements[i];
                        final isPinned = a['is_pinned'] == true;
                        final category = a['category'] ?? 'General';
                        final date = (a['created_at'] ?? '').toString().split('T').first;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isPinned ? Colors.amber.shade300 : Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isPinned) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                                      child: Text('PINNED', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                                  const Spacer(),
                                  Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(a['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(a['content'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                                    onPressed: () => _openCreateAnnouncementModal(a),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteAnnouncement(a['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Tab 4: Support & Bank Info ───────────────────────────────────────────
  Widget _buildSupportTab() {
    if (_loadingSupport) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueGrey),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Configure official rescue fund donation accounts displayed on user mobile applications.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('📱 KBZPay Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _input(_kbzNameCtrl, 'KBZPay Account Name'),
          _input(_kbzPhoneCtrl, 'KBZPay Phone Number', keyboardType: TextInputType.phone),

          const SizedBox(height: 16),
          const Text('🌊 WavePay Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _input(_waveNameCtrl, 'WavePay Account Name'),
          _input(_wavePhoneCtrl, 'WavePay Phone Number', keyboardType: TextInputType.phone),

          const SizedBox(height: 16),
          const Text('🏛️ Bank Transfer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _input(_bankNameCtrl, 'Bank Name (e.g. KBZ Bank / AYA Bank)'),
          _input(_bankAccNumCtrl, 'Bank Account Number'),
          _input(_bankAccNameCtrl, 'Bank Account Name'),

          const SizedBox(height: 16),
          const Text('📷 MMQR & Official Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _input(_mmqrPayloadCtrl, 'MMQR Payload / Data'),
          _input(_supportNoteCtrl, 'Donation Purpose Note', maxLines: 3),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _savingSupport
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_savingSupport ? 'SAVING...' : 'SAVE DONATION SETTINGS', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _savingSupport ? null : _saveSupportInfo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  Widget _statBox(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
              style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
