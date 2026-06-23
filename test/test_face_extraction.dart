import 'dart:io';
import 'package:id_card_scanner/services/face_extraction_service.dart';

void main() async {
  print('Starting face extraction test...');
  final faceService = FaceExtractionService();
  
  final String testImagePath = '${Directory.current.path}/assets/nin_slip.png';
  
  final file = File(testImagePath);
  if (!file.existsSync()) {
    print('Error: Test image not found at $testImagePath');
    exit(1);
  }
  
  try {
    final resultPath = await faceService.extractFace(testImagePath);
    
    if (resultPath != null) {
      print('Success! Face extracted and saved to: $resultPath');
    } else {
      print('No face found in the image.');
    }
  } catch (e) {
    print('Error during face extraction: $e');
  } finally {
    faceService.dispose();
  }
}
