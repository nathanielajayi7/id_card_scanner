import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:face_detection_tflite/face_detection_tflite.dart' as tflite;

class FaceExtractionResult {
  final String imagePath;
  final Rect boundingBox;
  final List<Offset> meshPoints;

  FaceExtractionResult({
    required this.imagePath,
    required this.boundingBox,
    required this.meshPoints,
  });
}

class FaceExtractionService {
  final FaceDetector _faceDetector;
  tflite.FaceDetector? _backupFaceDetector;

  FaceExtractionService()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: false,
          enableTracking: false,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.1,
        ),
      );

  Future<FaceExtractionResult?> extractFace(
    String imagePath, {
    double paddingFactor = 0.2,
  }) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    Rect? targetBoundingBox;
    List<Offset> targetMeshPoints = [];

    if (faces.isNotEmpty) {
      // We assume the largest face is the KYC face
      Face targetFace = faces.first;
      for (var face in faces) {
        if (face.boundingBox.width * face.boundingBox.height >
            targetFace.boundingBox.width * targetFace.boundingBox.height) {
          targetFace = face;
        }
      }

      targetBoundingBox = targetFace.boundingBox;
      final contours = targetFace.contours.values;
      targetMeshPoints = contours
          .where((c) => c != null)
          .expand((c) => c!.points)
          .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
          .toList();
    } else {
      // Fallback to TFLite
      _backupFaceDetector ??= await tflite.FaceDetector.create();
      final List<tflite.Face> tfliteFaces = await _backupFaceDetector!
          .detectFacesFromFilepath(imagePath);

      if (tfliteFaces.isEmpty) {
        return null;
      }

      tflite.Face targetFace = tfliteFaces.first;
      for (var face in tfliteFaces) {
        if (face.boundingBox.width * face.boundingBox.height >
            targetFace.boundingBox.width * targetFace.boundingBox.height) {
          targetFace = face;
        }
      }

      targetBoundingBox = Rect.fromLTWH(
        targetFace.boundingBox.topLeft.x.toDouble(),
        targetFace.boundingBox.topLeft.y.toDouble(),
        targetFace.boundingBox.width.toDouble(),
        targetFace.boundingBox.height.toDouble(),
      );

      if (targetFace.mesh != null) {
        targetMeshPoints = targetFace.mesh!.points
            .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
            .toList();
      }
    }

    // Load original image using the 'image' package to crop it
    final fileBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(fileBytes);

    if (originalImage == null) return null;

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
    final String kycImagePath = '${tempDir.path}/kyc_face_$timestamp.jpg';

    final croppedBytes = img.encodeJpg(croppedImage);
    final kycFile = File(kycImagePath);
    await kycFile.writeAsBytes(croppedBytes);

    return FaceExtractionResult(
      imagePath: kycImagePath,
      boundingBox: targetBoundingBox,
      meshPoints: targetMeshPoints,
    );
  }

  /// Slightly enhances the contrast and brightness of the given image.
  /// Returns the path to the newly saved enhanced image.
  Future<String> enhanceImage(String imagePath, {String? type}) async {
    final fileBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(fileBytes);

    if (originalImage == null) return imagePath;

    // Apply slight contrast (e.g., 1.2 = 120%) and brightness adjustments
    final enhancedImage = img.adjustColor(
      originalImage,
      contrast: imageNeedsContrast(type) ? 1.5 : 1.2,
      brightness: imageNeedsContrast(type) ? 1.3 : 1.1,
    );

    img.Image grayscale = img.grayscale(enhancedImage);

    // 2. Boost the contrast sharply to make faint text solid black
    img.Image highContrast = img.contrast(grayscale, contrast: 150);

    // Save to temp directory
    final tempDir = Directory.systemTemp;
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String enhancedImagePath = '${tempDir.path}/enhanced_$timestamp.jpg';

    final enhancedBytes = img.encodeJpg(highContrast);
    final enhancedFile = File(enhancedImagePath);
    await enhancedFile.writeAsBytes(enhancedBytes);

    return enhancedImagePath;
  }

  bool imageNeedsContrast(String? type) {
    return type == "passort" || type == "digital_nin_slip";
  }

  void dispose() {
    _faceDetector.close();
    _backupFaceDetector?.dispose();
  }
}
