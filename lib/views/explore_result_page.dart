import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/scan_document.dart';

class ExploreResultPage extends StatefulWidget {
  final ScanDocument scanResult;

  const ExploreResultPage({super.key, required this.scanResult});

  @override
  State<ExploreResultPage> createState() => _ExploreResultPageState();
}

class _ExploreResultPageState extends State<ExploreResultPage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final path = widget.scanResult.firstImagePath;
    if (path == null) return;

    final data = await File(path).readAsBytes();
    final image = await decodeImageFromList(data);
    if (mounted) {
      setState(() {
        _image = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Result'),
      ),
      backgroundColor: Colors.black,
      body: _image == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: InteractiveViewer(
                maxScale: 10.0,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _image!.width.toDouble(),
                    height: _image!.height.toDouble(),
                    child: CustomPaint(
                      painter: OverlayPainter(
                        image: _image!,
                        scanResult: widget.scanResult,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class OverlayPainter extends CustomPainter {
  final ui.Image image;
  final ScanDocument scanResult;

  OverlayPainter({required this.image, required this.scanResult});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the original image
    final paint = Paint();
    canvas.drawImage(image, Offset.zero, paint);

    // Draw text bounding boxes
    if (scanResult.textBoundingBoxes != null) {
      final textPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = Colors.redAccent;
        
      final textBgPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.redAccent.withValues(alpha: 0.2);

      for (final entry in scanResult.textBoundingBoxes!.entries) {
        final rect = entry.value;
        canvas.drawRect(rect, textBgPaint);
        canvas.drawRect(rect, textPaint);
      }
    }

    // Draw face bounding box
    if (scanResult.faceBoundingBox != null) {
      final faceBoxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = Colors.blueAccent;
      canvas.drawRect(scanResult.faceBoundingBox!, faceBoxPaint);
    }

    // Draw barcode bounding box
    if (scanResult.barcodeBoundingBox != null) {
      final barcodeBoxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = Colors.purpleAccent;
      canvas.drawRect(scanResult.barcodeBoundingBox!, barcodeBoxPaint);
    }

    // Draw face mesh
    if (scanResult.faceMeshPoints != null && scanResult.faceMeshPoints!.isNotEmpty) {
      final meshPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.greenAccent;
        
      for (final point in scanResult.faceMeshPoints!) {
        canvas.drawCircle(point, 3.0, meshPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.scanResult != scanResult;
  }
}
