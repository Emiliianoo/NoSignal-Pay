import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../providers/payment_provider.dart';
import '../widgets/app_icon.dart';
import '../widgets/primary_button.dart';

/// "Apunta al código de quien te cobra": camera plus a field to paste the code
/// (simulators have no camera). Follows Scan.dc.html.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _code = TextEditingController();
  final _scanner = MobileScannerController(formats: [BarcodeFormat.qrCode]);

  /// mobile_scanner reports the same QR many times per second. Only the first
  /// reading is processed; otherwise several confirm screens would open.
  bool _handlingCode = false;

  @override
  void dispose() {
    _code.dispose();
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _handlingCode) return;
    _submit(raw);
  }

  Future<void> _submit(String raw) async {
    if (_handlingCode) return;
    _handlingCode = true;
    FocusScope.of(context).unfocus();

    final ok = await context.read<PaymentProvider>().loadFromQr(raw);
    if (!mounted) return;
    if (ok) {
      // Pause the camera while confirming; it resumes when the user comes back.
      await _scanner.stop();
      if (!mounted) return;
      await Navigator.pushNamed(context, Routes.payConfirm);
      if (!mounted) return;
      await _scanner.start();
    }
    // Back here (error, or the user came back from confirm): read again.
    _handlingCode = false;
  }

  void _leave() {
    // Leaving the flow: forget the charge and its idempotency key.
    context.read<PaymentProvider>().clear();
  }

  @override
  Widget build(BuildContext context) {
    final payment = context.watch<PaymentProvider>();
    final text = Theme.of(context).textTheme;
    final errorCode = payment.errorCode;
    final isLoading = payment.status == PaymentStatus.loadingPreview;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          body: SafeArea(
            bottom: false, // the white sheet reaches the bottom edge
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(-10, 0),
                        child: IconButton(
                          tooltip: 'Volver al inicio',
                          onPressed: () => Navigator.maybePop(context),
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          icon: const AppIcon(
                            AppIcons.back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Apunta al código de quien te cobra',
                        style: text.headlineMedium?.copyWith(
                          fontSize: 26,
                          height: 32 / 26,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _CameraView(
                      controller: _scanner,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sheet),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '¿No puedes escanear? Pega el código',
                        style: text.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _code,
                        enabled: !isLoading,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (errorCode != null) {
                            context.read<PaymentProvider>().clear();
                          }
                        },
                        onSubmitted: _submit,
                        // Monospace only for the NSP:1:REQ:... code.
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          height: 20 / 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'NSP:1:REQ:…',
                        ),
                      ),
                      if (errorCode != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            errorMessage(errorCode),
                            style: text.labelLarge,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Continuar',
                        isLoading: isLoading,
                        onPressed: () => _submit(_code.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera inside a rounded box, with the 220 frame and the moving line.
class _CameraView extends StatelessWidget {
  const _CameraView({required this.controller, required this.onDetect});

  /// Background while the camera starts, or when there is none (simulator).
  static const _cameraBackground = Color(0xFF1A2029);

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vista de la cámara con el marco de lectura',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        child: ColoredBox(
          color: _cameraBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: controller,
                onDetect: onDetect,
                // No camera or no permission: keep the dark box; the paste
                // field below still works.
                errorBuilder: (context, error) => const SizedBox.shrink(),
              ),
              const Center(child: _ScanFrame()),
            ],
          ),
        ),
      ),
    );
  }
}

/// White corners (220x220) and the green line that moves up and down.
class _ScanFrame extends StatefulWidget {
  const _ScanFrame();

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  // AnimationController drives a value from 0 to 1 over 1.8 s; repeat(reverse)
  // makes it go back and forth. It must be disposed like a text controller.
  late final _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the line stays still at the top.
    if (MediaQuery.disableAnimationsOf(context)) {
      _line.stop();
    } else if (!_line.isAnimating) {
      _line.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 220,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _CornersPainter())),
          AnimatedBuilder(
            animation: _line,
            builder: (context, child) => Positioned(
              left: 16,
              right: 16,
              // From 8 to 212 (8 + 204), easing in and out as in the design.
              top: 8 + 204 * Curves.easeInOut.transform(_line.value),
              child: child!,
            ),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.scanLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four rounded corners of the frame (path from Scan.dc.html).
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const r = Radius.circular(20);
    final path = Path()
      // top left
      ..moveTo(2, 46)
      ..lineTo(2, 22)
      ..arcToPoint(const Offset(22, 2), radius: r)
      ..lineTo(46, 2)
      // top right
      ..moveTo(174, 2)
      ..lineTo(198, 2)
      ..arcToPoint(const Offset(218, 22), radius: r)
      ..lineTo(218, 46)
      // bottom right
      ..moveTo(218, 174)
      ..lineTo(218, 198)
      ..arcToPoint(const Offset(198, 218), radius: r)
      ..lineTo(174, 218)
      // bottom left
      ..moveTo(46, 218)
      ..lineTo(22, 218)
      ..arcToPoint(const Offset(2, 198), radius: r)
      ..lineTo(2, 174);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
