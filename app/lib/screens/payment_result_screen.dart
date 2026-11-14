import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/error_messages.dart';
import '../core/money.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/payment_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/app_icon.dart';
import '../widgets/detail_card.dart';
import '../widgets/primary_button.dart';

/// "Le pagaste $X a {nombre}", or "No pudimos confirmar tu pago" with a safe
/// retry. Follows Result.dc.html.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({super.key});

  void _goHome(BuildContext context) {
    // The balance changed (or may have): ask the server again.
    context.read<WalletProvider>().load();
    Navigator.popUntil(context, ModalRoute.withName(Routes.home));
    context.read<PaymentProvider>().clear();
  }

  @override
  Widget build(BuildContext context) {
    final payment = context.watch<PaymentProvider>();

    final Widget body = switch (payment.status) {
      PaymentStatus.success => _Paid(onDone: () => _goHome(context)),
      PaymentStatus.paying ||
      PaymentStatus.error => _NotConfirmed(onHome: () => _goHome(context)),
      // The flow was cleared while this screen is closing.
      _ => const SizedBox.shrink(),
    };

    return PopScope(
      // System back behaves like "Listo" / "Volver al inicio".
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 132, 24, 32),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Paid extends StatelessWidget {
  const _Paid({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final payment = context.read<PaymentProvider>();
    final result = payment.result!;
    final transaction = result.transaction;
    final text = Theme.of(context).textTheme;
    final name = transaction.counterpartyName ?? payment.request?.payeeName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: _PopIn(child: _Circle(color: AppColors.accent, done: true)),
        ),
        const SizedBox(height: 32),
        _RiseIn(
          delay: const Duration(milliseconds: 150),
          child: Semantics(
            liveRegion: true,
            child: Text(
              'Le pagaste ${formatCents(transaction.amountCents)} a $name',
              style: text.headlineLarge,
            ),
          ),
        ),
        const SizedBox(height: 32),
        _RiseIn(
          delay: const Duration(milliseconds: 250),
          child: DetailCard(
            rows: [
              if (transaction.description case final description?)
                DetailRow('Concepto', description),
              DetailRow('Fecha', formatDateTime(transaction.createdAt)),
              DetailRow(
                'Tu saldo',
                formatCents(result.balanceCents),
                emphasize: true,
              ),
            ],
          ),
        ),
        const Spacer(),
        PrimaryButton(label: 'Listo', onPressed: onDone),
      ],
    );
  }
}

class _NotConfirmed extends StatelessWidget {
  const _NotConfirmed({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final payment = context.watch<PaymentProvider>();
    final text = Theme.of(context).textTheme;
    final isPaying = payment.status == PaymentStatus.paying;
    // A retry may come back with a clear "no" (for example, no funds left).
    final finalError = !isPaying && !payment.canRetry
        ? payment.errorCode
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: _Circle(color: AppColors.ink, done: false),
        ),
        const SizedBox(height: 32),
        Semantics(
          liveRegion: true,
          child: Text(
            finalError == null
                ? 'No pudimos confirmar tu pago'
                : 'No se hizo el pago',
            style: text.headlineLarge,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          finalError == null
              ? 'Se perdió la conexión antes de recibir respuesta. '
                    'Reintentar es seguro: no se te cobrará dos veces.'
              : errorMessage(finalError),
          style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        if (finalError == null) ...[
          PrimaryButton(
            label: 'Reintentar',
            isLoading: isPaying,
            // Same idempotency key as the first attempt.
            onPressed: () => context.read<PaymentProvider>().confirm(),
          ),
          const SizedBox(height: 4),
        ],
        TextButton(
          onPressed: isPaying ? null : onHome,
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}

/// 88 circle: accent with a check (paid) or ink with no-signal (unknown).
class _Circle extends StatelessWidget {
  const _Circle({required this.color, required this.done});

  final Color color;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: done
          ? const AppIcon(
              AppIcons.done,
              size: 44,
              color: Colors.white,
              strokeWidth: 2.25,
            )
          : const AppIcon(AppIcons.noSignal, size: 44, color: Colors.white),
    );
  }
}

/// Scales in from 0.5 with a slight bounce (0.4 s). Off with reduced motion.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Opacity(
        opacity: ((scale - 0.5) * 2).clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: child,
    );
  }
}

/// Fades in while rising 12 px (0.35 s, after [delay]). Off with reduced motion.
class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
