import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/onboarding_providers.dart';
import '../domain/tenant_invite.dart';

enum _JoinStep { phone, otp, confirmName, done }

/// The invite-link entry point: `/join/:token`. Mirrors `Auth.dc.html`'s
/// `hasInvite` branch exactly — phone OTP, then a "you're joining {PG}"
/// confirmation with just a name field, then done. Not inside any
/// [RoleShell]: reachable while signed out, so this owns its own
/// [AppScaffold].
class JoinInviteScreen extends ConsumerWidget {
  const JoinInviteScreen({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteAsync = ref.watch(tenantInviteProvider(token));
    return AppScaffold(
      body: AsyncValueView(
        value: inviteAsync,
        onRetry: () => ref.invalidate(tenantInviteProvider(token)),
        loading: (context) => const _JoinSkeleton(),
        data: (context, invite) => _JoinFlow(invite: invite),
      ),
    );
  }
}

class _JoinSkeleton extends StatelessWidget {
  const _JoinSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          SkeletonLine(width: 160, height: 22),
          SizedBox(height: AppSpacing.space6),
          SkeletonBox(width: double.infinity, height: 80),
          SizedBox(height: AppSpacing.space4),
          SkeletonBox(width: double.infinity, height: 48),
        ],
      ),
    );
  }
}

class _JoinFlow extends ConsumerStatefulWidget {
  const _JoinFlow({required this.invite});

  final TenantInvite invite;

  @override
  ConsumerState<_JoinFlow> createState() => _JoinFlowState();
}

class _JoinFlowState extends ConsumerState<_JoinFlow> {
  _JoinStep _step = _JoinStep.phone;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isBusy = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneController.text)) {
      setState(() => _errorText = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final failure = await sendInviteOtp(ref, _phoneController.text);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _errorText = failure?.message;
      if (failure == null) _step = _JoinStep.otp;
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final failure = await verifyInviteOtp(
      ref,
      phoneNumber: _phoneController.text,
      otp: _otpController.text,
    );
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _errorText = failure?.message;
      if (failure == null) _step = _JoinStep.confirmName;
    });
  }

  Future<void> _finishJoin() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = 'Enter your name');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final failure = await completeInviteJoin(
      ref,
      invite: widget.invite,
      name: name,
      phoneNumber: _phoneController.text,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _isBusy = false;
        _errorText = failure.message;
      });
      return;
    }
    setState(() {
      _isBusy = false;
      _step = _JoinStep.done;
    });
    // go_router's redirect (driven by authControllerProvider, which
    // completeInviteJoin just updated) takes the user to Tenant Home —
    // no manual navigation here, same pattern as the normal login flow.
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.space6),
          Text(
            'PG Khata',
            style: AppTextStyles.sectionHeading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: AppSpacing.space6),
          switch (_step) {
            _JoinStep.phone => _PhoneStep(
              controller: _phoneController,
              errorText: _errorText,
              isBusy: _isBusy,
              onChanged: () => setState(() => _errorText = null),
              onSubmit: _sendOtp,
            ),
            _JoinStep.otp => _OtpStep(
              phoneNumber: _phoneController.text,
              controller: _otpController,
              errorText: _errorText,
              isBusy: _isBusy,
              onChanged: () => setState(() => _errorText = null),
              onSubmit: _verifyOtp,
            ),
            _JoinStep.confirmName => _ConfirmNameStep(
              invite: widget.invite,
              controller: _nameController,
              errorText: _errorText,
              isBusy: _isBusy,
              onChanged: () => setState(() => _errorText = null),
              onSubmit: _finishJoin,
            ),
            _JoinStep.done => _DoneStep(
              propertyName: widget.invite.propertyName,
            ),
          },
        ],
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.controller,
    required this.errorText,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool isBusy;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter your phone number',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          "We'll send a one-time code. No passwords.",
          style: AppTextStyles.body.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppTextField(
          label: 'Phone number',
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          autofocus: true,
          errorText: errorText,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.space4),
        PrimaryButton(
          label: 'Send OTP',
          isLoading: isBusy,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.phoneNumber,
    required this.controller,
    required this.errorText,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmit,
  });

  final String phoneNumber;
  final TextEditingController controller;
  final String? errorText;
  final bool isBusy;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the code',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Sent to +91 $phoneNumber via SMS.',
          style: AppTextStyles.body.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppTextField(
          label: 'OTP',
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          errorText: errorText,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.space4),
        PrimaryButton(label: 'Verify', isLoading: isBusy, onPressed: onSubmit),
      ],
    );
  }
}

class _ConfirmNameStep extends StatelessWidget {
  const _ConfirmNameStep({
    required this.invite,
    required this.controller,
    required this.errorText,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmit,
  });

  final TenantInvite invite;
  final TextEditingController controller;
  final String? errorText;
  final bool isBusy;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space3),
          decoration: BoxDecoration(
            color: context.appColors.success100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "You're joining ${invite.propertyName}",
                style: AppTextStyles.rowTitle.copyWith(
                  color: context.appColors.success700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Room ${invite.room}, Bed ${invite.bed} — reserved for you at '
                '${CurrencyFormatter.rupees(invite.rentPerBed)}/month. Just confirm your name below.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        AppTextField(
          label: 'Your name',
          controller: controller,
          autofocus: true,
          errorText: errorText,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.space4),
        PrimaryButton(
          label: 'Continue',
          isLoading: isBusy,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.propertyName});

  final String propertyName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: context.appColors.success100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "You're in.",
            style: AppTextStyles.rowTitle.copyWith(
              color: context.appColors.success700,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Taking you to your Tenant dashboard…',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
