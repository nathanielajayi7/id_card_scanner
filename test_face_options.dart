import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() {
  var options = FaceDetectorOptions(
    minFaceSize: 0.01,
  );
  print(options.minFaceSize);
}
