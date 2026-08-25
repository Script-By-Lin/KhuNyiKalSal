import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';

class HowToUseScreen extends ConsumerWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'အသုံးပြုပုံ လမ်းညွှန်' : 'How to Use & Quick Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Quick Trigger & Hardware Feature Highlight ───────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFF880E4F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB71C1C).withValues(alpha: 0.3),
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
                    const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMm ? 'အရေးပေါ် ခလုတ် ၃ ချက်နှိပ် စနစ်' : 'Hardware Triple-Click Trigger',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isMm
                      ? 'ဖုန်း၏ အသံတိုး/ကျယ်ခလုတ် (Volume Key) ကို ၁.၅ စက္ကန့်အတွင်း ၃ ချက် ဆက်တိုက်နှိပ်ခြင်းဖြင့် အရေးပေါ် SOS သို့မဟုတ် သဘာဝဘေး စနစ်ကို မျက်နှာပြင်မှ ချက်ချင်း ဖွင့်လှစ်ခေါ်ဆိုနိုင်ပါသည်။'
                      : 'Press any Volume button 3 times consecutively within 1.5 seconds to instantly trigger the emergency screen with haptic alarm.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Core Usage Steps ──────────────────────────────────────────
          Text(
            isMm ? 'အခြေခံ အသုံးပြုနည်း အဆင့်ဆင့်' : 'Step-by-Step Emergency Protocols',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 16),

          _Step(
            number: '1',
            title: isMm ? 'အကောင့်ဖွင့်ပြီး ဆေးမှတ်တမ်း ဖြည့်သွင်းပါ' : 'Register Your Medical Profile',
            description: isMm
                ? 'သင်၏ ကိုယ်ရေးအချက်အလက်၊ ဆက်သွယ်ရန်ဖုန်းနှင့် သွေးအမျိုးအစားတို့ကို ဖြည့်သွင်းပါ။ ၎င်းသည် ကယ်ဆယ်ရေးအဖွဲ့များ သင့်ကို ပိုမိုမြန်ဆန်စွာ ကူညီနိုင်စေပါသည်။'
                : 'Create an account with your personal info, blood type, and emergency contacts for swift responder triage.',
            icon: Icons.person_add,
          ),
          _Step(
            number: '2',
            title: isMm ? 'SOS ခလုတ်ကို ၃ စက္ကန့် ဖိနှိပ်ပါ' : 'Press & Hold SOS (3 Seconds)',
            description: isMm
                ? 'အရေးပေါ်အခြေအနေ ဖြစ်ပေါ်ပါက အနီရောင် SOS ခလုတ်ကြီးကို ၃ စက္ကန့်ကြာ ဖိနှိပ်ထားပါ။ (မတော်တဆ နှိပ်မိခြင်းမှ ကာကွယ်ရန် ဖြစ်ပါသည်)'
                : 'In an emergency, press and hold the red SOS button for 3 seconds to prevent accidental false alarms.',
            icon: Icons.touch_app,
          ),
          _Step(
            number: '3',
            title: isMm ? 'အရေးပေါ်အမျိုးအစား ရွေးချယ်ပါ' : 'Select Emergency Type',
            description: isMm
                ? 'မီးဘေး၊ ဆေးဘက်ဆိုင်ရာ၊ ယာဉ်မတော်တဆမှု သို့မဟုတ် သဘာဝဘေး စသည့် အရေးပေါ်အမျိုးအစားကို ရွေးချယ်ပါ။ စနစ်မှ အနီးဆုံး ကယ်ဆယ်ရေးအဖွဲ့သို့ အလိုအလျောက် သတိပေးအကြောင်းကြားပေးပါမည်။'
                : 'Choose Fire, Medical, Accident, or Natural Disaster. The system immediately alerts the nearest rescue teams and volunteers.',
            icon: Icons.warning_amber_rounded,
          ),
          _Step(
            number: '4',
            title: isMm ? 'သဘာဝဘေး ဥဩသံ အသံသတိပေးချက်' : 'Myanmar Proximity Disaster Radar',
            description: isMm
                ? 'သင့်ဒေသ (မြန်မာနိုင်ငံအတွင်း) သို့မဟုတ် သင့်အနီးနားတွင် ငလျင် (M4.0+)၊ မုန်တိုင်း သို့မဟုတ် ရေကြီးရေလျှံမှု ဖြစ်ပွားပါက စနစ်မှ အလိုအလျောက် အရေးပေါ်ဥဩသံဖြင့် ချက်ချင်း သတိပေးပါမည်။'
                : 'Real-time seismic and hazard monitors sound a loud emergency siren if an earthquake (M4.0+), storm, or flood occurs near your location in Myanmar.',
            icon: Icons.thunderstorm_outlined,
          ),
          _Step(
            number: '5',
            title: isMm ? 'သွေးတောင်းခံခြင်းနှင့် လှူဒါန်းခြင်း ဗဟိုဌာန' : 'Blood Request & Donor Hub',
            description: isMm
                ? 'အရေးပေါ် လူနာများအတွက် သွေးတောင်းခံနိုင်ပြီး ကယ်ဆယ်ရေးအဖွဲ့များမှ လက်ခံဆောင်ရွက်ပေးသည့်အခါ တိုက်ရိုက် အသိပေးချက် (Notification with Sound) လက်ခံရရှိပါမည်။'
                : 'Request emergency blood units or schedule donation pledges with instant audible notifications upon hospital/org confirmation.',
            icon: Icons.water_drop_outlined,
          ),
          _Step(
            number: '6',
            title: isMm ? 'အက်ပ် အမြန်ခလုတ်များ (Android Shortcuts)' : 'Android App Shortcuts',
            description: isMm
                ? 'ဖုန်းပင်မမျက်နှာပြင်ရှိ အက်ပ်အိုင်ကွန်ကို ဖိထားပြီး "🚨 Quick SOS" သို့မဟုတ် "🌪️ Disaster Radar" ကို ၁ ချက်နှိပ် တိုက်ရိုက်ဖွင့်လှစ် အသုံးပြုနိုင်ပါသည်။'
                : 'Long-press the app icon on your home screen to instantly access Quick SOS or Disaster Radar via Android Shortcuts.',
            icon: Icons.widgets_outlined,
          ),
          _Step(
            number: '7',
            title: isMm ? 'အကူအညီ လာရောက်မှုကို စောင့်ဆိုင်းပါ' : 'Live Tracking & Response',
            description: isMm
                ? 'စေတနာ့ဝန်ထမ်း ကယ်ဆယ်ရေးသမားမှ သင့်အချက်ပြမှုကို လက်ခံလိုက်ပါက "အကူအညီ လာနေပါပြီ!" ဟု မြင်တွေ့ရပြီး ကယ်ဆယ်ရေးယာဉ် တည်နေရာကို မြေပုံပေါ်တွင် အချိန်နှင့်တပြေးညီ ကြည့်ရှုနိုင်ပါသည်။'
                : 'Once accepted by responders, track rescue vehicles in real time on the live OpenStreetMap radar.',
            icon: Icons.notifications_active_outlined,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _Step({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.primaryRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
