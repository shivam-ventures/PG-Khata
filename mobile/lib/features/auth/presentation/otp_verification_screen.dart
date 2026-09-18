import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Login, step 2: OTP verification, resend, and the invalid-code error
/// state. Mirrors the OTP portion of `Auth.dc.html`.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({required this.phoneNumber, super.key});

  final String phoneNumber;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const _resendCooldown = Duration(seconds: 30);

  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = _resendCooldown.inSeconds;
  bool _isVerifying = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _secondsRemaining = _resendCooldown.inSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _errorText = null);
    await ref.read(authControllerProvider.notifier).sendOtp(widget.phoneNumber);
    if (!mounted) return;
    _startCooldown();
  }

  Future<void> _verify() async {
    if (_controller.text.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorText = null;
    });
    final failure = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(phoneNumber: widget.phoneNumber, otp: _controller.text);
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _errorText = failure?.message;
    });
    // On success, go_router's redirect (driven by authControllerProvider)
    // takes the user to their role home — no manual navigation here.
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.space8),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Enter the code',
              style: AppTextStyles.sectionHeading.copyWith(fontSize: 24),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'We sent a 6-digit code to +91 ${widget.phoneNumber}',
              style: AppTextStyles.body.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
            AppTextField(
              label: 'OTP',
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              errorText: _errorText,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: AppSpacing.space4),
            PrimaryButton(
              label: 'Verify & continue',
              isLoading: _isVerifying,
              onPressed: _verify,
            ),
            const SizedBox(height: AppSpacing.space4),
            Center(
              child: _secondsRemaining > 0
                  ? Text(
                      'Resend code in ${_secondsRemaining}s',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    )
                  : TextButton(
                      onPressed: _resend,
                      child: const Text('Resend code'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
