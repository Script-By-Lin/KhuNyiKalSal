import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/sms_dispatch_service.dart';
import '../services/offline_service.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../config/theme.dart';

class OfflineSOSDialog extends ConsumerStatefulWidget {
  final String emergencyType;
  final double lat;
  final double lng;

  const OfflineSOSDialog({
    super.key,
    required this.emergencyType,
    required this.lat,
    required this.lng,
  });

  @override
  ConsumerState<OfflineSOSDialog> createState() => _OfflineSOSDialogState();
}

class _OfflineSOSDialogState extends ConsumerState<OfflineSOSDialog> {
  List<Map<String, dynamic>> _cachedOrgs = [];
  bool _isQueued = false;
  bool _isSyncing = false;
  Map<String, dynamic>? _selectedOrg;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final orgs = await OfflineService().getCachedOrganizations();
    final queue = await OfflineService().getPendingSOSQueue();
    if (mounted) {
      setState(() {
        _cachedOrgs = orgs;
        if (queue.any((item) => item['type'] == widget.emergencyType)) {
          _isQueued = true;
        }
        if (orgs.isNotEmpty) {
          // Select matching org by emergency type if possible
          _selectedOrg = orgs.firstWhere(
            (o) {
              final cat = (o['category'] ?? '').toString().toLowerCase();
              final name = (o['org_name'] ?? '').toString().toLowerCase();
              final etype = widget.emergencyType.toLowerCase().replaceAll(' ', '_');
              if (etype == 'fire') {
                return cat.contains('fire') || name.contains('fire') || name.contains('မီးသတ်');
              }
              if (etype == 'medical' || etype == 'accident') {
                return cat.contains('medical') || name.contains('medical') || name.contains('ဆေး') || name.contains('hospital') || name.contains('ambulance');
              }
              if (etype == 'natural_disaster' || etype == 'disaster') {
                return cat.contains('fire') || cat.contains('voluntary') || cat.contains('volunteer') || name.contains('ကယ်ဆယ်') || name.contains('rescue');
              }
              return true;
            },
            orElse: () => orgs.first,
          );
        }
      });
    }
  }

  Future<void> _enqueueSOS() async {
    await OfflineService().queueOfflineSOS(
      type: widget.emergencyType,
      lat: widget.lat,
      lng: widget.lng,
    );
    if (mounted) {
      setState(() {
        _isQueued = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ SOS saved to offline queue. It will auto-transmit when online.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _syncToCloudNow() async {
    setState(() => _isSyncing = true);
    final isOnline = await OfflineService().checkInternet();
    if (!isOnline) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No internet connection detected. Saved in offline queue.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Transmit SOS directly to cloud and flush queue
    final notifier = ref.read(emergencyProvider.notifier);
    final emergencyId = await notifier.createSOS(widget.emergencyType, widget.lat, widget.lng);
    await OfflineService().syncPendingSOSQueue();

    if (mounted) {
      setState(() => _isSyncing = false);
      if (emergencyId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ SOS successfully transmitted to cloud network!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        context.go('/map');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.lastError ?? 'Could not reach server. Saved in offline queue.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeUpper = widget.emergencyType.toUpperCase();

    final selectedOrgName = _selectedOrg?['org_name'] ?? (isMm ? 'ဒေသတွင်း ကယ်ဆယ်ရေးအဖွဲ့' : 'Local Rescue Org');
    final selectedOrgPhone = (_selectedOrg?['phone_number'] ?? _selectedOrg?['phone'] ?? '').toString();

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMm ? 'အော့ဖ်လိုင်း အရေးပေါ် SOS' : 'Offline Emergency SOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            Text(
              isMm ? '$typeUpper အရေးပေါ်အကူအညီ' : '$typeUpper Emergency Mode',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryRed, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Offline Warning Banner ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF422006) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF78350F) : Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: isDark ? Colors.amber.shade400 : Colors.amber.shade900, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm ? 'အင်တာနက်လိုင်း မရှိသေးပါ' : 'No Internet Connection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMm
                                ? 'ဒေသတွင်း ကယ်ဆယ်ရေးအဖွဲ့များထံ တိုက်ရိုက် ဖုန်းခေါ်ဆိုခြင်း သို့မဟုတ် GPS တည်နေရာပါဝင်သော SMS ပေးပို့၍ ချက်ချင်း အကူအညီ ရယူနိုင်ပါသည်။'
                                : 'You can get immediate help by calling local rescue organizations directly or dispatching a geocoded SMS with your GPS location.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Primary Action 1: Direct Call to Local Org ───────────
              Text(
                isMm ? '၁။ ဒေသတွင်း ကယ်ဆယ်ရေးအဖွဲ့ထံ ဖုန်းခေါ်မည်' : '1. Call Local Rescue Organization',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital, color: AppTheme.primaryRed, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedOrgName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                              ),
                              if (selectedOrgPhone.isNotEmpty)
                                Text(
                                  '📞 $selectedOrgPhone',
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                        label: Text(
                          selectedOrgPhone.isNotEmpty
                              ? (isMm ? 'တိုက်ရိုက် ဖုန်းခေါ်မည် ($selectedOrgPhone)' : 'Call Now ($selectedOrgPhone)')
                              : (isMm ? 'တိုက်ရိုက် ဖုန်းခေါ်မည်' : 'Call Local Org'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: selectedOrgPhone.isNotEmpty
                            ? () => SMSDispatchService.makePhoneCall(selectedOrgPhone)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Primary Action 2: Send Geocoded SMS to Local Org ────
              Text(
                isMm ? '၂။ ဒေသတွင်းအဖွဲ့ထံ တည်နေရာပါသော SMS ပို့မည်' : '2. Send GPS Location SMS to Local Org',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sms_outlined, color: Colors.blue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMm ? 'အရေးပေါ် SMS အချက်အလက်' : 'Emergency SMS Dispatch',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                isMm
                                    ? 'GPS: ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)} (Google Maps လင့်ခ်ပါဝင်)'
                                    : 'GPS: ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)} (With Maps link)',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        label: Text(
                          isMm ? 'ကယ်ဆယ်ရေးအဖွဲ့ထံ SMS ပို့မည်' : 'Send Emergency SMS to Local Org',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await SMSDispatchService.dispatchBroadcastSMS(
                            emergencyType: widget.emergencyType,
                            lat: widget.lat,
                            lng: widget.lng,
                            targetPhoneNumber: selectedOrgPhone.isNotEmpty ? selectedOrgPhone : null,
                          );
                          if (!success && mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isMm
                                    ? 'SMS အက်ပ်ကို ဖွင့်၍မရပါ သို့မဟုတ် ဖုန်းနံပါတ် မရှိပါ'
                                    : 'Could not launch SMS app. Please check phone number.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Primary Action 3: Queue for Auto-Sync / Manual Sync ─
              Text(
                isMm ? '၃။ လိုင်းပြန်ရချိန်တွင် အလိုအလျောက် ပို့ရန်' : '3. Cloud Auto-Sync & Manual Push',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMm
                          ? 'အင်တာနက်လိုင်း ပြန်လည်ရရှိသည်နှင့် တပြိုင်နက် ဆာဗာသို့ အလိုအလျောက် SOS ပေးပို့သွားမည် ဖြစ်ပါသည်။'
                          : 'As soon as internet connection is restored, the app will automatically push this SOS alert to the cloud network.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              _isQueued ? Icons.check_circle : Icons.save_alt_rounded,
                              color: _isQueued ? Colors.green : Colors.grey.shade800,
                              size: 18,
                            ),
                            label: Text(
                              _isQueued
                                  ? (isMm ? 'သိမ်းဆည်းပြီး' : 'Queued')
                                  : (isMm ? 'တန်းစီဇယားသို့' : 'Save Queue'),
                              style: TextStyle(
                                color: _isQueued ? Colors.green : Colors.grey.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _isQueued ? Colors.green : Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isQueued ? null : _enqueueSOS,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                            label: Text(
                              _isSyncing
                                  ? (isMm ? 'ပို့နေသည်...' : 'Syncing...')
                                  : (isMm ? 'လိုင်းသို့ ပို့မည်' : 'Sync to Cloud'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isSyncing ? null : _syncToCloudNow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── All Cached Local Organizations ──────────────────────
              if (_cachedOrgs.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  isMm ? 'ဒေသတွင်း ကယ်ဆယ်ရေးအဖွဲ့များ (သိမ်းဆည်းထားသည်)' : 'All Cached Local Organizations',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._cachedOrgs.map((org) {
                  final phone = (org['phone_number'] ?? org['phone'] ?? '').toString();
                  final name = org['org_name'] ?? 'Local Rescue Organization';
                  if (phone.isEmpty) return const SizedBox.shrink();

                  final isSelected = _selectedOrg == org;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red.shade50.withValues(alpha: 0.5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryRed : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_city, size: 20, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '📞 $phone',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'SMS',
                          icon: const Icon(Icons.sms, color: Colors.blue, size: 22),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await SMSDispatchService.sendEmergencySMS(
                              phoneNumber: phone,
                              emergencyType: widget.emergencyType,
                              lat: widget.lat,
                              lng: widget.lng,
                            );
                            if (!ok && mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(isMm
                                      ? 'SMS အက်ပ်ကို ဖွင့်၍မရပါ'
                                      : 'Could not launch SMS app with this number'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Call',
                          icon: const Icon(Icons.phone, color: AppTheme.secondaryGreen, size: 22),
                          onPressed: () => SMSDispatchService.makePhoneCall(phone),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
              // ── Offline First-Aid Guide shortcut ────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, color: AppTheme.primaryRed, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm ? 'ရှေးဦးသူနာပြုလမ်းညွှန်' : 'Offline First-Aid Guides',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            isMm ? 'CPR၊ သွေးထွက်ခြင်း၊ မီးလောင်ဒဏ်ရာ ပြုစုနည်းများ' : 'CPR, Bleeding, Burn Protocols',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        context.push('/first-aid');
                      },
                      child: Text(isMm ? 'ဖတ်မည်' : 'View'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
