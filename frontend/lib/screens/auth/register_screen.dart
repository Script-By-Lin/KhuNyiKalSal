import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  bool _agreedToTerms = false;
  
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _bloodCtrl.dispose();
    _medicalCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _prevPage() {
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final clean = value.trim().replaceAll(' ', '').replaceAll('-', '');
    final regExp = RegExp(r'^(?:\+959|09)\d{9,10}$');
    if (!regExp.hasMatch(clean)) {
      return 'Phone must start with +959 or 09 followed by 9 or 10 digits\n(e.g., 09123456789 or +959123456789)';
    }
    return null;
  }

  Future<void> _executeRegistration() async {
    final auth = ref.read(authProvider.notifier);
    final cleanPhone = _phoneCtrl.text.trim().replaceAll(' ', '').replaceAll('-', '');

    final success = await auth.registerUser({
      'email': _emailCtrl.text.trim().toLowerCase(),
      'password': _passwordCtrl.text,
      'full_name': _nameCtrl.text.trim(),
      'phone_number': cleanPhone,
      'blood_type': _bloodCtrl.text.trim().isNotEmpty ? _bloodCtrl.text.trim() : null,
      'medical_conditions': _medicalCtrl.text.trim().isNotEmpty ? _medicalCtrl.text.trim() : null,
    });

    if (mounted) {
      if (success) {
        context.go('/home');
      } else {
        final errorMsg = ref.read(authProvider).error ?? 'Registration failed. Please check your inputs.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $errorMsg'),
            backgroundColor: AppTheme.primaryRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildStep1Form(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/login'),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(width: 8),
                Text(
                  'Join Khu Nyi Kal Sal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create your victim emergency account for instant rescue assistance.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // User Fields
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g. user@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Min 6 characters',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: _validatePassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number (+959... or 09...)',
                hintText: 'e.g. 0912345678 or +95912345678',
                helperText: 'Must start with +959 or 09 followed by 9 or 10 digits',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bloodCtrl,
              decoration: const InputDecoration(
                labelText: 'Blood Type (Optional)',
                hintText: 'e.g. A+, O-, B+',
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _medicalCtrl,
              decoration: const InputDecoration(
                labelText: 'Medical Conditions / Allergies (Optional)',
                hintText: 'Any existing medical conditions or allergies',
                prefixIcon: Icon(Icons.medical_information_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _nextPage();
                  }
                },
                child: const Text('Continue to Terms & Agreement'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Terms(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _prevPage,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const Icon(Icons.gavel, color: AppTheme.primaryRed, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Terms & Conditions', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'စည်းမျဉ်းစည်းကမ်းများ',
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _legalSectionBlack('ဝန်ဆောင်မှုအသုံးပြုခြင်းဆိုင်ရာ သဘောတူညီချက်', 'ဤအက်ပလီကေးရှင်းကို အသုံးပြုခြင်းဖြင့် အောက်ပါစည်းမျဉ်းစည်းကမ်းများကို သင်လက်ခံသဘောတူပါသည်။ ဤဝန်ဆောင်မှုသည် အရေးပေါ်အခြေအနေများတွင် ကူညီကယ်ဆယ်ရေးအဖွဲ့များနှင့် ချိတ်ဆက်ပေးရန် ရည်ရွယ်ပါသည်။'),
                  _legalSectionBlack('အသုံးပြုသူ၏ တာဝန်များ', '၁။ မှန်ကန်သောအချက်အလက်များ ဖြည့်သွင်းရမည်။\n၂။ အရေးပေါ်မဟုတ်သော SOS အချက်ပြမှုများ မလုပ်ရ။\n၃။ မမှန်ကန်သော SOS အချက်ပြမှု ပြုလုပ်ပါက ဥပဒေအရ အရေးယူခံရနိုင်ပါသည်။\n၄။ ကိုယ်ရေးအချက်အလက်များကို တိကျမှန်ကန်စွာ ဖြည့်သွင်းပေးရမည်။'),
                  _legalSectionBlack('ကိုယ်ရေးအချက်အလက် ကာကွယ်ရေး', 'သင်၏ကိုယ်ရေးအချက်အလက်များကို အရေးပေါ်ကယ်ဆယ်ရေးလုပ်ငန်းများအတွက်သာ အသုံးပြုမည်ဖြစ်ပြီး သင့်ခွင့်ပြုချက်မရှိဘဲ အခြားမည်သည့်‌ကိစ္စများတွင်မျှ အသုံးပြုမည်မဟုတ်ပါ။'),
                  _legalSectionBlack('ဥပဒေရေးရာ သတိပေးချက်', 'အရေးပေါ်မဟုတ်ဘဲ SOS ခလုတ်ကို နှိပ်ခြင်းသည် '
                  'ဥပဒေအရ ပြစ်မှုကျူးလွန်ရာ ကျရောက်နိုင်ပါသည်။ '
                  'မမှန်ကန်သော အချက်ပြမှုများအတွက် '
                  'အကောင့်ပိတ်သိမ်းခြင်း အပါအဝင် တရားနှောက်ယှက်မှု ဥပဒေများဖြင့် တရားစွဲခံရနိုင်ပါသည်။'),
                  
                  const Divider(color: Colors.black12, height: 32, thickness: 1),
                  
                  const Text(
                    'Terms of Service (English)',
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _legalSectionBlack('Service Agreement', 'By using Khu Nyi Kal Sal, you agree to these terms. This app connects users to nearby rescue organizations during emergencies.'),
                  _legalSectionBlack('User Responsibilities', '• Provide accurate personal and medical information.\n• Only use SOS for genuine emergencies.\n• False alerts may result in account suspension and legal action.\n• Keep your location services enabled for accurate response.'),
                  _legalSectionBlack('Privacy', 'Your data is used solely for emergency response and is not shared with third parties without consent.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                activeColor: AppTheme.primaryRed,
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.black, width: 2),
                onChanged: (v) {
                  setState(() => _agreedToTerms = v!);
                },
              ),
              const Expanded(
                child: Text(
                  'I have read and agree to the Terms & Conditions',
                  style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent Error Alert Banner on Agreement Page
                  if (authState.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade400, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Registration Failed',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  authState.error!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                      onPressed: (_agreedToTerms && !authState.isLoading) ? _executeRegistration : null,
                      child: authState.isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('CONFIRM & REGISTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legalSectionBlack(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStep1Form(context),
            _buildStep2Terms(context),
          ],
        ),
      ),
    );
  }
}
