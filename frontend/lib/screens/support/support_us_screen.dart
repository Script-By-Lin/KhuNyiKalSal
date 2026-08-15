import 'dart:convert';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final innerBoxBg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;
    final innerBoxBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    final kbzName = _info?['kbz_pay_name'] ?? 'Khu Nyi Kal Sal Relief Fund';
    final kbzPhone = _info?['kbz_pay_phone'] ?? '09789123456';
    final waveName = _info?['wave_pay_name'] ?? 'Khu Nyi Kal Sal Relief Fund';
    final wavePhone = _info?['wave_pay_phone'] ?? '09789123456';
    final bankName = _info?['bank_name'] ?? 'KBZ Bank';
    final bankAccNum = _info?['bank_account_number'] ?? '123-456-789012345';
    final bankAccName = _info?['bank_account_name'] ?? 'Khu Nyi Kal Sal Emergency Response';
    final mmqrPayload = _info?['mmqr_payload'] as String?;
    final mmqrImageUrl = _info?['mmqr_image_url'] as String?;
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
                    isMm ? 'လှူဒါန်းနိုင်သော လမ်းကြောင်းများ' : 'Official Donation Channels',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 1. KBZPay ──────────────────────────────────────
                  _paymentCard(
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF0056B3),
                    title: 'KBZPay',
                    accountNumber: kbzPhone,
                    accountName: kbzName,
                    badgeText: 'KPay Instant Transfer',
                    onCopy: () => _copyToClipboard(kbzPhone, 'KBZPay', isMm),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    innerBoxBg: innerBoxBg,
                    innerBoxBorder: innerBoxBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                  const SizedBox(height: 16),

                  // ── 2. WavePay ─────────────────────────────────────
                  _paymentCard(
                    icon: Icons.phone_android_rounded,
                    color: const Color(0xFFFBBF24),
                    iconColor: Colors.black87,
                    title: 'WavePay',
                    accountNumber: wavePhone,
                    accountName: waveName,
                    badgeText: 'Wave Money Transfer',
                    onCopy: () => _copyToClipboard(wavePhone, 'WavePay', isMm),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    innerBoxBg: innerBoxBg,
                    innerBoxBorder: innerBoxBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                  const SizedBox(height: 16),

                  // ── 3. Bank Account ────────────────────────────────
                  _paymentCard(
                    icon: Icons.account_balance_rounded,
                    color: const Color(0xFF0D9488),
                    title: bankName,
                    accountNumber: bankAccNum,
                    accountName: bankAccName,
                    badgeText: 'Direct Bank Transfer',
                    onCopy: () => _copyToClipboard(bankAccNum, '$bankName Account', isMm),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    innerBoxBg: innerBoxBg,
                    innerBoxBorder: innerBoxBorder,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                  const SizedBox(height: 16),

                  // ── 4. MMQR National Standard ──────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
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
                                color: Colors.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.purpleAccent, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MMQR National Standard',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                                  ),
                                  Text(
                                    isMm ? 'မည်သည့် ဘဏ် / Pay App မဆို Scan ဖတ်၍ လှူဒါန်းနိုင်ပါသည်' : 'Scan & Pay via any Myanmar banking app',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Center MMQR Image
                        Center(
                          child: Column(
                            children: [
                              _buildMmqrImageWidget(mmqrImageUrl, isDark, isMm),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                        // Copy Payload / Instructions Row
                        if (mmqrPayload != null && mmqrPayload.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.purpleAccent),
                                label: Text(
                                  isMm ? 'MMQR Payload စာသား ကူးယူမည်' : 'Copy MMQR Payload Data',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.purpleAccent),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: isDark ? Colors.purple.shade400 : Colors.purple.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _copyToClipboard(mmqrPayload, 'MMQR Payload', isMm),
                              ),
                            ),
                          ),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E1065) : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF581C87) : Colors.purple.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isMm
                                      ? r'KBZPay, Wave, AYA Pay, CB Pay, UABpay, OK$ စသည့် App များဖြင့် Scan ဖတ် လှူဒါန်းနိုင်ပါသည်'
                                      : 'Supported by KBZPay, Wave, AYA Pay, CB Pay, UABpay and all major banks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.purple.shade100 : Colors.purple.shade900,
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
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
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
                              color: textSecondary,
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
    required Color cardBg,
    required Color cardBorder,
    required Color innerBoxBg,
    required Color innerBoxBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                    ),
                    Text(
                      accountName,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: innerBoxBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: innerBoxBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: innerBoxBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    accountNumber,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: textPrimary,
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

  Widget _buildMmqrImageWidget(String? src, bool isDark, bool isMm) {
    if (src == null || src.trim().isEmpty) {
      return Container(
        height: 180,
        width: 180,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 64, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700),
            const SizedBox(height: 8),
            Text(
              isMm ? 'MMQR National Code' : 'MMQR Standard',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    Widget img;
    final trimmed = src.trim();
    if (trimmed.startsWith('data:image') || (!trimmed.startsWith('http://') && !trimmed.startsWith('https://') && trimmed.length > 100)) {
      try {
        final cleanBase64 = trimmed.contains(',') ? trimmed.split(',').last : trimmed;
        final bytes = base64Decode(cleanBase64.trim());
        img = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        img = const Center(child: Text('Invalid QR Image', style: TextStyle(color: Colors.red, fontSize: 11)));
      }
    } else {
      img = Image.network(
        trimmed,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Unable to load QR image', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 11)),
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple));
        },
      );
    }

    return GestureDetector(
      onTap: () => _openFullscreenQrDialog(trimmed, isMm),
      child: Container(
        height: 200,
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade400, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(child: img),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.black.withValues(alpha: 0.6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      isMm ? 'ချဲ့ကြည့်ရန် နှိပ်ပါ' : 'Tap to Enlarge',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreenQrDialog(String src, bool isMm) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, color: Colors.purple.shade700, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            isMm ? 'MMQR ကုဒ်' : 'Official MMQR',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Container(
                    height: 280,
                    width: 280,
                    padding: const EdgeInsets.all(8),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: src.startsWith('data:image') || (!src.startsWith('http://') && !src.startsWith('https://') && src.length > 100)
                          ? Image.memory(
                              base64Decode(src.contains(',') ? src.split(',').last : src),
                              fit: BoxFit.contain,
                            )
                          : Image.network(src, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isMm
                        ? 'မည်သည့် မိုဘိုင်းဘဏ် App ဖြင့်မဆို Scan ဖတ်၍ တိုက်ရိုက် လှူဒါန်းနိုင်ပါသည်'
                        : 'Pinch to zoom or scan directly with any mobile banking app',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(isMm ? 'ပိတ်မည်' : 'DONE', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
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
}
