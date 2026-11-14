import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

/// "Crea tu billetera": name, email, password and "Crear cuenta".
/// Follows Register.dc.html.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await context.read<AuthProvider>().register(
      displayName: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!ok || !mounted) return;
    // Signed in: home becomes the only screen, so "back" does not return here.
    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final text = Theme.of(context).textTheme;
    final errorCode = auth.errorCode;

    return PopScope(
      // Going back (arrow or system gesture) must not carry this error to login.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<AuthProvider>().clearError();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56 - 32,
                ),
                child: IntrinsicHeight(
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(-10, 0), // margin-left: -10px
                          child: IconButton(
                            tooltip: 'Volver a iniciar sesión',
                            onPressed: auth.isLoading
                                ? null
                                : () => Navigator.maybePop(context),
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            icon: const AppIcon(
                              AppIcons.back,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Crea tu billetera', style: text.headlineLarge),
                        const SizedBox(height: 32),
                        AppTextField(
                          label: 'Nombre',
                          controller: _name,
                          helperText: 'Es el nombre que verá quien te pague.',
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onChanged: (_) => auth.clearError(),
                        ),
                        const SizedBox(height: 20),
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
                          helperText: 'Usa 8 caracteres o más.',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          // newPassword lets the system suggest a strong one.
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) => auth.clearError(),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (errorCode != null) ...[
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              errorMessage(errorCode),
                              style: text.labelLarge,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        PrimaryButton(
                          label: 'Crear cuenta',
                          isLoading: auth.isLoading,
                          onPressed: _submit,
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Todo el dinero en NoSignal es simulado.',
                            style: text.bodySmall,
                            textAlign: TextAlign.center,
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
      ),
    );
  }
}
