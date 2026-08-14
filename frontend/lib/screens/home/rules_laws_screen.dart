import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';

class RulesLawsScreen extends ConsumerWidget {
  const RulesLawsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'စည်းမျဉ်းများနှင့် ဥပဒေများ' : 'Rules & Laws'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _RuleCard(
            icon: Icons.warning,
            title: isMm ? 'မမှန်မကန် အချက်ပြမှုများ' : 'False Alerts',
            body: isMm
                ? 'မမှန်ကန်သော အရေးပေါ် SOS အချက်ပြမှုများ ပြုလုပ်ခြင်းသည် ဥပဒေအရ ပြစ်ဒဏ်ကျခံရနိုင်သော ပြစ်မှုဖြစ်ပါသည်။ စနစ်ကို အလွဲသုံးစားပြုလုပ်သော အသုံးပြုသူများကို အကောင့်ပိတ်သိမ်းမည်ဖြစ်ပြီး ဥပဒေအရ အရေးယူမှုများ ပြုလုပ်သွားပါမည်။'
                : 'Triggering false SOS alerts is a punishable offence. '
                    'Users found abusing the system will be blocked and may '
                    'face legal consequences.',
            color: Colors.orange,
          ),
          _RuleCard(
            icon: Icons.shield,
            title: isMm ? 'အချက်အလက် လုံခြုံရေး' : 'Data Privacy',
            body: isMm
                ? 'သင်၏ ကိုယ်ရေးကိုယ်တာနှင့် ကျန်းမာရေးဆိုင်ရာ အချက်အလက်များကို လျှို့ဝှက်ကုဒ်ဖြင့် လုံခြုံစွာ ထိန်းသိမ်းထားပြီး အရေးပေါ်ကယ်ဆယ်ရေး လုပ်ငန်းများအတွင်း တုံ့ပြန်ကယ်ဆယ်ရေးအဖွဲ့များနှင့်သာ မျှဝေပါသည်။'
                : 'Your personal and medical information is encrypted and '
                    'shared only with responding rescue teams during emergencies.',
            color: AppTheme.secondaryGreen,
          ),
          _RuleCard(
            icon: Icons.speed,
            title: isMm ? 'နေ့စဉ် အသုံးပြုမှု ကန့်သတ်ချက်' : 'Daily Limits',
            body: isMm
                ? 'စနစ်အလွဲသုံးစားမှုကို ကာကွယ်ရန်အတွက် အသုံးပြုသူတစ်ဦးလျှင် တစ်ရက်အတွင်း အများဆုံး SOS အကြိမ် ၅ ကြိမ်သာ ပြုလုပ်နိုင်ပါသည်။ အထူးကိစ္စရပ်များအတွက် သက်ဆိုင်ရာဌာနသို့ ဆက်သွယ်ပါ။'
                : 'To prevent abuse, each user may trigger a maximum of '
                    '5 SOS alerts per day. Contact support for exceptional cases.',
            color: AppTheme.primaryRed,
          ),
          _RuleCard(
            icon: Icons.people,
            title: isMm ? 'စေတနာ့ဝန်ထမ်း စည်းကမ်းချက်များ' : 'Volunteer Conduct',
            body: isMm
                ? 'စေတနာ့ဝန်ထမ်းများသည် အရေးပေါ်အချက်ပြမှုများကို အချိန်နှင့်တပြေးညီ ကျွမ်းကျင်စွာ တုံ့ပြန်ကူညီရပါမည်။ သတ်မှတ်ထားသော စည်းမျဉ်းများကို မလိုက်နာပါက အဖွဲ့အစည်းမှ ထုတ်ပယ်ခြင်းခံရနိုင်ပါသည်။'
                : 'Volunteers must respond promptly and professionally. '
                    'Failure to follow protocols may result in removal from '
                    'the organization.',
            color: Colors.blue,
          ),
          _RuleCard(
            icon: Icons.gavel,
            title: isMm ? 'တရားဥပဒေဆိုင်ရာ မူဘောင်' : 'Legal Framework',
            body: isMm
                ? 'ဤအက်ပလီကေးရှင်းသည် မြန်မာနိုင်ငံ သဘာဝဘေးအန္တရာယ် စီမံခန့်ခွဲမှုနှင့် အရေးပေါ်တုံ့ပြန်ရေးဆိုင်ရာ စည်းမျဉ်းဥပဒေများနှင့်အညီ လည်ပတ်ဆောင်ရွက်နေပါသည်။ သက်ဆိုင်သူအားလုံးသည် တည်ဆဲဥပဒေများကို လိုက်နာရန် တာဝန်ရှိပါသည်။'
                : 'This application operates under Myanmar disaster management '
                    'and emergency response regulations. All parties are bound by '
                    'applicable national laws.',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _RuleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
