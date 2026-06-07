import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sports_venue_chatbot/core/constants/app_colors.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/booking/data/booking_api.dart';
import 'package:sports_venue_chatbot/features/booking/presentation/booking_provider.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/shared/widgets/app_snackbar.dart';

class BookingQrScanScreen extends ConsumerStatefulWidget {
  const BookingQrScanScreen({super.key});

  @override
  ConsumerState<BookingQrScanScreen> createState() =>
      _BookingQrScanScreenState();
}

class _BookingQrScanScreenState extends ConsumerState<BookingQrScanScreen> {
  late final MobileScannerController _controller;
  bool _isHandling = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isHandling) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    final parsed = _parseCheckInPayload(raw);
    if (parsed == null) {
      _showError('Mã QR không phải mã nhận sân của hệ thống.');
      return;
    }

    setState(() => _isHandling = true);
    await _controller.stop();

    try {
      final booking = await ref.read(bookingApiProvider).confirmCheckIn(
            bookingId: parsed.bookingId,
            token: parsed.token,
          );
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        await ref.read(bookingProvider.notifier).loadBookings(user.id);
      }
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Đã xác nhận nhận sân ${booking.resourceLabel ?? ''}'.trim(),
      );
      context.go('/billing');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
      await _restartScanner();
    } catch (_) {
      if (!mounted) return;
      _showError('Không thể xác nhận nhận sân. Vui lòng thử lại.');
      await _restartScanner();
    }
  }

  Future<void> _restartScanner() async {
    if (!mounted) return;
    setState(() => _isHandling = false);
    await _controller.start();
  }

  void _showError(String message) {
    if (!mounted) return;
    AppSnackBar.showError(context, message);
  }

  _CheckInPayload? _parseCheckInPayload(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    final isCustomScheme = uri.scheme == 'sportsvenue' &&
        (uri.host == 'booking-checkin' || uri.path.contains('booking-checkin'));
    final isWebPath = (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.path.contains('booking-checkin');
    if (!isCustomScheme && !isWebPath) return null;

    final bookingId = uri.queryParameters['booking_id'];
    final token = uri.queryParameters['token'];
    if (bookingId == null ||
        bookingId.isEmpty ||
        token == null ||
        token.isEmpty) {
      return null;
    }
    return _CheckInPayload(bookingId: bookingId, token: token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Quét QR nhận sân'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Bật/tắt đèn',
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Đổi camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          IgnorePointer(
            child: Container(
              decoration: ShapeDecoration(
                shape: _ScannerOverlayBorder(
                  borderColor: AppColors.primary,
                  overlayColor: Colors.black.withValues(alpha: 0.55),
                  borderRadius: 18,
                  borderLength: 38,
                  borderWidth: 4,
                  cutOutSize: 260,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isHandling
                      ? 'Đang xác nhận...'
                      : 'Đưa mã QR nhận sân của nhân viên vào khung quét.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInPayload {
  final String bookingId;
  final String token;

  const _CheckInPayload({
    required this.bookingId,
    required this.token,
  });
}

class _ScannerOverlayBorder extends ShapeBorder {
  final Color borderColor;
  final Color overlayColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const _ScannerOverlayBorder({
    required this.borderColor,
    required this.overlayColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.borderLength,
    required this.cutOutSize,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final cutOut = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(cutOut, Radius.circular(borderRadius)),
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(getOuterPath(rect), overlayPaint);

    final cutOut = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;
    final radius = Radius.circular(borderRadius);
    final rrect = RRect.fromRectAndRadius(cutOut, radius);
    canvas.drawRRect(rrect, paint);
  }

  @override
  ShapeBorder scale(double t) => _ScannerOverlayBorder(
        borderColor: borderColor,
        overlayColor: overlayColor,
        borderWidth: borderWidth * t,
        borderRadius: borderRadius * t,
        borderLength: borderLength * t,
        cutOutSize: cutOutSize * t,
      );
}
