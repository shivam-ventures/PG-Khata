import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/onboarding_providers.dart';
import '../domain/public_property_listing.dart';

enum _RegisterStep { property, phone, otp, confirmName, done }

/// The direct self-registration entry point: `/register`, reachable while
/// signed out — the "second onboarding path" alongside `JoinInviteScreen`'s
/// invite-link flow. Unlike that flow, nobody has already picked a specific
/// bed, so this adds one step up front (pick a PG) and ends in the
/// Owner/Manager Tenants screens' "self-registered — needs a bed" list
/// rather than an active tenancy — see [OnboardingRepository.selfRegister]'s
/// doc comment.
class SelfRegisterScreen extends ConsumerWidget {
  const SelfRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(publicPropertiesProvider);
    return AppScaffold(
      body: AsyncValueView(
        value: propertiesAsync,
        onRetry: () => ref.invalidate(publicPropertiesProvider),
        loading: (context) => const _RegisterSkeleton(),
        data: (context, properties) => _RegisterFlow(properties: properties),
      ),
    );
  }
}

class _RegisterSkeleton extends StatelessWidget {
  const _RegisterSkeleton();

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

class _RegisterFlow extends ConsumerStatefulWidget {
  const _RegisterFlow({required this.properties});

  final List<PublicPropertyListing> properties;

  @override
  ConsumerState<_RegisterFlow> createState() => _RegisterFlowState();
}

class _RegisterFlowState extends ConsumerState<_RegisterFlow> {
  _RegisterStep _step = _RegisterStep.property;
  PublicPropertyListing? _selectedProperty;
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

  void _selectProperty(PublicPropertyListing property) {
    setState(() {
      _selectedProperty = property;
      _step = _RegisterStep.phone;
    });
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
      if (failure == null) _step = _RegisterStep.otp;
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
      if (failure == null) _step = _RegisterStep.confirmName;
    });
  }

  Future<void> _finishRegister() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = 'Enter your name');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final failure = await selfRegisterTenant(
      ref,
      fullName: name,
      propertyId: _selectedProperty!.propertyId,
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
      _step = _RegisterStep.done;
    });
    // go_router's redirect (driven by authControllerProvider, which
    // selfRegisterTenant just updated) takes the user to Tenant Home —
    // same pattern as the invite-join flow.
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
            _RegisterStep.property => _PropertyStep(
              properties: widget.properties,
              onSelect: _selectProperty,
            ),
            _RegisterStep.phone => _PhoneStep(
              propertyName: _selectedProperty!.name,
              controller: _phoneController,
              errorText: _errorText,
              isBusy: _isBusy,
              onChanged: () => setState(() => _errorText = null),
              onSubmit: _sendOtp,
            ),
            _RegisterStep.otp => _OtpStep(
              phoneNumber: _phoneController.text,
              controller: _otpController,
              errorText: _errorText,
              isBusy: _isBusy,
              onChanged: () => setState(() => _errorText = null),
              onSubmit: _verifyOtp,
            ),
            _RegisterStep.confirmName => _ConfirmNameStep(
              propertyName: _selectedProperty!.name,
              controller: _nameController,
              errorText: _errorText,
              isBusy: _isBusy,
              onChanged: () => setState(() => _errorText = null),
              onSubmit: _finishRegister,
            ),
            _RegisterStep.done => const _DoneStep(),
          },
        ],
      ),
    );
  }
}

class _PropertyStep extends StatelessWidget {
  const _PropertyStep({required this.properties, required this.onSelect});

  final List<PublicPropertyListing> properties;
  final ValueChanged<PublicPropertyListing> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Which PG do you want to join?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          "You'll pick your name and phone next — staff there confirms "
          'your room and rent.',
          style: AppTextStyles.body.copyWith(color: context.appColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.space4),
        if (properties.isEmpty)
          Text(
            'No PGs are open for registration right now.',
            style: AppTextStyles.body.copyWith(
              color: context.appColors.textMuted,
            ),
          )
        else
          for (final property in properties)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: InkWell(
                onTap: () => onSelect(property),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appColors.divider),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(property.name, style: AppTextStyles.rowTitle),
                            Text(
                              property.address,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.appColors.textMuted,
                              ),
                            ),
                            Text(
                              property.vacantBedCount > 0
                                  ? '${property.vacantBedCount} beds vacant'
                                  : 'No beds vacant right now',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: property.vacantBedCount > 0
                                    ? context.appColors.success700
                                    : context.appColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.propertyName,
    required this.controller,
    required this.errorText,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmit,
  });

  final String propertyName;
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
          "Joining $propertyName. We'll send a one-time code. No passwords.",
          style: AppTextStyles.body.copyWith(color: context.appColors.textMuted),
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
          style: AppTextStyles.body.copyWith(color: context.appColors.textMuted),
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
    required this.propertyName,
    required this.controller,
    required this.errorText,
    required this.isBusy,
    required this.onChanged,
    required this.onSubmit,
  });

  final String propertyName;
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
                "You're registering interest in $propertyName",
                style: AppTextStyles.rowTitle.copyWith(
                  color: context.appColors.success700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Staff will confirm your room and rent shortly. Just '
                'confirm your name below.',
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
  const _DoneStep();

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
            "You're registered.",
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
