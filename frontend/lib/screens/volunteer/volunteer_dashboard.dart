import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class VolunteerDashboard extends ConsumerStatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  ConsumerState<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends ConsumerState<VolunteerDashboard> {
  final List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _isDutyActive = true;
  StreamSubscription? _wsSub;
  StreamSubscription? _locationSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _listenForAlerts();
    _startLocationStreaming();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadAlerts());
  }

  Future<void> _startLocationStreaming() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (_isDutyActive) {
        ApiService().updateVolunteerLocation(pos.latitude, pos.longitude);
      }
      _locationSub = LocationService.getLocationStream().listen((pos) {
        if (_isDutyActive) {
          ApiService().updateVolunteerLocation(pos.latitude, pos.longitude);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadAlerts() async {
    try {
      final res = await ApiService().getVolunteerAlerts();
      if (mounted) {
        setState(() {
          _alerts.clear();
          _alerts.addAll(List<Map<String, dynamic>>.from(res.data));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForAlerts() {
    final auth = ref.read(authProvider.notifier);
    _wsSub = auth.ws.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event'];
      if (eventType == 'SOS_CREATED') {
        _loadAlerts();
      } else if (eventType == 'EMERGENCY_COMPLETED' || eventType == 'SOS_CANCELLED') {
        setState(() {
          _alerts.removeWhere((a) => a['emergency_id'] == event['emergency_id']);
        });
      }
    });
  }

  Future<void> _respond(String emergencyId, String action) async {
    try {
      await ApiService().respondToEmergency(emergencyId, action);
      if (mounted) {
        if (action == 'accept') {
          setState(() {
            final idx = _alerts.indexWhere((a) => a['emergency_id'] == emergencyId);
            if (idx != -1) {
              _alerts[idx]['status'] = 'accepted';
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Emergency Accepted — Streaming live location to victim!'),
              backgroundColor: AppTheme.primaryRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _alerts.removeWhere((a) => a['emergency_id'] == emergencyId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Emergency Rejected'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to respond to emergency alert')),
        );
      }
    }
  }

  Future<void> _completeEmergency(String emergencyId) async {
    try {
      await ApiService().completeEmergency(emergencyId);
      if (mounted) {
        setState(() {
          _alerts.removeWhere((a) => a['emergency_id'] == emergencyId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Mission Completed! Patient safely delivered.'),
            backgroundColor: AppTheme.primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete rescue mission')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.directions_run, color: AppTheme.primaryRed, size: 24),
            SizedBox(width: 10),
            Text(
              'Volunteer Console',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
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
      body: Column(
        children: [
          // ── Duty Status Banner Header ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDutyActive ? AppTheme.primaryRed : Colors.grey,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isDutyActive ? AppTheme.primaryRed : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_isDutyActive)
                          BoxShadow(
                            color: AppTheme.primaryRed.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isDutyActive ? 'ON DUTY — LIVE DISPATCH ACTIVE' : 'OFF DUTY — STANDBY',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _isDutyActive ? AppTheme.primaryRed : Colors.grey.shade400,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isDutyActive,
                    activeThumbColor: AppTheme.primaryRed,
                    onChanged: (val) => setState(() => _isDutyActive = val),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
                : _alerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No emergency dispatch calls',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Monitoring for incoming emergency calls...',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAlerts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _alerts.length,
                          itemBuilder: (_, i) => _AlertCard(
                            alert: _alerts[i],
                            onAccept: () =>
                                _respond(_alerts[i]['emergency_id'], 'accept'),
                            onReject: () =>
                                _respond(_alerts[i]['emergency_id'], 'reject'),
                            onComplete: () =>
                                _completeEmergency(_alerts[i]['emergency_id']),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;

  const _AlertCard({
    required this.alert,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
  });

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = alert['user_info'] as Map<String, dynamic>? ?? {};
    final typeStr = (alert['type'] ?? 'emergency').toString().toUpperCase();
    final isFire = typeStr == 'FIRE';
    final isMedical = typeStr == 'MEDICAL';
    final phone = userInfo['phone_number'] ?? '';
    final isAccepted = alert['status'] == 'accepted';

    final cardColor = isFire
        ? const Color(0xFFEA580C)
        : (isMedical ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    final iconData = isFire
        ? Icons.local_fire_department
        : (isMedical ? Icons.local_hospital : Icons.shield);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAccepted ? AppTheme.primaryRed : cardColor.withValues(alpha: 0.3),
          width: isAccepted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAccepted ? AppTheme.primaryRed : cardColor).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: (isAccepted ? AppTheme.primaryRed : cardColor).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAccepted ? AppTheme.primaryRed : cardColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAccepted ? Icons.airport_shuttle : iconData,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '🚨 $typeStr CALL',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isAccepted ? AppTheme.primaryRed : cardColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isAccepted ? AppTheme.primaryRed : Colors.orange)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isAccepted ? 'ACTIVE RESCUE' : 'PENDING DISPATCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isAccepted ? AppTheme.primaryRed : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Victim Information (Name & Phone ONLY for Fire/Crime, Blood/Medical ONLY for Medical)
                _infoRow(Icons.person, 'Victim Name', userInfo['full_name'] ?? 'Unknown Victim'),
                _infoRow(Icons.phone, 'Phone Contact', phone.isNotEmpty ? phone : 'Not Provided'),

                // Medical details shown strictly ONLY for MEDICAL emergency calls
                if (isMedical) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(
                        Icons.bloodtype,
                        'Blood: ${userInfo['blood_type'] ?? 'Unknown'}',
                        Colors.red.shade700,
                        Colors.red.shade50,
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        Icons.medical_information,
                        'Condition: ${userInfo['medical_conditions'] ?? 'None'}',
                        Colors.blue.shade700,
                        Colors.blue.shade50,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call, size: 18, color: AppTheme.primaryRed),
                          label: const Text('CALL'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryRed,
                            side: const BorderSide(color: AppTheme.primaryRed),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onPressed: () => _makeCall(phone),
                        ),
                      ),
                    if (isAccepted)
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 20),
                            label: const Text(
                              'PATIENT SENT / MISSION COMPLETE',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: onComplete,
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 20),
                            label: const Text(
                              'ACCEPT & DISPATCH',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: onAccept,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: onReject,
                          child: const Text('REJECT'),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.subtleGrey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.subtleGrey),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }
}
