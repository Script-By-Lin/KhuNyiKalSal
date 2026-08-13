import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
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

  bool _isSubmitting = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    phoneCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    regionCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pick Organization Location',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Map
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: pickedPoint,
                          initialZoom: 15.0,
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
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          backgroundColor: Colors.black,
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
                SafeArea(
                  top: false,
                  child: Container(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint,
      {bool isEmail = false, bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: const TextStyle(color: Colors.black, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      _snack('Please fill required fields (Name, Email, Password)', AppTheme.primaryRed);
      return;
    }

    setState(() => _isSubmitting = true);

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
      _snack('✨ Rescue Organization Account Created!', AppTheme.primaryRed);
      if (mounted) context.pop(true);
    } catch (e) {
      _snack('Failed to create organization', Colors.red);
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Organization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_business, color: AppTheme.primaryRed, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'New Rescue Organization',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in the details below to register a new organization account.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              _input(nameCtrl, 'Organization Name (e.g. Bago Rescue)'),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.black, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2),
                          ),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _input(phoneCtrl, 'Phone Number')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _input(emailCtrl, 'Login Email', isEmail: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _input(passCtrl, 'Password', isPass: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _input(latCtrl, 'Latitude (e.g. 16.86)')),
                  const SizedBox(width: 10),
                  Expanded(child: _input(lngCtrl, 'Longitude (e.g. 96.19)')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.pin_drop, color: AppTheme.primaryRed, size: 20),
                    label: const Text('📍 PICK LOCATION ON MAP PIN',
                        style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickLocationOnMap(latCtrl, lngCtrl),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(child: _input(regionCtrl, 'Region (e.g. Yangon)')),
                  const SizedBox(width: 10),
                  Expanded(child: _input(addressCtrl, 'HQ Address')),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 24),
                  label: Text(_isSubmitting ? 'CREATING...' : 'CREATE ORGANIZATION',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
