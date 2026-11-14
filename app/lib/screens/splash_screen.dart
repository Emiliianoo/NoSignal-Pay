import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

/// First screen: checks the saved session and opens home or login.
/// Follows Splash.dc.html.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Track of the spinner, from the design (#3A424E). Only used here.
  static const _spinnerTrack = Color(0xFF3A424E);

  @override
  void initState() {
    super.initState();
    // restoreSession() notifies listeners, so it runs after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final auth = context.read<AuthProvider>();
    await auth.restoreSession();
    if (!mounted) return;
    final next = auth.status == AuthStatus.signedIn
        ? Routes.home
        : Routes.login;
    // Replace the splash so "back" never returns to it.
    Navigator.pushReplacementNamed(context, next);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Dark screen: white status bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 48),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogo(size: 88, radius: 28),
                        const SizedBox(height: 20),
                        Text(
                          'NoSignal',
                          style: text.headlineLarge?.copyWith(
                            color: Colors.white,
                            height: 40 / 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        backgroundColor: _spinnerTrack,
                        // Reduced motion: a still quarter arc instead of spinning.
                        value: reduceMotion ? 0.25 : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Abriendo tu billetera',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.textOnDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
