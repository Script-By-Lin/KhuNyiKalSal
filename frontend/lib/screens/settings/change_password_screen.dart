import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(() => setState(() {}));
    _confirmPassCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPassCtrl.text.length >= 6;
  bool get _hasUppercase => _newPassCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newPassCtrl.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _newPassCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;

  Future<void> _submitChangePassword(bool isMm) async {
    final currentPass = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() {
        _errorMessage = isMm
            ? 'စကားဝှက် အကွက်အားလုံးကို ပြည့်စုံစွာ ဖြည့်သွင်းပါ။'
            : 'Please fill in all password fields.';
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = isMm
            ? 'စကားဝှက်အသစ်နှင့် အတည်ပြုစကားဝှက် မတူညီပါ။'
            : 'New password and confirmation do not match.';
      });
      return;
    }

    if (newPass.length < 6) {
      setState(() {
        _errorMessage = isMm
            ? 'စကားဝှက်အသစ်သည် အနည်းဆုံး စာလုံး ၆ လုံး ရှိရပါမည်။'
            : 'Password must be at least 6 characters long.';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiService().changePassword(
        currentPassword: currentPass,
        newPassword: newPass,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _successMessage = isMm
              ? 'စကားဝှက်ကို အောင်မြင်စွာ ပြောင်းလဲပြီးပါပြီ။'
              : 'Password changed successfully.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMm
                        ? 'စကားဝှက်ကို အောင်မြင်စွာ ပြောင်းလဲပြီးပါပြီ။'
                        : 'Password changed successfully.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.secondaryGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = isMm
            ? 'စကားဝှက် ပြောင်းလဲ၍ မရပါ။ လက်ရှိစကားဝှက် မှန်ကန်မှု ရှိမရှိ စစ်ဆေးပါ။'
            : 'Failed to change password. Please check your current password.';

        try {
          final dioErr = e as dynamic;
          if (dioErr.response?.data?['detail'] != null) {
            msg = dioErr.response.data['detail'].toString();
          }
        } catch (_) {}

        setState(() {
          _isSubmitting = false;
          _errorMessage = msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'စကားဝှက် ပြောင်းလဲရန်' : 'Change Password',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Security Card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: isDark ? Colors.amber : Colors.amber.shade900,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm ? 'အကောင့်လုံခြုံရေး စကားဝှက်' : 'Account Security',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMm
                                ? 'သင့်အကောင့်ကို ပိုမိုလုံခြုံစေရန် အနည်းဆုံး စာလုံး ၆ လုံး၊ အင်္ဂလိပ်စာလုံးကြီး၊ စာလုံးသေးနှင့် ဂဏန်းများ ပါဝင်သော စကားဝှက်အသစ် သတ်မှတ်ပါ။'
                                : 'Protect your emergency response account by setting a strong, secure password.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Error Banner ──────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFFDC2626) : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: isDark ? Colors.red.shade300 : Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ── Success Banner ────────────────────────────────────
              if (_successMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF059669) : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ── 1. Current Password ───────────────────────────────
              Text(
                isMm ? '၁။ လက်ရှိ စကားဝှက်' : '1. Current Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                style: TextStyle(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: isMm ? 'လက်ရှိ စကားဝှက် ရိုက်ထည့်ပါ' : 'Enter current password',
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.lock_outline, color: textSecondary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── 2. New Password ───────────────────────────────────
              Text(
                isMm ? '၂။ စကားဝှက် အသစ်' : '2. New Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                style: TextStyle(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: isMm ? 'စကားဝှက် အသစ် ရိုက်ထည့်ပါ' : 'Enter new secure password',
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppTheme.primaryRed, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                  ),
                ),
              ),

              // ── Live Password Requirements Checklist ──────────────
              if (_newPassCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isPasswordValid
                        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : Colors.green.shade50)
                        : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPasswordValid
                          ? (isDark ? const Color(0xFF059669) : Colors.green.shade300)
                          : cardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCheckItem('At least 6 characters', _hasMinLength, isDark),
                      const SizedBox(height: 4),
                      _buildCheckItem('At least 1 uppercase letter (A-Z)', _hasUppercase, isDark),
                      const SizedBox(height: 4),
                      _buildCheckItem('At least 1 lowercase letter (a-z)', _hasLowercase, isDark),
                      const SizedBox(height: 4),
                      _buildCheckItem('At least 1 number (0-9)', _hasNumber, isDark),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── 3. Confirm New Password ───────────────────────────
              Text(
                isMm ? '၃။ စကားဝှက် အသစ် ထပ်မံရိုက်ထည့်ပါ' : '3. Confirm New Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                style: TextStyle(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: isMm ? 'စကားဝှက် အသစ် ပြန်ရိုက်ပါ' : 'Re-enter new password to verify',
                  hintStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(
                    _confirmPassCtrl.text.isNotEmpty && _confirmPassCtrl.text == _newPassCtrl.text
                        ? Icons.check_circle_outline
                        : Icons.lock_clock_outlined,
                    color: _confirmPassCtrl.text.isNotEmpty && _confirmPassCtrl.text == _newPassCtrl.text
                        ? AppTheme.secondaryGreen
                        : textSecondary,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Submit Button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.shield_rounded, color: Colors.white),
                  label: Text(
                    _isSubmitting
                        ? (isMm ? 'သိမ်းဆည်းနေပါသည်...' : 'UPDATING...')
                        : (isMm ? 'စကားဝှက် အသစ်သိမ်းမည်' : 'UPDATE PASSWORD'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSubmitting ? null : () => _submitChangePassword(isMm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isMet, bool isDark) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isMet
              ? AppTheme.secondaryGreen
              : (isDark ? Colors.white38 : Colors.grey.shade400),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            color: isMet
                ? (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade800)
                : (isDark ? Colors.white60 : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
