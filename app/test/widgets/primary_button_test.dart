import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosignal_pay/widgets/primary_button.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('calls onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(PrimaryButton(label: 'Entrar', onPressed: () => taps++)),
    );

    await tester.tap(find.text('Entrar'));

    expect(taps, 1);
  });

  testWidgets('is disabled and shows a spinner while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        PrimaryButton(
          label: 'Entrar',
          onPressed: () => taps++,
          isLoading: true,
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));

    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
  });
}
