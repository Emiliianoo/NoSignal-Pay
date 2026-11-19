import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'core/token_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/confirm_payment_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/payment_result_screen.dart';
import 'screens/register_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/splash_screen.dart';

/// Set with `flutter run --dart-define=API_BASE_URL=<url>`.
/// The default works on the iPhone simulator. Use `http://10.0.2.2:8000` on
/// the Android emulator and `http://<laptop-ip>:8000` on a physical phone.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

void main() {
  final tokenStorage = TokenStorage();
  final api = ApiClient(baseUrl: apiBaseUrl, readToken: tokenStorage.read);
  final wallet = WalletProvider(api: api);
  final payment = PaymentProvider(api: api);
  final auth = AuthProvider(
    api: api,
    tokenStorage: tokenStorage,
    // The next user must not see this balance or a half-finished payment.
    onSignedOut: () {
      wallet.clear();
      payment.clear();
    },
  );

  runApp(
    // Every provider is created here, above MaterialApp, so all screens can
    // reach them with context.watch / context.read. They are created first
    // (not inside create:) because AuthProvider needs to clear the others.
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: wallet),
        ChangeNotifierProvider.value(value: payment),
      ],
      child: const NoSignalApp(),
    ),
  );
}

class NoSignalApp extends StatelessWidget {
  const NoSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoSignal',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Dark status bar icons on every screen; the splash (dark background)
      // overrides this with white icons while it is visible.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: child!,
      ),
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => const SplashScreen(),
        Routes.login: (_) => const LoginScreen(),
        Routes.home: (_) => const HomeScreen(),
        Routes.register: (_) => const RegisterScreen(),
        Routes.payScan: (_) => const ScanScreen(),
        Routes.payConfirm: (_) => const ConfirmPaymentScreen(),
        Routes.payResult: (_) => const PaymentResultScreen(),
      },
    );
  }
}
