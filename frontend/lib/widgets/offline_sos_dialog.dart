import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sms_dispatch_service.dart';
import '../services/offline_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final orgs = await OfflineService().getCachedOrganizations();
    if (mounted) {
      setState(() {
        _cachedOrgs = orgs;
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
          content: Text('SOS saved to offline queue. It will auto-transmit when online.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final typeUpper = widget.emergencyType.toUpperCase();

    String primaryHotline = SMSDispatchService.hotlineAmbulance;
    String hotlineLabel = isMm ? '၁၉၁ ဆေးရုံ/လူနာတင်ယာဉ်' : '191 Ambulance';
    if (widget.emergencyType == 'fire') {
      primaryHotline = SMSDispatchService.hotlineFire;
      hotlineLabel = isMm ? '၁၉၂ မီးသတ်တပ်ဖွဲ့' : '192 Fire Department';
    } else if (widget.emergencyType == 'crime') {
      primaryHotline = SMSDispatchService.hotlinePolice;
      hotlineLabel = isMm ? '၁၉၉ ရဲတပ်ဖွဲ့' : '199 Police Emergency';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppTheme.primaryRed, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMm ? 'အော့ဖ်လိုင်း အရေးပေါ် SOS' : 'Offline Emergency SOS',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  isMm ? '$typeUpper အရေးပေါ်အကူအညီ' : '$typeUpper Emergency',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMm
                          ? 'အင်တာနက်လိုင်း မရှိပါ။ အောက်ပါ နည်းလမ်းများဖြင့် တိုက်ရိုက် အကူအညီ ရယူပါ:'
                          : 'No internet connection. Please use direct emergency channels below:',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Option 1: Direct Hotline Call ──────────────────────────
            Text(
              isMm ? '၁။ အရေးပေါ် ဖုန်းခေါ်ဆိုရန်' : '1. Direct Emergency Call',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                label: Text(hotlineLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => SMSDispatchService.makePhoneCall(primaryHotline),
              ),
            ),
            const SizedBox(height: 14),

            // ── Option 2: Geocoded SMS Dispatch ────────────────────────
            Text(
              isMm ? '၂။ တည်နေရာပါသော အရေးပေါ် SMS ပို့ရန်' : '2. Send Geocoded Emergency SMS',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.sms_failed_rounded, color: Colors.blue),
                label: Text(
                  isMm ? 'တည်နေရာပါဝင်သော SMS ပို့မည်' : 'Send SMS with GPS Location',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  SMSDispatchService.dispatchBroadcastSMS(
                    emergencyType: widget.emergencyType,
                    lat: widget.lat,
                    lng: widget.lng,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── Option 3: Local Queue for Auto-Sync ──────────────────────
            Text(
              isMm ? '၃။ လိုင်းပြန်ရချိန်တွင် အလိုအလျောက် ပို့ရန်' : '3. Queue for Cloud Auto-Sync',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton.icon(
                icon: Icon(
                  _isQueued ? Icons.check_circle : Icons.cloud_upload_outlined,
                  color: _isQueued ? Colors.green : Colors.grey.shade800,
                  size: 18,
                ),
                label: Text(
                  _isQueued
                      ? (isMm ? 'အော့ဖ်လိုင်း သိမ်းဆည်းပြီးပါပြီ' : 'Saved to Offline Queue')
                      : (isMm ? 'အော့ဖ်လိုင်း တန်းစီဇယားတွင် သိမ်းမည်' : 'Save to Offline Queue'),
                  style: TextStyle(
                    color: _isQueued ? Colors.green : Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isQueued ? null : _enqueueSOS,
              ),
            ),

            // ── Cached Rescue Teams (if available) ──────────────────────
            if (_cachedOrgs.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              Text(
                isMm ? 'အနီးဆုံး ကယ်ဆယ်ရေးအဖွဲ့များ (သိမ်းဆည်းထားသည်)' : 'Cached Rescue Organizations',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ..._cachedOrgs.take(3).map((org) {
                final phone = org['phone_number'] ?? org['phone'] ?? '';
                final name = org['org_name'] ?? 'Rescue Org';
                if (phone.toString().isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green, size: 18),
                        onPressed: () => SMSDispatchService.makePhoneCall(phone.toString()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isMm ? 'ပိတ်မည်' : 'Close'),
        ),
      ],
    );
  }
}
