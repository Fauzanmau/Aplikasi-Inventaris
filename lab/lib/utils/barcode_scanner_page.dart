import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:auto_size_text/auto_size_text.dart';   // ← Ditambahkan

const primaryPurple = Color(0xFFA020F0);
const softPurple = Color(0xFFF3E8FF);

enum ScanMode { barcode, qr }

class BarcodeScannerPage extends StatefulWidget {
  final Function(String) onDetect;
  const BarcodeScannerPage({
    super.key,
    required this.onDetect,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _controller;
  late final AudioPlayer _player;
  late final AnimationController _animationController;
  bool _scanned = false;
  bool _torchOn = false;
  ScanMode _scanMode = ScanMode.barcode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 800,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.qrCode,
      ],
    );
    _player = AudioPlayer();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start().catchError((e) {
          debugPrint("Gagal start scanner saat resume: $e");
        });
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller.stop().catchError((e) {
          debugPrint("Gagal stop scanner: $e");
        });
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _beep() async {
    try {
      HapticFeedback.mediumImpact();
      await _player.stop();
      await _player.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  Rect _scanWindow(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height * 0.33);
    if (_scanMode == ScanMode.qr) {
      return Rect.fromCenter(
        center: center,
        width: size.width * 0.65,
        height: size.width * 0.65,
      );
    } else {
      return Rect.fromCenter(
        center: center,
        width: size.width * 0.9,
        height: 200,
      );
    }
  }

  String _getScanHintText() {
    return _scanMode == ScanMode.barcode
        ? "Arahkan kamera ke barcode"
        : "Arahkan kamera ke QR Code";
  }

  void _handleDetection(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode.isNotEmpty) {
      setState(() => _scanned = true);
      await _controller.stop();
      await _beep();
      widget.onDetect(barcode);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanRect = _scanWindow(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        title: AutoSizeText(
          'Scan Serial Number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          minFontSize: 17,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                try {
                  await _controller.toggleTorch();
                  if (mounted) {
                    setState(() => _torchOn = !_torchOn);
                  }
                } catch (e) {
                  debugPrint("Torch toggle error: $e");
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: _torchOn ? Colors.white : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _torchOn ? Icons.flash_on : Icons.flash_off,
                  color: _torchOn ? primaryPurple : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            scanWindow: scanRect,
            fit: BoxFit.cover,
            onDetect: _handleDetection,
          ),
          // Overlay + animasi scan line
          AnimatedBuilder(
            animation: _animationController,
            builder: (_, __) {
              return CustomPaint(
                painter: ScannerOverlay(
                  scanWindow: scanRect,
                  animationValue: _animationController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Petunjuk teks — dipindah ke atas scan window
          Positioned(
            top: 100, // sesuaikan jarak dari atas (bisa diubah)
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _getScanHintText(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Switch mode Barcode / QR (di bawah)
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _modeChip("Barcode", ScanMode.barcode),
                const SizedBox(width: 12),
                _modeChip("QR Code", ScanMode.qr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String text, ScanMode mode) {
    final selected = _scanMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _scanMode = mode;
          _scanned = false; // reset status scanned saat ganti mode
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFB15EFF), Color(0xFF8E2DE2)],
                )
              : null,
          // ignore: deprecated_member_use
          color: selected ? null : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white70,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  final Rect scanWindow;
  final double animationValue;
  ScannerOverlay({
    required this.scanWindow,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ignore: deprecated_member_use
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    final background = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addRRect(RRect.fromRectXY(scanWindow, 20, 20));
    final overlay = Path.combine(PathOperation.difference, background, cutout);
    canvas.drawPath(overlay, overlayPaint);

    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB15EFF), Color(0xFF8E2DE2)],
      ).createShader(scanWindow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectXY(scanWindow, 20, 20),
      borderPaint,
    );

    final lineY = scanWindow.top + (scanWindow.height * animationValue);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          // ignore: deprecated_member_use
          primaryPurple.withOpacity(0.1),
          primaryPurple,
          // ignore: deprecated_member_use
          primaryPurple.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(
        scanWindow.left,
        lineY - 2,
        scanWindow.width,
        4,
      ));
    canvas.drawRect(
      Rect.fromLTWH(
        scanWindow.left,
        lineY - 2,
        scanWindow.width,
        4,
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlay oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.scanWindow != scanWindow;
}