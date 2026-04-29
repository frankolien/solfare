import 'package:flutter/material.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _hasScanned = false;

  void _onCapture(Result result) {
    if (_hasScanned) return;
    var value = result.text;
    if (value.isEmpty) return;

    // Handle solana: URI scheme — strip prefix and any query params.
    if (value.startsWith('solana:')) {
      value = value.substring(7).split('?').first;
    }

    // Basic Solana address validation (32-44 chars, base58 length range).
    if (value.length >= 32 && value.length <= 44) {
      _hasScanned = true;
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera + decoder. Pure-Dart ZXing under the hood, so it runs on
          // arm64 simulators (mobile_scanner's MLKit dependency does not).
          QRCodeDartScanView(
            typeScan: TypeScan.live,
            formats: const [BarcodeFormat.qrCode],
            onCapture: _onCapture,
          ),

          // Overlay
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Scan frame
                Expanded(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),

                // Cancel button
                Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2D35),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
