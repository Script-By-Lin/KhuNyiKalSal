import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/settings_provider.dart';

class RulesLawsScreen extends ConsumerWidget {
  const RulesLawsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'စည်းမျဉ်းဥပဒေများနှင့် သဘောတူညီချက်' : 'Rules, Laws & Terms of Service',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner ─────────────────────────────────────────
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
                        child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isMm ? 'တရားဝင် စည်းမျဉ်းနှင့် ဥပဒေရေးရာ မူဘောင်' : 'Official Legal & Regulatory Framework',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isMm
                        ? 'ဤအက်ပလီကေးရှင်းကို အသုံးပြုခြင်းဖြင့် အောက်ဖော်ပြပါ စည်းကမ်းချက်များ၊ သဘာဝဘေးအန္တရာယ် ကာကွယ်ရေးဥပဒေများနှင့် ကိုယ်ရေးအချက်အလက် လုံခြုံရေးမူဝါဒများကို သဘောတူညီပြီး ဖြစ်ပါသည်။'
                        : 'By accessing or using Khu Nyi Kal Sal, all users, rescue organizations, and volunteers agree to be bound by these Terms of Service, disaster management laws, and privacy standards.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 1: False SOS & Penalties ────────────────────
            _legalCard(
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.orange,
              title: isMm ? '၁။ မမှန်ကန်သော အရေးပေါ် SOS အချက်ပြမှုများနှင့် ပြစ်ဒဏ်များ' : '1. False SOS Alerts & Legal Penalties',
              body: isMm
                  ? 'အရေးပေါ် မဟုတ်ဘဲ အပျော်သဘော (သို့မဟုတ်) အလွဲသုံးစား SOS ခလုတ်နှိပ်ခြင်းသည် ဥပဒေအရ ကြီးလေးသော ပြစ်မှုဖြစ်ပါသည်။\n\n'
                      '• စနစ်မှ ၂၄ နာရီအတွင်း SOS အကြိမ်ရေကို အလိုအလျောက် စောင့်ကြည့်နေပြီး အလွဲသုံးစားပြုလုပ်ပါက အကောင့်ကို ချက်ချင်း ရာသက်ပန် ပိတ်သိမ်း (Ban) မည် ဖြစ်ပါသည်။\n'
                      '• အမှန်တကယ် အသက်ဘေးကြုံတွေ့နေရသူများ၏ အခွင့်အရေးကို ထိခိုက်စေသဖြင့် တည်ဆဲ ဆက်သွယ်ရေးနှင့် အများပြည်သူ အနှောင့်အယှက်ဖြစ်စေမှု ဥပဒေများဖြင့် တရားစွဲဆို အရေးယူခြင်း ခံရမည်။'
                  : 'Triggering false or abusive SOS alerts is strictly prohibited and constitutes a punishable legal offense.\n\n'
                      '• The automated abuse detection engine monitors 24h frequency. High-frequency abuse will result in immediate permanent account banning and session termination.\n'
                      '• False triggers divert critical ambulances away from genuine life-and-death situations and will be prosecuted under national public nuisance and communications laws.',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // ── Section 2: Data Privacy & Cryptography ──────────────
            _legalCard(
              icon: Icons.security_rounded,
              iconColor: AppTheme.secondaryGreen,
              title: isMm ? '၂။ ကိုယ်ရေးအချက်အလက် လုံခြုံရေးနှင့် လျှို့ဝှက်ကုဒ်စနစ်' : '2. Cryptographic Privacy & Zero-Trace GPS',
              body: isMm
                  ? '• သင်၏ ဖုန်းနံပါတ်၊ သွေးအမျိုးအစားနှင့် ကျန်းမာရေးရောဂါအခံ အချက်အလက်များကို စစ်ဘက်အဆင့် Salted Fernet AES-256 ဖြင့် လျှို့ဝှက်ကုဒ်ပြောင်းကာ သိမ်းဆည်းထားပါသည်။\n'
                      '• တိုက်ရိုက် GPS တည်နေရာကို ကယ်ဆယ်ရေးလုပ်ငန်း ဆောင်ရွက်နေစဉ်အတွင်း၌သာ ယာယီ RAM Cache တွင် ထိန်းသိမ်းထားပြီး ကယ်ဆယ်ရေးပြီးဆုံးသည်နှင့် စနစ်မှ ချက်ချင်း ခြေရာဖျက် (Zero-Trace Purge) ပေးပါသည်။\n'
                      '• မည်သည့် ပြင်ပစီးပွားရေး ကြော်ငြာကုမ္ပဏီကိုမျှ အချက်အလက် လွှဲပြောင်းပေးအပ်ခြင်း မရှိပါ။'
                  : '• All sensitive Personally Identifiable Information (phone numbers, medical conditions, blood group) is encrypted at rest using salted Fernet AES-256.\n'
                      '• High-precision GPS tracking is held strictly in ephemeral RAM cache during active rescue operations and is immediately wiped (Zero-Trace Purge) upon mission completion.\n'
                      '• Your data is never sold or shared with commercial third parties.',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // ── Section 3: Good Samaritan Protection ────────────────
            _legalCard(
              icon: Icons.favorite_rounded,
              iconColor: Colors.redAccent,
              title: isMm ? '၃။ အသက်ကယ်ဆယ်ရေး စေတနာရှင် ကာကွယ်မှုဥပဒေ' : '3. Good Samaritan & First Responder Immunity',
              body: isMm
                  ? 'အရေးပေါ် အသက်ကယ်ဆယ်ရေး လုပ်ငန်းများတွင် စေတနာအပြည့်ဖြင့် ကူညီဆောင်ရွက်သော စေတနာ့ဝန်ထမ်းများနှင့် ကယ်ဆယ်ရေးအဖွဲ့ဝင်များသည် မတော်တဆ ထိခိုက်မှုများအတွက် ဥပဒေအရ အကာအကွယ် (Good Samaritan Protection) ရရှိပါသည်။\n\n'
                      '• အဖွဲ့ဝင်များသည် ကျင့်ဝတ်စည်းကမ်းနှင့်အညီ အစွမ်းကုန် ကြိုးပမ်းကယ်ဆယ်ရပါမည်။'
                  : 'Responders and volunteers acting in good faith to preserve human life are protected under Good Samaritan principles.\n\n'
                      '• Responders are expected to act promptly, ethically, and in accordance with recognized first-aid and rescue protocols.',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // ── Section 4: Blood Donation Ethics ────────────────────
            _legalCard(
              icon: Icons.water_drop_rounded,
              iconColor: Colors.deepPurple,
              title: isMm ? '၄။ သွေးလှူဒါန်းခြင်းဆိုင်ရာ စည်းမျဉ်းကျင့်ဝတ်များ' : '4. Blood Donation & Patient Request Ethics',
              body: isMm
                  ? '• သွေးလှူဒါန်းမှုနှင့် သွေးတောင်းခံမှုများသည် ပရဟိတ သန့်သန့် ဖြစ်ပြီး စီးပွားဖြစ် ရောင်းဝယ်ဖောက်ကားခြင်း လုံးဝ မပြုလုပ်ရပါ။\n'
                      '• သွေးလှူဒါန်းသူများသည် ကျန်းမာရေး သတ်မှတ်ချက်များနှင့် ကိုက်ညီရမည်ဖြစ်ပြီး သွေးတောင်းခံသူများသည် ဆေးရုံနှင့် လူနာအချက်အလက်ကို မှန်ကန်စွာ ဖြည့်သွင်းရပါမည်။'
                  : '• Blood donation and exchange through this platform are strictly non-commercial and humanitarian in nature. Buying or selling blood is strictly forbidden.\n'
                      '• Donors must meet basic health eligibility criteria, and emergency blood requesters must provide verifiable hospital details.',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // ── Section 5: Disclaimer & Liability ───────────────────
            _legalCard(
              icon: Icons.shield_outlined,
              iconColor: Colors.blueGrey,
              title: isMm ? '၅။ တာဝန်ယူမှု ကန့်သတ်ချက်များ' : '5. Emergency Disclaimer & Network Availability',
              body: isMm
                  ? 'ဤအက်ပလီကေးရှင်းသည် အရေးပေါ်ကယ်ဆယ်ရေးအဖွဲ့များနှင့် ဆက်သွယ်ပေးသော နည်းပညာကြားခံစနစ် ဖြစ်ပါသည်။ အင်တာနက်လိုင်းပြတ်တောက်မှု (သို့မဟုတ်) သဘာဝဘေးအခြေအနေကြောင့် ဆက်သွယ်ရေးအခက်အခဲ ဖြစ်ပေါ်ပါက Offline SMS စနစ်ကို အသုံးပြု၍ တိုက်ရိုက် အကူအညီတောင်းခံနိုင်ပါသည်။'
                  : 'This application is a digital coordination bridge connecting citizens with local rescue organizations. While we provide offline SMS fallbacks, network reliability depends on local cellular conditions.',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legalCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
