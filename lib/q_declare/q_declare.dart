import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:q_officer_barantin/main.dart'; // Import main.dart untuk mengakses tema

class QDeclareScreen extends StatefulWidget {
  const QDeclareScreen({super.key});

  @override
  State<QDeclareScreen> createState() => _QDeclareScreenState();
}

class _QDeclareScreenState extends State<QDeclareScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanCompleted = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      });
    _animationController.forward();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanCompleted) {
      final List<Barcode> barcodes = capture.barcodes;
      if (barcodes.isNotEmpty) {
        controller.stop();
        setState(() {
          _isScanCompleted = true;
        });

        final String? qrData = barcodes.first.rawValue;
        debugPrint('QR Code terdeteksi: $qrData');

        // Navigasi dengan data dummy yang diterima
        Navigator.pushReplacementNamed(context, '/barang-bawaan',
            arguments: qrData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Q-Declare'),
        backgroundColor: MyApp.karantinaBrown, // Menggunakan warna tema
        actions: [
          IconButton(
            onPressed: () => controller.toggleTorch(),
            icon: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final bool isTorchOn = controller.torchEnabled;
                return Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellow : Colors.white,
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // Custom Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: MediaQuery.of(context).size.width * 0.75,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Animated border dan line
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.75,
              height: MediaQuery.of(context).size.width * 0.75,
              child: CustomPaint(
                painter: ScannerOverlayPainter(animationValue: _animation.value),
              ),
            ),
          ),

          // Teks Instruksi
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Arahkan kamera ke QR Code',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Custom Painter untuk overlay scanner
class ScannerOverlayPainter extends CustomPainter {
  final double animationValue;
  ScannerOverlayPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 30;
    const double padding = 0; // No padding, align with the cutout

    // Top-left corner
    canvas.drawLine(const Offset(padding, padding),
        const Offset(padding + cornerLength, padding), cornerPaint);
    canvas.drawLine(const Offset(padding, padding),
        const Offset(padding, padding + cornerLength), cornerPaint);

    // Top-right corner
    canvas.drawLine(Offset(size.width - padding, padding),
        Offset(size.width - padding - cornerLength, padding), cornerPaint);
    canvas.drawLine(Offset(size.width - padding, padding),
        Offset(size.width - padding, padding + cornerLength), cornerPaint);

    // Bottom-left corner
    canvas.drawLine(Offset(padding, size.height - padding),
        Offset(padding + cornerLength, size.height - padding), cornerPaint);
    canvas.drawLine(Offset(padding, size.height - padding),
        Offset(padding, size.height - padding - cornerLength), cornerPaint);

    // Bottom-right corner
    canvas.drawLine(Offset(size.width - padding, size.height - padding),
        Offset(size.width - padding - cornerLength, size.height - padding),
        cornerPaint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding),
        Offset(size.width - padding, size.height - padding - cornerLength),
        cornerPaint);

    // Animated Scan Line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final double lineY = size.height * animationValue;
    canvas.drawLine(
        Offset(padding + 10, lineY), Offset(size.width - 10, lineY), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}