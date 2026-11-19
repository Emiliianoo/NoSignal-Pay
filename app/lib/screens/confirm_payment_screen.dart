import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/error_messages.dart';
import '../core/money.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/payment_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/app_icon.dart';
import '../widgets/detail_card.dart';
import '../widgets/primary_button.dart';

/// "Paga $85.50 a Mariana Cruz": what the server says about the charge, and
/// the pay button. Follows Confirm.dc.html.
class ConfirmPaymentScreen extends StatelessWidget {
  const ConfirmPaymentScreen({super.key});

  /// Initials box colors from the design; only used here.
  static const _initialsBackground = Color(0xFFD5EDE0);

  Future<void> _pay(BuildContext context) async {
    final payment = context.read<PaymentProvider>();
    await payment.confirm();
    if (!context.mounted) return;
    final code = payment.errorCode;
    final noResponse =
        code == ApiException.networkError || code == ApiException.timeout;
    // Success, or no answer (we don't know if it went through): result screen.
    // A clear "no" from the server (no funds, already paid...) stays here.
    if (payment.status == PaymentStatus.success || noResponse) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.payResult,
        ModalRoute.withName(Routes.home),
      );
    }
  }

  void _cancel(BuildContext context) {
    Navigator.popUntil(context, ModalRoute.withName(Routes.home));
    context.read<PaymentProvider>().clear();
  }

  @override
  Widget build(BuildContext context) {
    final payment = context.watch<PaymentProvider>();
    final balance = context.watch<WalletProvider>().balanceCents;
    final text = Theme.of(context).textTheme;
    final request = payment.request;
    // The flow was cleared while this screen is closing.
    if (request == null) return const Scaffold();

    final amount = formatCents(request.amountCents);
    final isPaying = payment.status == PaymentStatus.paying;
    final errorCode = payment.status == PaymentStatus.error
        ? payment.errorCode
        : null;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 56 - 32,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: const Offset(-10, 0),
                        child: IconButton(
                          tooltip: 'Volver a escanear',
                          onPressed: isPaying
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
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _initialsBackground,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            initials(request.payeeName),
                            style: text.headlineSmall?.copyWith(
                              fontSize: 22,
                              color: AppColors.accentPressed,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Paga $amount a ${request.payeeName}',
                      style: text.headlineLarge,
                    ),
                    const SizedBox(height: 32),
                    DetailCard(
                      rows: [
                        if (request.description case final description?)
                          DetailRow('Concepto', description),
                        if (balance != null) ...[
                          DetailRow('Tu saldo', formatCents(balance)),
                          DetailRow(
                            'Te quedarán',
                            formatCents(balance - request.amountCents),
                            emphasize: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Revisa el nombre antes de pagar. '
                        'Un pago enviado no se puede deshacer.',
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    if (errorCode != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          errorMessage(errorCode),
                          style: text.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      label: 'Pagar $amount',
                      isLoading: isPaying,
                      // After a clear "no" from the server, paying again
                      // would give the same answer.
                      onPressed: errorCode == null ? () => _pay(context) : null,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: isPaying ? null : () => _cancel(context),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mariana Cruz" -> "MC"; "ana" -> "A".
String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}
