import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

class LegalAgreementScreen extends StatelessWidget {
  const LegalAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Legal Regulations', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ──────────────────────────────────────────
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
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Khu Nyi Kal Sal — Terms of Service',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'အရေးပေါ် ကူညီကယ်ဆယ်ရေး ကွန်ရက် အသုံးပြုခြင်းဆိုင်ရာ တရားဝင် သဘောတူညီချက်များ',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _card(
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.orange,
              title: '၁။ အရေးပေါ် SOS စနစ် အလွဲသုံးစားမှု တားမြစ်ချက်',
              body: '• မမှန်ကန်သော အရေးပေါ် SOS အချက်ပြမှုများ ပြုလုပ်ခြင်းသည် ဥပဒေအရ ပြစ်ဒဏ်ကျခံရနိုင်သော ပြစ်မှုဖြစ်ပါသည်။\n'
                  '• စနစ်မှ အလွဲသုံးစားပြုလုပ်သော အသုံးပြုသူများကို အကောင့်ပိတ်သိမ်း (Ban) မည်ဖြစ်ပြီး တည်ဆဲဥပဒေများဖြင့် အရေးယူမည်။',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            _card(
              icon: Icons.security_rounded,
              iconColor: AppTheme.secondaryGreen,
              title: '၂။ အချက်အလက် လုံခြုံရေးနှင့် ခြေရာမကျန် GPS စနစ်',
              body: '• သင်၏ ကိုယ်ရေးအချက်အလက်များကို Salted Fernet AES-256 ဖြင့် လုံခြုံစွာ သိမ်းဆည်းပါသည်။\n'
                  '• GPS တည်နေရာကို ကယ်ဆယ်ရေးလုပ်ငန်းအတွင်း၌သာ အသုံးပြုပြီး ပြီးဆုံးသည်နှင့် ချက်ချင်း ဖျက်ဆီးပါသည်။',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            _card(
              icon: Icons.favorite_rounded,
              iconColor: Colors.redAccent,
              title: '၃။ စေတနာ့ဝန်ထမ်းနှင့် ကယ်ဆယ်ရေးအဖွဲ့များ အကာအကွယ်ပေးမှု',
              body: '• အရေးပေါ် အသက်ကယ်ဆယ်ရေး လုပ်ငန်းများတွင် စေတနာအပြည့်ဖြင့် ကူညီဆောင်ရွက်သော စေတနာ့ဝန်ထမ်းများသည် ဥပဒေအရ အကာအကွယ် ရရှိပါသည်။',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            _card(
              icon: Icons.water_drop_rounded,
              iconColor: Colors.deepPurple,
              title: '၄။ သွေးလှူဒါန်းခြင်းဆိုင်ရာ စည်းမျဉ်းများ',
              body: '• သွေးလှူဒါန်းမှုနှင့် သွေးတောင်းခံမှုများသည် ပရဟိတ သန့်သန့် ဖြစ်ပြီး စီးပွားဖြစ် ရောင်းဝယ်ဖောက်ကားခြင်း လုံးဝ မပြုလုပ်ရပါ။',
              cardBg: cardBg,
              cardBorder: cardBorder,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('သဘောတူလက်ခံပါသည် (I Agree)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _card({
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
      margin: const EdgeInsets.only(bottom: 14),
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
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(fontSize: 13, height: 1.5, color: textSecondary)),
        ],
      ),
    );
  }
}
