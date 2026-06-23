import 'package:flutter/material.dart';
import '../controllers/scanner_controller.dart';
import 'result_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final ScannerController _controller = ScannerController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (_controller.scanResult != null && !_controller.isScanning) {
      // Navigate to result page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(scanResult: _controller.scanResult!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              if (_controller.isScanning) {
                return const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Scanning in progress...'),
                  ],
                );
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.credit_card,
                    size: 100,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Capture ID Card',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _controller.scanDocument,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan Card'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
