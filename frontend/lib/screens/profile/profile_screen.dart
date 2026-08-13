import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
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

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await ApiService().getProfile();
      final histRes = await ApiService().getEmergencyHistory();
      if (mounted) {
        setState(() {
          _profile = res.data;
          _history = histRes.data as List;
          _nameCtrl.text = _profile?['full_name'] ?? '';
          _phoneCtrl.text = _profile?['phone_number'] ?? '';
          _bloodCtrl.text = _profile?['blood_type'] ?? '';
          _medicalCtrl.text = _profile?['medical_conditions'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validatePhone(String value) {
    final clean = value.trim().replaceAll(' ', '').replaceAll('-', '');
    final regExp = RegExp(r'^(?:\+959|09)\d{9,10}$');
    if (!regExp.hasMatch(clean)) {
      return 'Phone must start with +959 or 09 followed by 9 or 10 digits\n(e.g., 09123456789 or +959123456789)';
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
        ),
      );
      return;
    }

    try {
      final cleanPhone = _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_number': cleanPhone,
        'blood_type': _bloodCtrl.text.trim(),
        'medical_conditions': _medicalCtrl.text.trim(),
      });
      setState(() => _editing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    }
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '📜 SOS Emergency History Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _history.isEmpty
                    ? const Center(
                        child: Text(
                          'No past emergency records found.',
                          style: TextStyle(color: AppTheme.subtleGrey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _history.length,
                        itemBuilder: (_, i) {
                          final h = _history[i];
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
                              color: AppTheme.surfaceGrey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  type.contains('FIRE')
                                      ? Icons.local_fire_department
                                      : (type.contains('CRIME')
                                          ? Icons.shield
                                          : Icons.medical_services),
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        'Date: $date',
                                        style: const TextStyle(
                                            fontSize: 12, color: AppTheme.subtleGrey),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bloodCtrl.dispose();
    _medicalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'ပရိုဖိုင်' : 'My Profile'),
        actions: [
          if (!_editing && !_loading)
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
                  // ── Avatar ────────────────────────────────────────────
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryRed.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (_nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text[0]
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User Profile',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.email ?? '',
                    style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // ── Fields ────────────────────────────────────────────
                  _field(isMm ? 'နာမည်အပြည့်အစုံ' : 'Full Name', _nameCtrl, Icons.person_outline),
                  _field(isMm ? 'ဖုန်းနံပါတ်' : 'Phone Number', _phoneCtrl, Icons.phone_outlined,
                      helperText: 'Must start with +959 or 09 (9 or 10 digits total)'),
                  _field(isMm ? 'သွေးအမျိုးအစား' : 'Blood Type', _bloodCtrl, Icons.bloodtype_outlined),
                  _field('Medical Conditions', _medicalCtrl,
                      Icons.medical_information_outlined,
                      maxLines: 3),

                  // ── Emergency Contacts ────────────────────────────────
                  if (_profile?['emergency_contacts'] != null) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Emergency Contacts',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const SizedBox(height: 10),
                    ...(_profile!['emergency_contacts'] as List)
                        .map<Widget>((c) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceGrey,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.contact_phone,
                                      size: 20, color: AppTheme.primaryRed),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(c['phone'] ?? '',
                                          style: const TextStyle(
                                              color: AppTheme.subtleGrey,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                  ],

                  const SizedBox(height: 24),

                  // ── Action Buttons ──────────────────────────────────────
                  if (_editing) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: Text(isMm ? 'သိမ်းဆည်းမည်' : 'Save Changes'),
                        onPressed: _save,
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
                        child: const Text('Cancel'),
                      ),
                    ),
                  ] else ...[
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
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Profile Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textDark,
                          side: const BorderSide(color: Colors.grey, width: 1.5),
                        ),
                        onPressed: () => setState(() => _editing = true),
                      ),
                    ),
                  ],
                  // Extra space at bottom to ensure floating navbar never overlaps
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
