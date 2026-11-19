import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/error_messages.dart';
import 'package:nosignal_pay/core/routes.dart';
import 'package:nosignal_pay/core/token_storage.dart';
import 'package:nosignal_pay/providers/auth_provider.dart';
import 'package:nosignal_pay/providers/wallet_provider.dart';
import 'package:nosignal_pay/screens/home_screen.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  late FakeApiClient api;

  // The balance loads right after the first frame, so the answer is set first.
  Future<void> pumpHome(WidgetTester tester, Object walletResult) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 't'});
    api = FakeApiClient()
      ..meResult = ana
      ..walletResult = walletResult;
    final wallet = WalletProvider(api: api);
    final auth = AuthProvider(
      api: api,
      tokenStorage: TokenStorage(),
      onSignedOut: wallet.clear,
    );
    await auth.restoreSession();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: wallet),
        ],
        child: MaterialApp(
          initialRoute: Routes.home,
          routes: {
            Routes.home: (_) => const HomeScreen(),
            Routes.login: (_) => const Text('login'),
          },
        ),
      ),
    );
  }

  testWidgets('greets the user and shows the balance', (tester) async {
    await pumpHome(tester, walletWith(163000));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text(r'$1,630.00'), findsOneWidget);
  });

  testWidgets('shows the error and a retry when the balance fails', (
    tester,
  ) async {
    await pumpHome(tester, apiError(null, 'network_error'));
    await tester.pumpAndSettle();

    expect(find.text(errorMessage('network_error')), findsOneWidget);

    api.walletResult = walletWith(5000);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text(r'$50.00'), findsOneWidget);
  });

  testWidgets('logout clears the balance and opens login', (tester) async {
    await pumpHome(tester, walletWith(163000));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    final wallet = Provider.of<WalletProvider>(
      tester.element(find.text('login')),
      listen: false,
    );
    expect(wallet.balanceCents, isNull);
  });
}
