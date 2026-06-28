import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:id_card_scanner/id_card_scanner.dart';
import 'package:id_card_scanner/services/barcode_extraction_service.dart';
import 'package:id_card_scanner/services/face_extraction_service.dart';
import 'package:id_card_scanner/services/text_extraction_service.dart';
import 'package:id_card_scanner/models/field_instruction.dart';
import 'package:id_card_scanner/models/scan_document.dart';
import 'package:id_card_scanner/views/explore_result_page.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image/image.dart' as img;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _testFaceExtraction(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final byteData = await rootBundle.load('assets/verified_nin.png');

      // final originalImage = 

      final tempFile = await enhanceImage(byteData);
      // await tempFile.writeAsBytes(
      //   highContrast.buffer.asUint8List(
      //     byteData.offsetInBytes,
      //     byteData.lengthInBytes,
      //   ),
      // );

      final faceService = FaceExtractionService();
      final textService = TextExtractionService();
      final barCodeService = BarcodeExtractionService();

      final faceResult = await faceService.extractFace(tempFile);
      final kycPath = faceResult?.imagePath;

      final mockInstructions =
          instructionSet[DetectedType.verified_nin];
      if (mockInstructions == null) {
        throw Exception("no instruction set for this card type");
      }
      final extractionResult = await textService.extractAttributes(
        tempFile,
        mockInstructions,
      );

      final barcodeResult = await barCodeService.extractBarcodes(
        tempFile
      );

      inspect(barcodeResult);


      final extractedData = extractionResult.data;
      

      faceService.dispose();
      textService.dispose();
      barCodeService.dispose();

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
                if (barcodeResult.barcodeImgPath != null) ...[
                  const SizedBox(height: 16),
                  Image.file(File(barcodeResult.barcodeImgPath!), height: 80),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Extracted Fields:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...extractedData.entries.map(
                  (e) => Text('${e.key}: ${e.value}'),
                ),
                if (barcodeResult.barcodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Extracted Barcodes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...barcodeResult.barcodes.map(
                    (b) => Text(b),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  final scanDoc = ScanDocument(
                    rawData: ImageScanResult(images: [Uri.file(tempFile).toString()]),
                    kycImagePath: kycPath,
                    extractedData: extractedData,
                    textBoundingBoxes: extractionResult.boundingBoxes,
                    faceBoundingBox: faceResult?.boundingBox,
                    faceMeshPoints: faceResult?.meshPoints,
                    extractedBarcodes: barcodeResult.barcodes,
                    barcodeImgPath: barcodeResult.barcodeImgPath,
                    barcodeBoundingBox: barcodeResult.barcodeBoundingBox,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExploreResultPage(scanResult: scanDoc),
                    ),
                  );
                },
                child: const Text('Explore Result'),
              ),
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

/// Slightly enhances the contrast and brightness of the given image.
  /// Returns the path to the newly saved enhanced image.
  Future<String> enhanceImage(ByteData image) async {
    final fileBytes = image;
    final originalImage = img.decodeImage(fileBytes.buffer.asUint8List());

    if (originalImage == null) return '';

    // Apply slight contrast (e.g., 1.2 = 120%) and brightness adjustments
    final enhancedImage = img.adjustColor(
      originalImage,
      contrast: 1.2,
      brightness: 1.1,
    );

    // img.Image grayscale = img.grayscale(enhancedImage); .

    // 2. Boost the contrast sharply to make faint text solid black
    // img.Image highContrast = img;

    // Save to temp directory
    final tempDir = Directory.systemTemp;
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String enhancedImagePath = '${tempDir.path}/enhanced_$timestamp.jpg';

    final enhancedBytes = img.encodeJpg(enhancedImage);
    final enhancedFile = File(enhancedImagePath);
    await enhancedFile.writeAsBytes(enhancedBytes);

    return enhancedImagePath;
  }
