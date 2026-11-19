import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/error_messages.dart';
import 'package:nosignal_pay/core/routes.dart';
import 'package:nosignal_pay/core/token_storage.dart';
import 'package:nosignal_pay/models/user.dart';
import 'package:nosignal_pay/providers/auth_provider.dart';
import 'package:nosignal_pay/screens/register_screen.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  late FakeApiClient api;

  // Starts on a fake login screen with a button that opens register, so the
  // tests can also check going back.
  Future<void> pumpRegister(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    api = FakeApiClient();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(api: api, tokenStorage: TokenStorage()),
        child: MaterialApp(
          initialRoute: Routes.login,
          routes: {
            Routes.login: (context) => Consumer<AuthProvider>(
              builder: (context, auth, _) => Scaffold(
                body: Column(
                  children: [
                    Text('login error: ${auth.errorCode}'),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.register),
                      child: const Text('open register'),
                    ),
                  ],
                ),
              ),
            ),
            Routes.register: (_) => const RegisterScreen(),
            Routes.home: (_) => const Text('home'),
          },
        ),
      ),
    );
    await tester.tap(find.text('open register'));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '  Ana Torres  ');
    await tester.enterText(find.byType(TextField).at(1), 'ana@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret-123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
  }

  testWidgets('a successful register sends the trimmed name and opens home', (
    tester,
  ) async {
    await pumpRegister(tester);
    api.loginResult = AuthResult(accessToken: 't', expiresIn: 1, user: ana);

    await fillAndSubmit(tester);

    expect(api.registeredName, 'Ana Torres');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('shows the message for email_already_registered', (tester) async {
    await pumpRegister(tester);
    api.loginResult = apiError(409, 'email_already_registered');

    await fillAndSubmit(tester);

    expect(find.text(errorMessage('email_already_registered')), findsOneWidget);
  });

  testWidgets('going back clears the error so login does not show it', (
    tester,
  ) async {
    await pumpRegister(tester);
    api.loginResult = apiError(422, 'validation_error');
    await fillAndSubmit(tester);

    await tester.tap(find.byTooltip('Volver a iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('login error: null'), findsOneWidget);
  });
}
