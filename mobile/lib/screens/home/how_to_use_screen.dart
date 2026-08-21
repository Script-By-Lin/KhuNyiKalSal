import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';

class HowToUseScreen extends ConsumerWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'အသုံးပြုပုံ လမ်းညွှန်' : 'How to Use'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Step(
            number: '1',
            title: isMm ? 'အကောင့်ဖွင့်ပြီး အချက်အလက်များ ဖြည့်ပါ' : 'Register Your Account',
            description: isMm
                ? 'သင်၏ ကိုယ်ရေးအချက်အလက်၊ ဆက်သွယ်ရန်ဖုန်းနှင့် သွေးအမျိုးအစားတို့ကို ဖြည့်သွင်းပါ။ ၎င်းသည် ကယ်ဆယ်ရေးအဖွဲ့များ သင့်ကို ပိုမိုမြန်ဆန်စွာ ကူညီနိုင်စေပါသည်။'
                : 'Create an account with your personal and medical information. '
                    'This helps rescue teams assist you faster.',
            icon: Icons.person_add,
          ),
          _Step(
            number: '2',
            title: isMm ? 'မြေပုံဖွင့်၍ အနီးဆုံးအဖွဲ့များ ကြည့်ပါ' : 'Open the Map',
            description: isMm
                ? 'မြေပုံထဲသို့ သွားရောက်ပြီး သင့်လက်ရှိတည်နေရာနှင့် အနီးဆုံး ကယ်ဆယ်ရေးအသင်းအဖွဲ့များကို ကြည့်ရှုနိုင်ပါသည်။'
                : 'Navigate to the Map tab to see your location and nearby rescue organizations.',
            icon: Icons.map,
          ),
          _Step(
            number: '3',
            title: isMm ? 'SOS ခလုတ်ကို ၃ စက္ကန့် ဖိနှိပ်ပါ' : 'Press & Hold SOS',
            description: isMm
                ? 'အရေးပေါ်အခြေအနေ ဖြစ်ပေါ်ပါက အနီရောင် SOS ခလုတ်ကြီးကို ၃ စက္ကန့်ကြာ ဖိနှိပ်ထားပါ။ (မတော်တဆ နှိပ်မိခြင်းမှ ကာကွယ်ရန် ဖြစ်ပါသည်)'
                : 'In an emergency, press and hold the red SOS button for 3 seconds. '
                    'This prevents accidental triggers.',
            icon: Icons.touch_app,
          ),
          _Step(
            number: '4',
            title: isMm ? 'အရေးပေါ်အမျိုးအစား ရွေးချယ်ပါ' : 'Select Emergency Type',
            description: isMm
                ? 'မီးဘေး၊ ဆေးဘက်ဆိုင်ရာ သို့မဟုတ် ရာဇဝတ်မှု စသည့် အရေးပေါ်အမျိုးအစားကို ရွေးချယ်ပါ။ စနစ်မှ အနီးဆုံး သက်ဆိုင်ရာအဖွဲ့သို့ အလိုအလျောက် သတိပေးအကြောင်းကြားပေးပါမည်။'
                : 'Choose Fire, Medical, or Crime. '
                    'The system will alert the nearest relevant organization.',
            icon: Icons.warning_amber,
          ),
          _Step(
            number: '5',
            title: isMm ? 'အကူအညီ လာရောက်မှုကို စောင့်ဆိုင်းပါ' : 'Wait for Response',
            description: isMm
                ? 'စေတနာ့ဝန်ထမ်း ကယ်ဆယ်ရေးသမားမှ သင့်အချက်ပြမှုကို လက်ခံလိုက်ပါက "အကူအညီ လာနေပါပြီ!" ဟု မြင်တွေ့ရပါမည်။ မည်သူမျှ မတုံ့ပြန်ပါက စနစ်သည် နောက်ထပ် အနီးဆုံးအဖွဲ့သို့ အလိုအလျောက် ဆက်လက်လွှဲပြောင်းပေးပါမည်။'
                : 'A volunteer will accept your alert. You\'ll see '
                    '"Help is on the way!" when someone responds. '
                    'If nobody responds, the system automatically tries the next organization.',
            icon: Icons.notifications_active,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.subtleGrey,
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
