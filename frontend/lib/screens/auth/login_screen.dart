import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final isMm = ref.read(settingsProvider).locale.languageCode == 'my';
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'အီးမေးလ်နှင့် လျှို့ဝှက်နံပါတ် ထည့်သွင်းပေးပါ'
                : 'Please enter email and password',
          ),
        ),
      );
      return;
    }

    final auth = ref.read(authProvider.notifier);
    final success = await auth.login(email, password);

    if (success && mounted) {
      final role = ref.read(authProvider).role;
      if (role != null) {
        final lowerRole = role.toLowerCase();
        if (lowerRole == 'admin' || lowerRole == 'superadmin') {
          context.go('/admin-dashboard');
        } else if (lowerRole == 'volunteer') {
          context.go('/volunteer-dashboard');
        } else if (lowerRole == 'organization') {
          context.go('/org-dashboard');
        } else {
          context.go('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Logo / Title ──────────────────────────────────────
                    Image.asset(
                      'assets/images/logo_transparent.png',
                      height: 130,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isMm ? 'အရေးပေါ် ကူညီကယ်ဆယ်ရေး စနစ်' : 'Emergency Response System',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppTheme.subtleGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Email ─────────────────────────────────────────────
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: isMm ? 'အီးမေးလ်' : 'Email',
                        labelText: isMm ? 'အီးမေးလ်' : 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Password ──────────────────────────────────────────
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: isMm ? 'လျှို့ဝှက်နံပါတ်' : 'Password',
                        labelText: isMm ? 'လျှို့ဝှက်နံပါတ်' : 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Forgot Password Button ────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordModal(context, isMm, isDark),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isMm ? 'လျှို့ဝှက်နံပါတ် မေ့နေပါသလား?' : 'Forgot Password?',
                          style: const TextStyle(
                            color: AppTheme.primaryRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Error ─────────────────────────────────────────────
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          authState.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    // ── Login button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isMm ? 'အကောင့်ဝင်မည်' : 'Log In',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Register link ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isMm ? 'အကောင့်မရှိသေးပါက ' : "Don't have an account? ",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/register'),
                          child: Text(
                            isMm ? 'အသစ်ဖွင့်ပါ' : 'Register',
                            style: const TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordModal(BuildContext context, bool isMm, bool isDark) {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final otpCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    int step = 1; // 1 = Request OTP, 2 = Verify OTP & Set New Password
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? modalError;

    Timer? countdownTimer;
    int remainingSeconds = 60;

    void startCountdown(void Function(void Function()) setModalState) {
      countdownTimer?.cancel();
      remainingSeconds = 60;
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (remainingSeconds > 0) {
          setModalState(() => remainingSeconds--);
        } else {
          t.cancel();
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;
            final safeBottom = MediaQuery.of(modalCtx).padding.bottom;

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: bottomInset + safeBottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_reset, color: AppTheme.primaryRed, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step == 1
                                  ? (isMm ? 'လျှို့ဝှက်နံပါတ် ပြန်လည်သတ်မှတ်ရန်' : 'Reset Password')
                                  : (isMm ? 'OTP နံပါတ် အတည်ပြုခြင်း' : 'Verify OTP & Reset'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step == 1
                                  ? (isMm
                                      ? 'သင့် Gmail သို့ ၆ လုံးပါ OTP ကုဒ် (၆၀ စက္ကန့် သက်တမ်း) ပို့ပေးပါမည်'
                                      : 'Enter your Gmail to receive a 6-digit code (60s validity)')
                                  : (isMm
                                      ? '${resetEmailCtrl.text} သို့ OTP ပို့ထားပါသည်'
                                      : 'OTP sent to ${resetEmailCtrl.text}'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          countdownTimer?.cancel();
                          Navigator.pop(modalCtx);
                        },
                        icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (modalError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              modalError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Step 1: Request OTP Form
                  if (step == 1) ...[
                    TextField(
                      controller: resetEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: isMm ? 'အီးမေးလ် / Gmail' : 'Registered Email / Gmail',
                        hintText: 'user@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final email = resetEmailCtrl.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setModalState(() {
                                    modalError = isMm
                                        ? 'မှန်ကန်သော အီးမေးလ် ထည့်သွင်းပါ'
                                        : 'Please enter a valid email address';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isLoading = true;
                                  modalError = null;
                                });

                                try {
                                  await ApiService().forgotPassword(email);
                                  setModalState(() {
                                    step = 2;
                                    isLoading = false;
                                  });
                                  startCountdown(setModalState);
                                } catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                    modalError = (e as dynamic).response?.data?['detail'] ??
                                        (isMm ? 'OTP ပို့ရာတွင် အမှားဖြစ်ပွားပါသည်' : 'Failed to send OTP. Please check your email.');
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                isMm ? 'OTP ကုဒ် ပို့မည်' : 'Send OTP Code',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],

                  // Step 2: Enter OTP & New Password Form
                  if (step == 2) ...[
                    // OTP Code Field
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                        color: remainingSeconds > 0 ? const Color(0xFF00E676) : Colors.red,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: isMm ? '၆ လုံးပါ OTP ကုဒ်' : '6-Digit OTP Code',
                        hintText: '123456',
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── 60s Countdown Live Indicator ─────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: (remainingSeconds > 0 ? const Color(0xFF00E676) : Colors.red).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (remainingSeconds > 0 ? const Color(0xFF00E676) : Colors.red).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            remainingSeconds > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                            size: 18,
                            color: remainingSeconds > 0 ? const Color(0xFF00E676) : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              remainingSeconds > 0
                                  ? (isMm
                                      ? 'ကျန်ရှိချိန် - ${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')} စက္ကန့်'
                                      : 'Valid for: ${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}')
                                  : (isMm
                                      ? 'OTP သက်တမ်းကုန်သွားပါပြီ။ OTP ပြန်ပို့မည် ကို နှိပ်ပါ'
                                      : 'OTP expired! Please tap Resend OTP below.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                fontWeight: FontWeight.bold,
                                color: remainingSeconds > 0
                                    ? (isDark ? Colors.white70 : Colors.black87)
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // New Password Field with Eye Toggle
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: isMm ? 'လျှို့ဝှက်နံပါတ် အသစ်' : 'New Password',
                        hintText: isMm ? 'အနည်းဆုံး ၆ လုံး၊ စာလုံးကြီး/သေး/နံပါတ်' : 'Min 6 chars, Upper/Lower/Digit',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Re-enter Password Field with Eye Toggle
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: isMm ? 'လျှို့ဝှက်နံပါတ် ထပ်မံရိုက်ထည့်ပါ' : 'Re-enter New Password',
                        hintText: isMm ? 'လျှို့ဝှက်နံပါတ် အသစ်နှင့် တူညီရပါမည်' : 'Must match new password',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resend OTP / Change Email Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  countdownTimer?.cancel();
                                  setModalState(() {
                                    step = 1;
                                    modalError = null;
                                  });
                                },
                          child: Text(
                            isMm ? '← အီးမေးလ် ပြန်ပြောင်းမည်' : '← Change Email',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setModalState(() {
                                    isLoading = true;
                                    modalError = null;
                                  });
                                  try {
                                    await ApiService().forgotPassword(resetEmailCtrl.text.trim());
                                    setModalState(() {
                                      isLoading = false;
                                      modalError = null;
                                    });
                                    startCountdown(setModalState);
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isMm ? 'OTP ကုဒ် အသစ် ပို့ပြီးပါပြီ (၆၀ စက္ကန့် သက်တမ်း)' : 'New OTP code resent (valid for 60s)!',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isLoading = false;
                                      modalError = (e as dynamic).response?.data?['detail'] ??
                                          (isMm ? 'OTP ပြန်ပို့ရာတွင် အမှားဖြစ်ပွားပါသည်' : 'Failed to resend OTP.');
                                    });
                                  }
                                },
                          child: Text(
                            isMm ? 'OTP ပြန်ပို့မည်' : 'Resend OTP',
                            style: const TextStyle(color: AppTheme.primaryRed, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Reset Password Submit Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final otp = otpCtrl.text.trim();
                                final newPass = newPasswordCtrl.text;
                                final confirmPass = confirmPasswordCtrl.text;

                                if (otp.length != 6) {
                                  setModalState(() {
                                    modalError = isMm
                                        ? '၆ လုံးပါ OTP ကုဒ် အပြည့်အစုံ ရိုက်ထည့်ပါ'
                                        : 'Please enter the complete 6-digit OTP';
                                  });
                                  return;
                                }

                                if (newPass.length < 6) {
                                  setModalState(() {
                                    modalError = isMm
                                        ? 'လျှို့ဝှက်နံပါတ်သည် အနည်းဆုံး ၆ လုံး ရှိရပါမည်'
                                        : 'Password must be at least 6 characters long';
                                  });
                                  return;
                                }

                                if (!RegExp(r'[A-Z]').hasMatch(newPass) ||
                                    !RegExp(r'[a-z]').hasMatch(newPass) ||
                                    !RegExp(r'\d').hasMatch(newPass)) {
                                  setModalState(() {
                                    modalError = isMm
                                        ? 'စာလုံးကြီး (A-Z)၊ စာလုံးသေး (a-z) နှင့် နံပါတ် (0-9) ပါဝင်ရပါမည်'
                                        : 'Must contain uppercase (A-Z), lowercase (a-z), and numbers (0-9)';
                                  });
                                  return;
                                }

                                if (newPass != confirmPass) {
                                  setModalState(() {
                                    modalError = isMm
                                        ? 'ရိုက်ထည့်ထားသော လျှို့ဝှက်နံပါတ် ၂ ခု မတူညီပါ'
                                        : 'Passwords do not match. Please re-enter carefully.';
                                  });
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(modalCtx);

                                setModalState(() {
                                  isLoading = true;
                                  modalError = null;
                                });

                                try {
                                  await ApiService().resetPassword(
                                    email: resetEmailCtrl.text.trim(),
                                    otp: otp,
                                    newPassword: newPass,
                                  );

                                  if (mounted) {
                                    countdownTimer?.cancel();
                                    navigator.pop();
                                    _emailCtrl.text = resetEmailCtrl.text.trim();
                                    _passwordCtrl.clear();

                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF10B981),
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.white),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                isMm
                                                    ? 'လျှို့ဝှက်နံပါတ် ပြောင်းလဲပြီးပါပြီ။ လျှို့ဝှက်နံပါတ်အသစ်ဖြင့် အကောင့်ဝင်နိုင်ပါပြီ။'
                                                    : 'Password reset successfully! Please log in with your new password.',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                    modalError = (e as dynamic).response?.data?['detail'] ??
                                        (isMm ? 'လျှို့ဝှက်နံပါတ် ပြောင်းလဲရာတွင် အမှားဖြစ်ပွားပါသည်' : 'Failed to reset password. Please check OTP.');
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                              )
                            : Text(
                                isMm ? 'လျှို့ဝှက်နံပါတ် အသစ်ပြောင်းမည်' : 'Reset Password',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
