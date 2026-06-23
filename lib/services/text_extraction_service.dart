import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../models/field_instruction.dart';

class TextExtractionResult {
  final Map<String, String> data;
  final Map<String, Rect> boundingBoxes;

  TextExtractionResult({required this.data, required this.boundingBoxes});
}

class _DocumentLine {
  final double centerY;
  final List<TextLine> textLines = [];

  _DocumentLine(this.centerY);
}

class TextExtractionService {
  final TextRecognizer _textRecognizer;

  TextExtractionService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<TextExtractionResult> extractAttributes(
    String imagePath,
    List<FieldInstruction> instructions,
  ) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    // Get image dimensions for relative bounding box calculations
    final fileBytes = await File(imagePath).readAsBytes();
    final decodedImage = img.decodeImage(fileBytes);
    final double imgW = decodedImage?.width.toDouble() ?? 1000.0;
    final double imgH = decodedImage?.height.toDouble() ?? 1000.0;

    // Flatten all lines from all blocks
    List<TextLine> allLines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        allLines.add(line);
      }
    }

    // Sort all lines roughly from top to bottom
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // Group lines into horizontal physical lines
    List<_DocumentLine> documentLines = [];
    for (var line in allLines) {
      double centerY = line.boundingBox.top + (line.boundingBox.height / 2);
      double threshold = line.boundingBox.height / 2.0;

      bool added = false;
      for (var docLine in documentLines) {
        if ((docLine.centerY - centerY).abs() < threshold) {
          docLine.textLines.add(line);
          added = true;
          break;
        }
      }
      if (!added) {
        final newLine = _DocumentLine(centerY);
        newLine.textLines.add(line);
        documentLines.add(newLine);
      }
    }

    // Sort blocks horizontally within each line
    for (var docLine in documentLines) {
      docLine.textLines.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    }

    Map<String, String> extractedData = {};
    Map<String, Rect> extractedRects = {};

    for (var instruction in instructions) {
      final result = _processInstruction(instruction, allLines, documentLines, imgW, imgH);
      final matchedText = result?.text;
      final matchedRect = result?.rect;

      if (matchedText != null && matchedText.trim().isNotEmpty) {
        extractedData[instruction.attributeName] = matchedText;
        if (matchedRect != null) {
          extractedRects[instruction.attributeName] = matchedRect;
        }
      }
    }

    return TextExtractionResult(data: extractedData, boundingBoxes: extractedRects);
  }

  _InstructionResult? _processInstruction(
    FieldInstruction instruction,
    List<TextLine> allLines,
    List<_DocumentLine> documentLines,
    double imgW,
    double imgH,
  ) {
    String? matchedText;
    Rect? matchedRect;

    switch (instruction.strategy) {
      case MatchStrategy.boundingBox:
        if (instruction.expectedRegion != null) {
          final expectedRect = Rect.fromLTWH(
            instruction.expectedRegion!.left * imgW,
            instruction.expectedRegion!.top * imgH,
            instruction.expectedRegion!.width * imgW,
            instruction.expectedRegion!.height * imgH,
          );

          TextLine? bestMatch;
          double highestOverlap = -1.0;

          for (var line in allLines) {
            final intersect = expectedRect.intersect(Rect.fromLTWH(
              line.boundingBox.left, line.boundingBox.top, 
              line.boundingBox.width, line.boundingBox.height
            ));

            if (intersect.width > 0 && intersect.height > 0) {
              double overlapArea = intersect.width * intersect.height;
              if (overlapArea > highestOverlap) {
                highestOverlap = overlapArea;
                bestMatch = line;
              }
            }
          }

          // Fallback: use center point distance if no overlap
          if (bestMatch == null) {
            double minDistance = double.infinity;
            for (var line in allLines) {
              double dx = expectedRect.center.dx - (line.boundingBox.left + line.boundingBox.width / 2);
              double dy = expectedRect.center.dy - (line.boundingBox.top + line.boundingBox.height / 2);
              double dist = sqrt(dx * dx + dy * dy);
              if (dist < minDistance) {
                minDistance = dist;
                bestMatch = line;
              }
            }
          }

          if (bestMatch != null) {
            matchedText = bestMatch.text;
            matchedRect = bestMatch.boundingBox;
          }
        }
        break;

      case MatchStrategy.absoluteIndex:
        if (instruction.index != null && instruction.index! < allLines.length) {
          matchedText = allLines[instruction.index!].text;
          matchedRect = allLines[instruction.index!].boundingBox;
        }
        break;

      case MatchStrategy.sameLineAsAnchor:
        if (instruction.anchorText != null && instruction.offsetOnLine != null) {
          for (var docLine in documentLines) {
            int anchorIdx = docLine.textLines.indexWhere((l) =>
                l.text.toLowerCase().contains(instruction.anchorText!.toLowerCase()));
            
            if (anchorIdx != -1) {
              int targetIdx = anchorIdx + instruction.offsetOnLine!;
              if (targetIdx >= 0 && targetIdx < docLine.textLines.length) {
                matchedText = docLine.textLines[targetIdx].text;
                matchedRect = docLine.textLines[targetIdx].boundingBox;
              }
              break;
            }
          }
        }
        break;

      case MatchStrategy.linesBelowAnchor:
        if (instruction.anchorText != null && instruction.numLinesBelow != null) {
          for (int i = 0; i < documentLines.length; i++) {
            var docLine = documentLines[i];
            
            // Find the specific anchor block to establish horizontal position
            TextLine? anchorBlock;
            for (var l in docLine.textLines) {
              if (l.text.toLowerCase().contains(instruction.anchorText!.toLowerCase())) {
                anchorBlock = l;
                break;
              }
            }
            
            if (anchorBlock != null) {
              List<String> combinedLines = [];
              double? left, top, right, bottom;
              
              double anchorLeft = anchorBlock.boundingBox.left;
              double anchorRight = anchorBlock.boundingBox.right;
              
              int count = instruction.numLinesBelow!;
              int startIndex = count > 0 ? i + 1 : i + count;
              int endIndex = count > 0 ? i + count : i - 1;
              
              for (int targetIndex = startIndex; targetIndex <= endIndex; targetIndex++) {
                if (targetIndex >= 0 && targetIndex < documentLines.length) {
                  var targetLine = documentLines[targetIndex];
                  
                  // Filter text blocks that align vertically with the anchor
                  List<TextLine> alignedBlocks = [];
                  for (var block in targetLine.textLines) {
                    double blockLeft = block.boundingBox.left;
                    double blockRight = block.boundingBox.right;
                    
                    // Condition: Horizontally overlaps OR left edge is within 100px tolerance
                    bool overlaps = max(anchorLeft, blockLeft) <= min(anchorRight, blockRight);
                    bool leftAligned = (anchorLeft - blockLeft).abs() < 100;
                    
                    if (overlaps || leftAligned) {
                      alignedBlocks.add(block);
                    }
                  }
                  
                  if (alignedBlocks.isNotEmpty) {
                    String lineText = alignedBlocks.map((e) => e.text).join(' ');
                    if (lineText.trim().isNotEmpty) {
                      combinedLines.add(lineText);
                    }
                    
                    for (var block in alignedBlocks) {
                      if (left == null || block.boundingBox.left < left) left = block.boundingBox.left;
                      if (top == null || block.boundingBox.top < top) top = block.boundingBox.top;
                      if (right == null || block.boundingBox.right > right) right = block.boundingBox.right;
                      if (bottom == null || block.boundingBox.bottom > bottom) bottom = block.boundingBox.bottom;
                    }
                  }
                }
              }
              
              if (combinedLines.isNotEmpty) {
                matchedText = combinedLines.join('\n');
                if (left != null && top != null && right != null && bottom != null) {
                  matchedRect = Rect.fromLTRB(left, top, right, bottom);
                }
              }
              break;
            }
          }
        }
        break;

      case MatchStrategy.regex:
        if (instruction.extractRegex != null) {
          for (var line in allLines) {
            if (instruction.extractRegex!.hasMatch(line.text)) {
              matchedText = line.text;
              matchedRect = line.boundingBox;
              break;
            }
          }
        }
        break;
    }

    // Apply regex if present
    if (matchedText != null && instruction.extractRegex != null) {
      final match = instruction.extractRegex!.firstMatch(matchedText);
      if (match != null) {
        matchedText = match.groupCount >= 1 ? match.group(1) : match.group(0);
      } else {
        matchedText = null;
      }
    }

    // Apply formatting if present
    if (matchedText != null && instruction.formatter != null) {
      matchedText = instruction.formatter!(matchedText);
    }

    // Attempt fallback if we still don't have text
    if ((matchedText == null || matchedText.trim().isEmpty) && instruction.fallback != null) {
      return _processInstruction(instruction.fallback!, allLines, documentLines, imgW, imgH);
    }

    if (matchedText == null) return null;
    return _InstructionResult(matchedText, matchedRect);
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class _InstructionResult {
  final String text;
  final Rect? rect;
  _InstructionResult(this.text, this.rect);
}
