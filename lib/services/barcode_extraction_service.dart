import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

class BarcodeExtractionResult {
  final List<String> barcodes;
  final String? barcodeImgPath;
  final Rect? barcodeBoundingBox;

  BarcodeExtractionResult({
    required this.barcodes,
    this.barcodeImgPath,
    this.barcodeBoundingBox,
  });
}

class BarcodeExtractionService {
  final BarcodeScanner _barcodeScanner;

  BarcodeExtractionService()
      : _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);

  Future<BarcodeExtractionResult> extractBarcodes(String imagePath, {double paddingFactor = 0.1}) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Barcode> detectedBarcodes = await _barcodeScanner.processImage(inputImage);

    final validBarcodes = detectedBarcodes
        .where((barcode) => barcode.rawValue != null)
        .toList();

    if (validBarcodes.isEmpty) {
      print("no bar codes");
      return BarcodeExtractionResult(barcodes: []);
    }

    final rawValues = validBarcodes.map((b) => b.rawValue!).toList();
    
    // Attempt to crop the first valid barcode image
    final targetBarcode = validBarcodes.first;
    final targetBoundingBox = targetBarcode.boundingBox;
    
    String? croppedBarcodePath;

    final fileBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(fileBytes);

    if (originalImage != null) {
        // Calculate padding
        final paddingX = targetBoundingBox.width * paddingFactor;
        final paddingY = targetBoundingBox.height * paddingFactor;

        int cropX = (targetBoundingBox.left - paddingX).toInt();
        int cropY = (targetBoundingBox.top - paddingY).toInt();
        int cropWidth = (targetBoundingBox.width + 2 * paddingX).toInt();
        int cropHeight = (targetBoundingBox.height + 2 * paddingY).toInt();

        // Ensure crop bounds are within the image dimensions
        cropX = max(0, cropX);
        cropY = max(0, cropY);
        if (cropX + cropWidth > originalImage.width) {
          cropWidth = originalImage.width - cropX;
        }
        if (cropY + cropHeight > originalImage.height) {
          cropHeight = originalImage.height - cropY;
        }

        // Crop the image
        final croppedImage = img.copyCrop(
          originalImage,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        );

        // Save to temp directory
        final tempDir = Directory.systemTemp;
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        croppedBarcodePath = '${tempDir.path}/barcode_$timestamp.jpg';

        final croppedBytes = img.encodeJpg(croppedImage);
        final barcodeFile = File(croppedBarcodePath);
        await barcodeFile.writeAsBytes(croppedBytes);
      }

    return BarcodeExtractionResult(
      barcodes: rawValues,
      barcodeImgPath: croppedBarcodePath,
      barcodeBoundingBox: targetBoundingBox,
    );
  }

  void dispose() {
    _barcodeScanner.close();
  }
}
