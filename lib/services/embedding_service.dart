import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class EmbeddingService {
  Interpreter? _interpreter;
  Map<String, List<double>> _anchors = {};

  Future<void> initialize() async {
    // Load model
    _interpreter = await Interpreter.fromAsset('packages/id_card_scanner/assets/mobilenet_v2_1.0_224.tflite');

    // Load anchors
    final jsonStr = await rootBundle.loadString('packages/id_card_scanner/assets/anchors.json');
    final Map<String, dynamic> rawAnchors = jsonDecode(jsonStr);
    _anchors = rawAnchors.map((key, value) => MapEntry(key, List<double>.from(value.map((e) => (e as num).toDouble()))));
  }

  Future<String?> classifyDocument(String imagePath) async {
    if (_interpreter == null) {
      await initialize();
    }

    // Read and decode image
    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Preprocess: Resize to 224x224
    final resized = img.copyResize(image, width: 304, height: 192);

    // MobileNetV2 expects input shape [1, 224, 224, 3] and values in [-1, 1]
    // Using a flat Float32List is significantly faster and more memory-efficient than nested lists.
    var inputBuffer = Float32List(1 * 304 * 192 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 192; y++) {
      for (int x = 0; x < 304; x++) {
        final pixel = resized.getPixel(x, y);
        // Normalized to [-1, 1]
        inputBuffer[pixelIndex++] = (pixel.r / 127.5) - 1.0;
        inputBuffer[pixelIndex++] = (pixel.g / 127.5) - 1.0;
        inputBuffer[pixelIndex++] = (pixel.b / 127.5) - 1.0;
      }
    }

    // tflite_flutter expects the input as the reshaped structure
    var input = inputBuffer.reshape([1, 192, 304, 3]);

    // Output shape for this model is likely [1, 1280]
    var output = List.generate(1, (i) => List.filled(1280, 0.0));

    _interpreter!.run(input, output);
    final embedding = output[0];

    // Compare to anchors using Cosine Similarity and Euclidean Distance
    String bestMatch = "unknown";
    double bestScore = -double.infinity;

    for (var entry in _anchors.entries) {
      double sim = _cosineSimilarity(embedding, entry.value);
      double dist = _euclideanDistance(embedding, entry.value);
      
      // Combine metrics: maximize similarity and minimize distance, scaled down
      double combinedScore = sim - (dist / 100.0);
      
      // Logging for redundancy/debugging
      debugPrint('Anchor: ${entry.key} -> Cosine Sim: $sim | Euclidean Dist: $dist | Combined: $combinedScore');

      if (combinedScore > bestScore) {
        bestScore = combinedScore;
        bestMatch = entry.key;
      }
    }

    // Return the label with highest similarity
    return bestMatch;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;
    double sumSq = 0.0;
    for (int i = 0; i < a.length; i++) {
      double diff = a[i] - b[i];
      sumSq += diff * diff;
    }
    return sqrt(sumSq);
  }
}
