import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/settings_provider.dart';

class SupportUsScreen extends ConsumerStatefulWidget {
  const SupportUsScreen({super.key});

  @override
  ConsumerState<SupportUsScreen> createState() => _SupportUsScreenState();
}

class _SupportUsScreenState extends ConsumerState<SupportUsScreen> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSupportInfo();
  }

  Future<void> _fetchSupportInfo() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getSupportInfo();
      if (mounted) {
        setState(() {
          _info = res.data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyToClipboard(String text, String label, bool isMm) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isMm ? '$label နံပါတ်ကို ကူးယူပြီးပါပြီ ($text)' : 'Copied $label ($text)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.secondaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    final kbzName = _info?['kbz_pay_name'] ?? 'Khu Nyi Kal Sal Relief Fund';
    final kbzPhone = _info?['kbz_pay_phone'] ?? '09789123456';
    final waveName = _info?['wave_pay_name'] ?? 'Khu Nyi Kal Sal Relief Fund';
    final wavePhone = _info?['wave_pay_phone'] ?? '09789123456';
    final bankName = _info?['bank_name'] ?? 'KBZ Bank';
    final bankAccNum = _info?['bank_account_number'] ?? '123-456-789012345';
    final bankAccName = _info?['bank_account_name'] ?? 'Khu Nyi Kal Sal Emergency Response';
    final noteMessage = _info?['note_message'] ?? 'All donations directly support emergency rescue operations, first aid kits, and blood drives.';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'လှူဒါန်းထောက်ပံ့ရန်' : 'Support Our Mission',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSupportInfo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Banner ─────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB71C1C), AppTheme.primaryRed],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryRed.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
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
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isMm ? 'အသက်ကယ်ဆယ်ရေး ရန်ပုံငွေ' : 'Emergency Life Relief Fund',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isMm
                              ? 'မိမိတို့၏ စေတနာသဒ္ဓါတရားဖြင့် လှူဒါန်းငွေများကို အရေးပေါ်လူနာတင်ယာဉ် ဆီဖိုး၊ ရှေးဦးပြုစုရေးပစ္စည်းများနှင့် သဘာဝဘေးအန္တရာယ် ကယ်ဆယ်ရေးလုပ်ငန်းများတွင် ၁၀၀% အပြည့်အဝ အသုံးပြုပါသည်။'
                              : 'Your generous contribution directly funds ambulance fuel, medical first-aid kits, and rapid response operations for vulnerable citizens in crisis.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    isMm ? 'တရားဝင် လှူဒါန်းနိုင်သော လမ်းကြောင်းများ' : 'Official Donation Channels',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  // ── KBZPay Card ──────────────────────────────────────
                  _paymentCard(
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF003399),
                    title: 'KBZPay',
                    accountNumber: kbzPhone,
                    accountName: kbzName,
                    badgeText: 'INSTANT TRANSFER',
                    onCopy: () => _copyToClipboard(kbzPhone, 'KBZPay', isMm),
                  ),

                  const SizedBox(height: 14),

                  // ── WavePay Card ─────────────────────────────────────
                  _paymentCard(
                    icon: Icons.phone_android_rounded,
                    color: const Color(0xFFFFCC00),
                    iconColor: Colors.black87,
                    title: 'WavePay',
                    accountNumber: wavePhone,
                    accountName: waveName,
                    badgeText: 'INSTANT TRANSFER',
                    onCopy: () => _copyToClipboard(wavePhone, 'WavePay', isMm),
                  ),

                  const SizedBox(height: 14),

                  // ── Bank Transfer Card ───────────────────────────────
                  _paymentCard(
                    icon: Icons.account_balance_rounded,
                    color: Colors.teal.shade800,
                    title: bankName,
                    accountNumber: bankAccNum,
                    accountName: bankAccName,
                    badgeText: 'BANK TRANSFER',
                    onCopy: () => _copyToClipboard(bankAccNum, bankName, isMm),
                  ),

                  const SizedBox(height: 14),

                  // ── MMQR National Standard Card ──────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.purple, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MMQR National Standard',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    isMm ? 'မည်သည့် ဘဏ် / Pay App မဆို Scan ဖတ်၍ လှူဒါန်းနိုင်ပါသည်' : 'Scan & Pay via any Myanmar banking app',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.purple.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isMm
                                      ? 'KBZ, Wave, AYA, CB, UAB, MAB စသည့် App များဖြင့် တိုက်ရိုက် လွှဲပြောင်းနိုင်ပါသည်'
                                      : 'Supported by KBZPay, Wave, AYA Pay, CB Pay, UABpay and all major banks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Admin Note Footer ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            noteMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _paymentCard({
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    required String title,
    required String accountNumber,
    required String accountName,
    required String badgeText,
    required VoidCallback onCopy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      accountName,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    accountNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('COPY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onCopy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
