import 'dart:io';
import 'package:flutter/material.dart';
import '../models/scan_document.dart';
import 'explore_result_page.dart';

class ResultPage extends StatelessWidget {
  final ScanDocument scanResult;

  const ResultPage({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 32),
              const Text(
                'Scan Completed Successfully',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      scanResult.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (scanResult.kycImagePath != null) ...[
                      const SizedBox(height: 16),
                      const Text('Extracted KYC Face:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(scanResult.kycImagePath!),
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    if (scanResult.barcodeImgPath != null) ...[
                      const SizedBox(height: 16),
                      const Text('Extracted Barcode:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(scanResult.barcodeImgPath!),
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                    if (scanResult.extractedData != null && scanResult.extractedData!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Extracted Fields:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...scanResult.extractedData!.entries.map(
                        (e) => Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 14)),
                      ).toList(),
                    ],
                    if (scanResult.extractedBarcodes != null && scanResult.extractedBarcodes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Extracted Barcodes:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...scanResult.extractedBarcodes!.map(
                        (b) => Text(b, style: const TextStyle(fontSize: 14)),
                      ).toList(),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to Home
                    },
                    child: const Text('Back to Home'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExploreResultPage(scanResult: scanResult),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('Explore Result'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
