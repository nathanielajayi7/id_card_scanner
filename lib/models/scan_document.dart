import 'dart:ui';
import 'package:flutter_doc_scanner/flutter_doc_scanner_models.dart';

class ScanDocument {
  final ImageScanResult rawData;
  String? detectedType;
  String? kycImagePath;
  Map<String, String>? extractedData;
  
  // New overlay fields
  Map<String, Rect>? textBoundingBoxes;
  List<Offset>? faceMeshPoints;
  Rect? faceBoundingBox;
  List<String>? extractedBarcodes;
  String? barcodeImgPath;
  Rect? barcodeBoundingBox;

  ScanDocument({
    required this.rawData,
    this.detectedType,
    this.kycImagePath,
    this.extractedData,
    this.textBoundingBoxes,
    this.faceMeshPoints,
    this.faceBoundingBox,
    this.extractedBarcodes,
    this.barcodeImgPath,
    this.barcodeBoundingBox,
  });

  // Helper to extract the first image path from typical flutter_doc_scanner output
  String? get firstImagePath{ 
    final String path = rawData.images.first;
    final cleanPath = Uri.parse(path).toFilePath();
    return cleanPath;
  }

  @override
  String toString() =>
      detectedType != null ? '$detectedType: $rawData' : rawData.images.first;
}
