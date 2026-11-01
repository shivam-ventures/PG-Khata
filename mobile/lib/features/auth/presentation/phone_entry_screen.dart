import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/result.dart';
import '../../../core/routing/app_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

/// Login, step 1: phone number entry. Mirrors `Auth.dc.html`'s phone field
/// only — the self-registration/role-picker/join-code parts of that screen
/// are handled by the separate join-invite flow, not here.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValidPhone => RegExp(r'^[6-9]\d{9}$').hasMatch(_controller.text);

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_isValidPhone) {
      setState(() => _errorText = l10n.loginInvalidPhone);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .sendOtp(_controller.text);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.when(
      ok: (_) => context.push('/login/verify?phone=${_controller.text}'),
      err: (failure) => setState(() => _errorText = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.space8),
            Text(
              l10n.appName,
              style: AppTextStyles.sectionHeading.copyWith(fontSize: 28),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              l10n.loginTitle,
              style: AppTextStyles.body.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
            AppTextField(
              label: l10n.loginPhoneLabel,
              controller: _controller,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              autofocus: true,
              errorText: _errorText,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: AppSpacing.space4),
            PrimaryButton(
              label: l10n.loginSendOtp,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.space4),
            Center(
              child: TextButton(
                onPressed: () => context.push(AppRoute.register),
                child: Text(l10n.loginNoInvite),
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              l10n.loginDemoAccounts,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
