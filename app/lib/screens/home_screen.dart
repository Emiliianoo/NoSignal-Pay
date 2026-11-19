import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/error_messages.dart';
import '../core/money.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/app_icon.dart';

/// Greeting, balance card with Cobrar / Pagar / Recargar, and recent
/// movements. Follows Home.dc.html.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // load() notifies listeners; doing that while the first frame is being
    // built throws, so we wait until it is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
    });
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  // Temporary until the charge and top-up screens exist.
  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Disponible pronto')));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => context.read<WalletProvider>().load(),
          child: ListView(
            // Lets pull-to-refresh work even when the content is short.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenSide,
              AppSpacing.screenTop,
              AppSpacing.screenSide,
              32,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hola, ${user?.displayName ?? ''}',
                      style: text.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(10, 0), // margin-right: -10px
                    child: IconButton(
                      tooltip: 'Cerrar sesión',
                      onPressed: _logout,
                      iconSize: 24,
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      icon: const AppIcon(
                        AppIcons.logout,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _BalanceCard(
                onCharge: _comingSoon,
                onPay: () => Navigator.pushNamed(context, Routes.payScan),
                onTopUp: _comingSoon,
              ),
              const SizedBox(height: 32),
              Text('Últimos movimientos', style: text.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                // Until GET /transactions exists.
                child: Text(
                  'Aquí verás tus cobros, pagos y recargas.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark card: outer radius 28, padding 8, so the buttons inside use 20.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.onCharge,
    required this.onPay,
    required this.onTopUp,
  });

  final VoidCallback onCharge;
  final VoidCallback onPay;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _Balance(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: AppIcons.charge,
                  label: 'Cobrar',
                  onPressed: onCharge,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: AppIcons.pay,
                  label: 'Pagar',
                  onPressed: onPay,
                  isPrimary: true, // the only accent button on the screen
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: AppIcons.topUp,
                  label: 'Recargar',
                  onPressed: onTopUp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Saldo disponible" and the amount, or what to show while it loads or fails.
class _Balance extends StatelessWidget {
  const _Balance();

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final text = Theme.of(context).textTheme;
    final balance = wallet.balanceCents;
    final errorCode = wallet.errorCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saldo disponible',
          style: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.textOnDarkSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // "—" until the first balance arrives.
          balance == null ? '—' : formatCents(balance),
          style: text.displayMedium?.copyWith(color: Colors.white),
          semanticsLabel: balance == null ? 'Cargando saldo' : null,
        ),
        if (errorCode != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              errorMessage(errorCode),
              style: text.bodySmall?.copyWith(
                color: AppColors.textOnDarkSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.read<WalletProvider>().load(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final AppIcons icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? AppColors.accent : AppColors.inkRaised;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias, // keeps the ripple inside the corners
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
