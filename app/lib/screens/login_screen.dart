import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

/// "Entra a tu billetera": email, password and "Entrar". Follows Login.dc.html.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus(); // hide the keyboard
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _email.text.trim(),
      password: _password.text,
    );
    // The screen may have closed while waiting; then there is nothing to do.
    if (!ok || !mounted) return;
    // Remove login from the stack so "back" does not return to it.
    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
  }

  void _openRegister() {
    context.read<AuthProvider>().clearError();
    Navigator.pushNamed(context, Routes.register);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;
    final errorCode = auth.errorCode;

    return Scaffold(
      body: SafeArea(
        // Scrolls when the keyboard covers the form, but fills the screen when
        // it fits, so the "Crea tu billetera" link stays at the bottom.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 72 - 32,
              ),
              child: IntrinsicHeight(
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppLogo(size: 48, radius: 16),
                      const SizedBox(height: 32),
                      Text('Entra a tu billetera', style: text.headlineLarge),
                      const SizedBox(height: 40),
                      AppTextField(
                        label: 'Correo',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => auth.clearError(),
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'Contraseña',
                        controller: _password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onChanged: (_) => auth.clearError(),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (errorCode != null) ...[
                        const SizedBox(height: 20),
                        _ErrorText(errorMessage(errorCode)),
                      ],
                      const SizedBox(height: 32),
                      PrimaryButton(
                        label: 'Entrar',
                        isLoading: auth.isLoading,
                        onPressed: _submit,
                      ),
                      const Spacer(), // pushes the link to the bottom
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '¿Es tu primera vez?',
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: auth.isLoading ? null : _openRegister,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Crea tu billetera'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An error under the form. Uses ink (not a new color) to keep a single
/// accent; liveRegion makes screen readers announce it when it appears.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(message, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
