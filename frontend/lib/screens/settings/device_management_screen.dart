import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';
import '../../providers/settings_provider.dart';
import '../../config/theme.dart';
import '../../utils/date_formatter.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
    try {
      final res = await _api.getSessions();
      final data = List<Map<String, dynamic>>.from(res.data);
      if (mounted) {
        setState(() {
          _sessions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _extractError(e, isMm);
          _isLoading = false;
        });
      }
    }
  }

  String _extractError(dynamic e, bool isMm) {
    try {
      final dioErr = e as dynamic;
      final status = dioErr.response?.statusCode;
      if (status == 404) {
        return isMm
            ? 'စက်ပစ္စည်းစီမံခန့်ခွဲမှု စနစ်ကို ဆာဗာတွင် အဆင့်မြှင့်တင်နေဆဲ ဖြစ်ပါသည်။ ကျေးဇူးပြု၍ Backend အသစ်ကို Deploy ပြုလုပ်ပေးပါ။'
            : 'Connected devices feature is not yet active on the cloud server. Please deploy the latest backend to Railway.';
      } else if (status == 401) {
        return isMm
            ? 'အကောင့်သက်တမ်းကုန်ဆုံးသွားပါပြီ။ ကျေးဇူးပြု၍ ပြန်လည်ဝင်ရောက်ပါ။'
            : 'Session expired or invalidated. Please sign in again.';
      } else if (dioErr.response?.data is Map && dioErr.response.data.containsKey('detail')) {
        return dioErr.response.data['detail'].toString();
      }
      return isMm
          ? 'ဆာဗာနှင့် ချိတ်ဆက်၍ မရနိုင်ပါ။ အင်တာနက်လိုင်းကို စစ်ဆေးပါ။'
          : 'Unable to load devices. Please check your internet connection and try again.';
    } catch (_) {
      return isMm ? 'အမှားတစ်ခု ဖြစ်ပေါ်ခဲ့ပါသည်။' : 'An error occurred while loading devices.';
    }
  }

  Future<void> _revokeSession(String sessionId, String deviceName) async {
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMm ? 'စက်ပစ္စည်း ဖြုတ်မည်' : 'Revoke Device'),
        content: Text(
          isMm
              ? '$deviceName ကို အကောင့်မှ ဖြုတ်ရန် သေချာပါသလား။'
              : 'Are you sure you want to disconnect $deviceName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isMm ? 'ဖြုတ်မည်' : 'Disconnect',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.revokeSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'စက်ပစ္စည်းကို အောင်မြင်စွာ ဖြုတ်လိုက်ပါပြီ'
                  : 'Device disconnected successfully',
            ),
          ),
        );
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _logoutOtherDevices() async {
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMm ? 'အခြားစက်များမှ ထွက်မည်' : 'Log Out Other Devices'),
        content: Text(
          isMm
              ? 'ဤဖုန်းမှလွဲ၍ ကျန်ရှိသော စက်ပစ္စည်းအားလုံးမှ အကောင့်ထွက်ရန် သေချာပါသလား။'
              : 'Are you sure you want to log out of all other active sessions?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isMm ? 'မလုပ်တော့ပါ' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isMm ? 'အားလုံးထွက်မည်' : 'Log Out All',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Revoke all other sessions
      for (final s in _sessions) {
        if (s['is_current'] != true && s['is_active'] == true) {
          await _api.revokeSession(s['session_id']);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'အခြားစက်များမှ အောင်မြင်စွာ ထွက်လိုက်ပါပြီ'
                  : 'Logged out of all other devices',
            ),
          ),
        );
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    final title = isMm ? 'အသုံးပြုနေသော စက်များ' : 'Connected Devices';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: isMm ? 'ပြန်လည်ရယူရန်' : 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSessions,
                          child: Text(isMm ? 'ထပ်မံကြိုးစားမည်' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Header info banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.security, color: Colors.blue.shade700, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isMm
                                    ? 'သင့်အကောင့်လုံခြုံရေးအတွက် လက်ရှိချိတ်ဆက်ထားသော စက်ပစ္စည်းများကို စီမံခန့်ခွဲနိုင်ပါသည်။'
                                    : 'Manage your active devices to protect your account and real-time emergency safety.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        isMm ? 'ချိတ်ဆက်ထားသော စက်များ' : 'Active Sessions',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_sessions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              isMm
                                  ? 'မည်သည့် စက်ပစ္စည်းမျှ မရှိပါ'
                                  : 'No active sessions found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._sessions.map((s) => _buildDeviceCard(s, isMm)),

                      const SizedBox(height: 24),

                      // Logout other devices button
                      if (_sessions.where((s) => s['is_current'] != true && s['is_active'] == true).isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phonelink_erase, color: AppTheme.primaryRed),
                            label: Text(
                              isMm
                                  ? 'အခြားစက်အားလုံးမှ ထွက်မည်'
                                  : 'Log Out of All Other Devices',
                              style: const TextStyle(
                                color: AppTheme.primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primaryRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _logoutOtherDevices,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> session, bool isMm) {
    final isCurrent = session['is_current'] == true;
    final isActive = session['is_active'] == true;
    final deviceName = session['device_name'] ?? 'Unknown Device';
    final ip = session['ip_address'] ?? 'Unknown IP';
    final formattedDate = session['last_used_at'] != null
        ? AppDateFormatter.formatDateTime(session['last_used_at'], isMm: isMm)
        : '-';

    IconData deviceIcon = Icons.smartphone;
    final dLower = deviceName.toString().toLowerCase();
    if (dLower.contains('windows') || dLower.contains('mac') || dLower.contains('pc') || dLower.contains('linux')) {
      deviceIcon = Icons.computer;
    } else if (dLower.contains('browser') || dLower.contains('web')) {
      deviceIcon = Icons.language;
    } else if (dLower.contains('tablet') || dLower.contains('ipad')) {
      deviceIcon = Icons.tablet;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent ? Colors.green.shade400 : Colors.grey.shade300,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                deviceIcon,
                color: isCurrent ? Colors.green.shade700 : Colors.grey.shade700,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isMm ? 'ဤစက်ပစ္စည်း' : 'This Device',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        )
                      else if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isMm ? 'ပိတ်ထားသည်' : 'Revoked',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'IP: $ip',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isMm ? 'နောက်ဆုံးသုံးခဲ့ချိန်' : 'Last active'}: $formattedDate',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (!isCurrent && isActive)
              IconButton(
                icon: const Icon(Icons.logout, color: Color(0xFFD32F2F), size: 20),
                tooltip: isMm ? 'အကောင့်ထွက်မည်' : 'Revoke',
                onPressed: () => _revokeSession(session['session_id'], deviceName),
              ),
          ],
        ),
      ),
    );
  }
}
