import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';

class LegalAgreementScreen extends StatelessWidget {
  const LegalAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'စည်းမျဉ်းစည်းကမ်းများ',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _section(
              'ဝန်ဆောင်မှုအသုံးပြုခြင်းဆိုင်ရာ သဘောတူညီချက်',
              'ဤအက်ပလီကေးရှင်းကို အသုံးပြုခြင်းဖြင့် '
                  'အောက်ပါစည်းမျဉ်းစည်းကမ်းများကို သင်လက်ခံသဘောတူပါသည်။ '
                  'ဤဝန်ဆောင်မှုသည် အရေးပေါ်အခြေအနေများတွင် '
                  'ကူညီကယ်ဆယ်ရေးအဖွဲ့များနှင့် ချိတ်ဆက်ပေးရန် '
                  'ရည်ရွယ်ပါသည်။',
            ),
            _section(
              'အသုံးပြုသူ၏ တာဝန်များ',
              '၁။ မှန်ကန်သောအချက်အလက်များ ဖြည့်သွင်းရမည်။\n'
                  '၂။ အရေးပေါ်မဟုတ်သော SOS အချက်ပြမှုများ မလုပ်ရ။\n'
                  '၃။ မမှန်ကန်သော SOS အချက်ပြမှု ပြုလုပ်ပါက '
                  'ဥပဒေအရ အရေးယူခံရနိုင်ပါသည်။\n'
                  '၄။ ကိုယ်ရေးအချက်အလက်များကို တိကျမှန်ကန်စွာ '
                  'ဖြည့်သွင်းပေးရမည်။',
            ),
            _section(
              'ကိုယ်ရေးအချက်အလက် ကာကွယ်ရေး',
              'သင်၏ကိုယ်ရေးအချက်အလက်များကို အရေးပေါ်'
                  'ကယ်ဆယ်ရေးလုပ်ငန်းများအတွက်သာ '
                  'အသုံးပြုမည်ဖြစ်ပြီး သင့်ခွင့်ပြုချက်မရှိဘဲ '
                  'အခြားမည်သည့်‌ကိစ္စများတွင်မျှ အသုံးပြုမည်မဟုတ်ပါ။',
            ),
            _section(
              'ဥပဒေရေးရာ သတိပေးချက်',
              'အရေးပေါ်မဟုတ်ဘဲ SOS ခလုတ်ကို နှိပ်ခြင်းသည် '
                  'ဥပဒေအရ ပြစ်မှုကျူးလွန်ရာ ကျရောက်နိုင်ပါသည်။ '
                  'မမှန်ကန်သော အချက်ပြမှုများအတွက် '
                  'အကောင့်ပိတ်သိမ်းခြင်း အပါအဝင် တရားနှောက်ယှက်မှု ဥပဒေများဖြင့် တရားစွဲခံရနိုင်ပါသည်။',
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Terms of Service (English)',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            _section(
              'Service Agreement',
              'By using Khu Nyi Kal Sal, you agree to these terms. '
                  'This app connects users to nearby rescue organizations '
                  'during emergencies.',
            ),
            _section(
              'User Responsibilities',
              '• Provide accurate personal and medical information.\n'
                  '• Only use SOS for genuine emergencies.\n'
                  '• False alerts may result in account suspension and legal action.\n'
                  '• Keep your location services enabled for accurate response.',
            ),
            _section(
              'Privacy',
              'Your data is used solely for emergency response and is not '
                  'shared with third parties without consent.',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('I Understand'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}
