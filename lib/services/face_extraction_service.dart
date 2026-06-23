import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceExtractionService {
  final FaceDetector _faceDetector;

  FaceExtractionService()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: false,
            enableClassification: false,
            enableTracking: false,
            enableLandmarks: false,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  Future<String?> extractFace(String imagePath, {double paddingFactor = 0.2}) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      return null;
    }

    // We assume the largest face is the KYC face, or just take the first one.
    // For ID cards, usually there's only one prominent face.
    Face targetFace = faces.first;
    for (var face in faces) {
      if (face.boundingBox.width * face.boundingBox.height >
          targetFace.boundingBox.width * targetFace.boundingBox.height) {
        targetFace = face;
      }
    }

    final boundingBox = targetFace.boundingBox;

    // Load original image using the 'image' package to crop it
    final fileBytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(fileBytes);

    if (originalImage == null) return null;

    // Calculate padding
    final paddingX = boundingBox.width * paddingFactor;
    final paddingY = boundingBox.height * paddingFactor;

    int cropX = (boundingBox.left - paddingX).toInt();
    int cropY = (boundingBox.top - paddingY).toInt();
    int cropWidth = (boundingBox.width + 2 * paddingX).toInt();
    int cropHeight = (boundingBox.height + 2 * paddingY).toInt();

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

    return kycImagePath;
  }

  void dispose() {
    _faceDetector.close();
  }
}
