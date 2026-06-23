import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:id_card_scanner/id_card_scanner.dart';
import 'package:id_card_scanner/services/face_extraction_service.dart';
import 'package:id_card_scanner/services/text_extraction_service.dart';
import 'package:id_card_scanner/models/field_instruction.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _testFaceExtraction(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final byteData = await rootBundle.load('assets/nin_slip.png');
      final tempFile = File('${Directory.systemTemp.path}/nin_slip_test.png');
      await tempFile.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      final faceService = FaceExtractionService();
      final textService = TextExtractionService();

      final kycPath = await faceService.extractFace(tempFile.path);

      final mockInstructions =
          instructionSet[DetectedType.nin_slip];
      if (mockInstructions == null) {
        throw Exception("no instruction set for this card type");
      }
      final extractedData = await textService.extractAttributes(
        tempFile.path,
        mockInstructions,
      );

      faceService.dispose();
      textService.dispose();

      if (context.mounted) {
        Navigator.pop(context); // remove loading

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Extraction Result'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kycPath != null) Image.file(File(kycPath), height: 100),
                const SizedBox(height: 16),
                const Text(
                  'Extracted Fields:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...extractedData.entries.map(
                  (e) => Text('${e.key}: ${e.value}'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Card Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.document_scanner,
                size: 100,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to ID Scanner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Easily capture and process your identity documents.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScannerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Get Started'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _testFaceExtraction(context),
                icon: const Icon(Icons.face),
                label: const Text('Test Face Extraction'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
