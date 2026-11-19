import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/core/api_exception.dart';
import 'package:nosignal_pay/core/error_messages.dart';
import 'package:nosignal_pay/core/routes.dart';
import 'package:nosignal_pay/providers/payment_provider.dart';
import 'package:nosignal_pay/providers/wallet_provider.dart';
import 'package:nosignal_pay/screens/confirm_payment_screen.dart';
import 'package:nosignal_pay/screens/payment_result_screen.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

/// Confirm and result screens. The scan screen needs a real camera, so these
/// tests start with the charge already loaded, as after a successful scan.
void main() {
  late FakeApiClient api;
  late PaymentProvider payment;

  Future<void> pumpConfirm(WidgetTester tester) async {
    api = FakeApiClient()
      ..walletResult = walletWith(163000)
      ..paymentRequestResult = chargeWith();
    payment = PaymentProvider(api: api);
    final wallet = WalletProvider(api: api);
    await wallet.load();
    await payment.loadFromQr(qrText);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: payment),
          ChangeNotifierProvider.value(value: wallet),
        ],
        child: MaterialApp(
          initialRoute: Routes.home,
          routes: {
            Routes.home: (context) => TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.payConfirm),
              child: const Text('home'),
            ),
            Routes.payConfirm: (_) => const ConfirmPaymentScreen(),
            Routes.payResult: (_) => const PaymentResultScreen(),
          },
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirm shows the amount, the payee and what is left', (
    tester,
  ) async {
    await pumpConfirm(tester);

    expect(find.text(r'Paga $85.50 a Mariana Cruz'), findsOneWidget);
    expect(find.text('MC'), findsOneWidget);
    expect(find.text('Café y pan'), findsOneWidget);
    expect(find.text(r'$1,630.00'), findsOneWidget);
    expect(find.text(r'$1,544.50'), findsOneWidget);
    expect(find.text(r'Pagar $85.50'), findsOneWidget);
  });

  testWidgets('paying opens the success result', (tester) async {
    await pumpConfirm(tester);
    api.payResults.add(paidWith(balanceCents: 154450));

    await tester.tap(find.text(r'Pagar $85.50'));
    await tester.pumpAndSettle();

    expect(find.text(r'Le pagaste $85.50 a Mariana Cruz'), findsOneWidget);
    expect(find.text(r'$1,544.50'), findsOneWidget);

    api.walletResult = walletWith(154450);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(payment.status, PaymentStatus.idle);
  });

  testWidgets('no response opens the retry screen; retry uses the same key', (
    tester,
  ) async {
    await pumpConfirm(tester);
    api.payResults
      ..add(apiError(null, ApiException.networkError))
      ..add(paidWith());

    await tester.tap(find.text(r'Pagar $85.50'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos confirmar tu pago'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text(r'Le pagaste $85.50 a Mariana Cruz'), findsOneWidget);
    expect(api.payKeys[0], api.payKeys[1]);
  });

  testWidgets('a clear "no" stays on confirm with the message', (tester) async {
    await pumpConfirm(tester);
    api.payResults.add(apiError(422, 'insufficient_funds'));

    await tester.tap(find.text(r'Pagar $85.50'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmPaymentScreen), findsOneWidget);
    expect(find.text(errorMessage('insufficient_funds')), findsOneWidget);
  });

  test('initials take the first letter of up to two words', () {
    expect(initials('Mariana Cruz'), 'MC');
    expect(initials('ana'), 'A');
    expect(initials('  Luis  Alberto Méndez '), 'LA');
  });
}
