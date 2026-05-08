import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../models/link_activation.dart';
import 'connection_success_screen.dart';
import 'invalid_link_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner le QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_isProcessing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  setState(() => _isProcessing = true);
                  _handleScannedLink(code);
                  break;
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  void _handleScannedLink(String link) async {
    final authService = AuthService();
    final result = await authService.activateDevice(link);

    if (!mounted) return;

    if (result.status == LinkStatus.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ConnectionSuccessScreen(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InvalidLinkScreen(status: result.status),
        ),
      );
    }
  }
}
