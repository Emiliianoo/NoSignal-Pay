import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/core/routes.dart';
import 'package:nosignal_pay/core/token_storage.dart';
import 'package:nosignal_pay/providers/auth_provider.dart';
import 'package:nosignal_pay/screens/splash_screen.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  Future<void> pumpSplash(
    WidgetTester tester, {
    String? savedToken,
    Object? meResult,
  }) async {
    FlutterSecureStorage.setMockInitialValues(
      savedToken == null ? {} : {'access_token': savedToken},
    );
    final api = FakeApiClient()..meResult = meResult;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(api: api, tokenStorage: TokenStorage()),
        child: MaterialApp(
          initialRoute: Routes.splash,
          routes: {
            Routes.splash: (_) => const SplashScreen(),
            Routes.login: (_) => const Text('login'),
            Routes.home: (_) => const Text('home'),
          },
        ),
      ),
    );
  }

  testWidgets('shows the loading message first', (tester) async {
    await pumpSplash(tester);

    expect(find.text('Abriendo tu billetera'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('no saved token opens login', (tester) async {
    await pumpSplash(tester);
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('a valid saved token opens home', (tester) async {
    await pumpSplash(tester, savedToken: 't', meResult: ana);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an expired token opens login', (tester) async {
    await pumpSplash(
      tester,
      savedToken: 'old',
      meResult: apiError(401, 'token_expired'),
    );
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('no network opens login', (tester) async {
    await pumpSplash(
      tester,
      savedToken: 't',
      meResult: apiError(null, ApiException.networkError),
    );
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
  });
}
