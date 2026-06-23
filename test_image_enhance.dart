import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

void main() {
  var image = img.Image(width: 10, height: 10);
  var enhanced = img.adjustColor(image, contrast: 1.2, brightness: 1.1);
  if (kDebugMode) {
    print(enhanced);
  }
}
