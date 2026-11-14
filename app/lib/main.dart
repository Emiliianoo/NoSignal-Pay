import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'core/token_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';

/// Set with `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`.
/// The default works on the iPhone simulator; see CLAUDE.md for the others.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

void main() {
  final tokenStorage = TokenStorage();
  final api = ApiClient(baseUrl: apiBaseUrl, readToken: tokenStorage.read);
  final wallet = WalletProvider(api: api);
  final auth = AuthProvider(
    api: api,
    tokenStorage: tokenStorage,
    onSignedOut: wallet.clear, // the next user must not see this balance
  );

  runApp(
    // Every provider is created here, above MaterialApp, so all screens can
    // reach them with context.watch / context.read. They are created first
    // (not inside create:) because AuthProvider needs to clear the others.
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: wallet),
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
      },
    );
  }
}
