import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  final List<Map<String, dynamic>> _orgs = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchOrgs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchOrgs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getAdminOrgs();
      if (mounted) {
        setState(() {
          _orgs.clear();
          _orgs.addAll(List<Map<String, dynamic>>.from(res.data));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load organization accounts', Colors.red);
      }
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

  Future<void> _pickLocationOnMap(
      TextEditingController latCtrl, TextEditingController lngCtrl) async {
    double? initLat = double.tryParse(latCtrl.text);
    double? initLng = double.tryParse(lngCtrl.text);
    
    LatLng pickedPoint = LatLng(initLat ?? 16.8661, initLng ?? 96.1951);
    final mapController = MapController();

    // Try to get real location if none is set
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
                // Header
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
                          '📍 Pin HQ Location\nLat: ${pickedPoint.latitude.toStringAsFixed(5)}, Lng: ${pickedPoint.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Interactive Map
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: pickedPoint,
                          initialZoom: 14.0,
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
                                width: 48,
                                height: 40,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryRed,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.business, color: Colors.white, size: 28),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: FloatingActionButton.small(
                          backgroundColor: AppTheme.primaryRed,
                          child: const Icon(Icons.my_location, color: Colors.white),
                          onPressed: () async {
                            try {
                              final pos = await LocationService.getCurrentLocation();
                              final newPos = LatLng(pos.latitude, pos.longitude);
                              setMapState(() {
                                pickedPoint = newPos;
                              });
                              mapController.move(newPos, 15.0);
                            } catch (_) {}
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Confirm Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('CONFIRM THIS PIN LOCATION',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _openAddOrgModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '16.8661');
    final lngCtrl = TextEditingController(text: '96.1951');
    final regionCtrl = TextEditingController(text: 'Yangon');
    final addressCtrl = TextEditingController(text: 'Station HQ');
    String selectedCategory = 'Medical';
    final categories = ['Medical', 'Fire', 'Crime'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
              const Row(
                children: [
                  Icon(Icons.add_business, color: AppTheme.primaryRed, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Create New Rescue Organization',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _input(nameCtrl, 'Organization Name (e.g. Bago Rescue)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedCategory = val);
                  },
                ),
              ),
              _input(emailCtrl, 'Login Email', isEmail: true),
              _input(passCtrl, 'Password', isPass: true),
              _input(phoneCtrl, 'Phone Number'),
              Row(
                children: [
                  Expanded(child: _input(latCtrl, 'Latitude (e.g. 16.86)')),
                  const SizedBox(width: 10),
                  Expanded(child: _input(lngCtrl, 'Longitude (e.g. 96.19)')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pin_drop, color: AppTheme.primaryRed, size: 18),
                    label: const Text('📍 PICK LOCATION ON MAP PIN',
                        style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickLocationOnMap(latCtrl, lngCtrl),
                  ),
                ),
              ),
              _input(regionCtrl, 'Operating Region (e.g. Yangon, Bago)'),
              _input(addressCtrl, 'HQ Address'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('CREATE ORGANIZATION ACCOUNT',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                      _snack('Please fill required fields', AppTheme.primaryRed);
                      return;
                    }
                    try {
                      await ApiService().createAdminOrg({
                        'org_name': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'password': passCtrl.text,
                        'phone_number': phoneCtrl.text.trim(),
                        'category': selectedCategory,
                        'geo_lat': double.tryParse(latCtrl.text) ?? 16.8661,
                        'geo_lng': double.tryParse(lngCtrl.text) ?? 96.1951,
                        'operating_regions': regionCtrl.text.trim(),
                        'headquarters_address': addressCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _fetchOrgs();
                      _snack('✨ Rescue Organization Account Created!',
                          AppTheme.primaryRed);
                    } catch (e) {
                      _snack('Failed to create organization', Colors.red);
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

  void _openEditOrgModal(Map<String, dynamic> org) {
    final nameCtrl = TextEditingController(text: org['org_name'] ?? '');
    final phoneCtrl = TextEditingController(text: org['phone_number'] ?? '');
    final latCtrl = TextEditingController(text: org['geo_lat']?.toString() ?? '');
    final lngCtrl = TextEditingController(text: org['geo_lng']?.toString() ?? '');
    final regionCtrl = TextEditingController(text: org['operating_regions'] ?? '');
    final addressCtrl = TextEditingController(text: org['headquarters_address'] ?? '');
    String selectedCategory = org['category'] ?? 'Medical';
    final categories = ['Medical', 'Fire', 'Crime'];
    bool isActive = org['is_active'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                const Row(
                  children: [
                    Icon(Icons.edit, color: AppTheme.primaryRed, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Edit Organization Account',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _input(nameCtrl, 'Organization Name'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory) ? selectedCategory : 'Medical',
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                ),
                _input(phoneCtrl, 'Phone Number'),
                Row(
                  children: [
                    Expanded(child: _input(latCtrl, 'Latitude')),
                    const SizedBox(width: 10),
                    Expanded(child: _input(lngCtrl, 'Longitude')),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.pin_drop, color: AppTheme.primaryRed, size: 18),
                      label: const Text('📍 RE-PIN LOCATION ON MAP',
                          style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _pickLocationOnMap(latCtrl, lngCtrl),
                    ),
                  ),
                ),
                _input(regionCtrl, 'Operating Region'),
                _input(addressCtrl, 'HQ Address'),
                Row(
                  children: [
                    const Text('Active Account Status: ',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      activeThumbColor: AppTheme.primaryRed,
                      onChanged: (val) => setModalState(() => isActive = val),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      try {
                        await ApiService().updateAdminOrg(org['account_id'], {
                          'org_name': nameCtrl.text.trim(),
                          'phone_number': phoneCtrl.text.trim(),
                          'category': selectedCategory,
                          'geo_lat': double.tryParse(latCtrl.text) ?? org['geo_lat'],
                          'geo_lng': double.tryParse(lngCtrl.text) ?? org['geo_lng'],
                          'operating_regions': regionCtrl.text.trim(),
                          'headquarters_address': addressCtrl.text.trim(),
                          'is_active': isActive,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchOrgs();
                        _snack('Organization updated successfully!', AppTheme.primaryRed);
                      } catch (e) {
                        _snack('Failed to update organization', Colors.red);
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

  void _deleteOrg(String accountId, String orgName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Organization?', style: TextStyle(color: Colors.black)),
        content: Text(
          'Are you sure you want to permanently delete "$orgName"? All associated volunteer accounts will also be deleted.',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService().deleteAdminOrg(accountId);
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchOrgs();
                _snack('Organization deleted', AppTheme.primaryRed);
              } catch (_) {
                _snack('Failed to delete organization', Colors.red);
              }
            },
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint,
      {bool isEmail = false, bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrgs = _orgs.where((o) {
      final name = (o['org_name'] ?? '').toString().toLowerCase();
      final region = (o['operating_regions'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || region.contains(query);
    }).toList();

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
                'Super Admin Control Panel',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchOrgs,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: _buildOrganizationsTab(filteredOrgs),
    );
  }

  Widget _buildOrganizationsTab(List<Map<String, dynamic>> filteredOrgs) {
    return Column(
        children: [
          // Stat Counters Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                _statBox('TOTAL ORGS', '${_orgs.length}', AppTheme.primaryRed),
                const SizedBox(width: 10),
                _statBox('ACTIVE', '${_orgs.where((o) => o['is_active'] == true).length}',
                    AppTheme.primaryRed),
                const SizedBox(width: 10),
                _statBox('REGIONS', 'Yangon/Bago', AppTheme.primaryRed),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search organization by name or region...',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.black38),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _openAddOrgModal,
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
                : filteredOrgs.isEmpty
                    ? const Center(
                        child: Text(
                          'No rescue organization accounts found',
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                      )
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
                              border: Border.all(
                                color: AppTheme.primaryRed.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryRed.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.business,
                                      color: AppTheme.primaryRed, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o['org_name'] ?? 'Unknown Org',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '✉️ ${o['email']}  •  📞 ${o['phone_number']}',
                                        style: const TextStyle(
                                            color: Colors.black87, fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '📍 ${o['operating_regions']} (${o['geo_lat']}, ${o['geo_lng']})',
                                        style: TextStyle(
                                            color: Colors.grey.shade400, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppTheme.primaryRed),
                                  onPressed: () => _openEditOrgModal(o),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  onPressed: () =>
                                      _deleteOrg(o['account_id'], o['org_name']),
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
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
