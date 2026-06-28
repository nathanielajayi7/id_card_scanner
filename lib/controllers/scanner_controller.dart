import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import '../models/scan_document.dart';
import '../services/embedding_service.dart';
import '../services/face_extraction_service.dart';
import '../services/text_extraction_service.dart';
import '../services/barcode_extraction_service.dart';
import '../models/field_instruction.dart';

class ScannerController extends ChangeNotifier {
  ScanDocument? _scanResult;
  String? _errorMessage;
  bool _isScanning = false;
  final EmbeddingService _embeddingService = EmbeddingService();
  final FaceExtractionService _faceExtractionService = FaceExtractionService();
  final TextExtractionService _textExtractionService = TextExtractionService();
  final BarcodeExtractionService _barcodeExtractionService = BarcodeExtractionService();

  ScanDocument? get scanResult => _scanResult;
  String? get errorMessage => _errorMessage;
  bool get isScanning => _isScanning;

  Future<void> scanDocument() async {
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // getScanDocuments allows us to configure the page limit. We use 2 for front and back.
      ImageScanResult? scannedDocuments = await FlutterDocScanner()
          .getScannedDocumentAsImages(
            page: 1,
            quality: 1,
            useAutomaticSinglePictureProcessing: true,
          );

      if (scannedDocuments != null && scannedDocuments.images.isNotEmpty) {
        final doc = ScanDocument(rawData: scannedDocuments);

        // Extract features and compare with anchors
        var imagePath = doc.firstImagePath;
        if (imagePath != null) {
          // Slightly enhance image contrast and brightness before processing
          String imagePath2 = await _faceExtractionService.enhanceImage(imagePath, type: doc.detectedType);
          // doc.firstImagePath = imagePath;
          // throw Exception(imagePath);
          final type = await _embeddingService.classifyDocument(imagePath);
          doc.detectedType = type;
          // Attempt to extract face for KYC
          final faceExtractionResult = await _faceExtractionService.extractFace(
            imagePath,
          );
          if (faceExtractionResult != null) {
            doc.kycImagePath = faceExtractionResult.imagePath;
            doc.faceBoundingBox = faceExtractionResult.boundingBox;
            doc.faceMeshPoints = faceExtractionResult.meshPoints;
          }

          inspect(type);
          final instructions =
              instructionSet[DetectedType.values.firstWhere(
                (e) => e.name.toString() == type,
              )];
          if (instructions == null) {
            throw Exception("no instruction set for this card type");
          }

          final textExtractionResult = await _textExtractionService
              .extractAttributes(imagePath2, instructions);
          doc.extractedData = textExtractionResult.data;
          doc.textBoundingBoxes = textExtractionResult.boundingBoxes;

          // Extract barcodes
          final barcodeResult = await _barcodeExtractionService.extractBarcodes(imagePath);
          if (barcodeResult.barcodes.isNotEmpty) {
            doc.extractedBarcodes = barcodeResult.barcodes;
            doc.barcodeImgPath = barcodeResult.barcodeImgPath;
            doc.barcodeBoundingBox = barcodeResult.barcodeBoundingBox;
          }
        }

        _scanResult = doc;
      } else {
        _errorMessage = 'Unknown platform documents or cancelled';
      }
    } on PlatformException catch (e) {
      _errorMessage = 'Failed to get scanned documents: ${e.message}';
      _scanResult = null;
    } catch (e, s) {
      _errorMessage = 'Error processing document: $e';
      _scanResult = null;
      print(e);
      print(s);
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void reset() {
    _scanResult = null;
    _errorMessage = null;
    _isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _faceExtractionService.dispose();
    _textExtractionService.dispose();
    _barcodeExtractionService.dispose();
    super.dispose();
  }
}
