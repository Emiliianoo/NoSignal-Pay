import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/error_messages.dart';
import 'package:nosignal_pay/core/routes.dart';
import 'package:nosignal_pay/core/token_storage.dart';
import 'package:nosignal_pay/models/user.dart';
import 'package:nosignal_pay/providers/auth_provider.dart';
import 'package:nosignal_pay/screens/login_screen.dart';
import 'package:nosignal_pay/widgets/primary_button.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  late FakeApiClient api;

  // The app without the Google Fonts theme (tests have no network).
  Future<void> pumpLogin(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    api = FakeApiClient();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(api: api, tokenStorage: TokenStorage()),
        child: MaterialApp(
          initialRoute: Routes.login,
          routes: {
            Routes.login: (_) => const LoginScreen(),
            Routes.home: (_) => const Text('home'),
          },
        ),
      ),
    );
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret-123');
    await tester.tap(find.text('Entrar'));
  }

  testWidgets('shows the Spanish message for invalid_credentials', (
    tester,
  ) async {
    await pumpLogin(tester);
    api.loginResult = apiError(401, 'invalid_credentials');

    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text(errorMessage('invalid_credentials')), findsOneWidget);
  });

  testWidgets('the error disappears when a field changes', (tester) async {
    await pumpLogin(tester);
    api.loginResult = apiError(null, 'network_error');
    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'other');
    await tester.pump();

    expect(find.text(errorMessage('network_error')), findsNothing);
  });

  testWidgets('the button is disabled while the request is on its way', (
    tester,
  ) async {
    await pumpLogin(tester);
    api.gate = Completer<void>();
    api.loginResult = AuthResult(accessToken: 't', expiresIn: 1, user: ana);

    await fillAndSubmit(tester);
    await tester.pump();

    final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(button.isLoading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    api.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a successful login opens home', (tester) async {
    await pumpLogin(tester);
    api.loginResult = AuthResult(accessToken: 't', expiresIn: 1, user: ana);

    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
