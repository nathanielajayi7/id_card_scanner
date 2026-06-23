import 'dart:ui';

enum MatchStrategy {
  boundingBox,     // Matches based on a defined expected area
  absoluteIndex,   // Matches the N-th text block found in the document
  sameLineAsAnchor // Finds an anchor text and selects a block on the same line
}

class FieldInstruction {
  final String attributeName;
  final MatchStrategy strategy;

  // Used for boundingBox matching (values 0.0 to 1.0)
  final Rect? expectedRegion; 

  // Used for absoluteIndex matching (0-based)
  final int? index;

  // Used for sameLineAsAnchor matching
  final String? anchorText; // e.g. "DOB"
  final int? offsetOnLine;  // e.g. 1 means the next text block to the right

  // Fallback instruction if this one fails to find a match
  final FieldInstruction? fallback;

  // Optional cleaning/formatting method applied after extraction
  final String Function(String)? formatter;

  // Optional RegExp to extract a specific part of the matched text
  final RegExp? extractRegex;

  FieldInstruction({
    required this.attributeName,
    required this.strategy,
    this.expectedRegion,
    this.index,
    this.anchorText,
    this.offsetOnLine = 0,
    this.fallback,
    this.formatter,
    this.extractRegex,
  });
}

Map<DetectedType, List<FieldInstruction>> get instructionSet => 
  {
    DetectedType.nin_slip : [
        FieldInstruction(
                attributeName: 'NIN Number',
                strategy: MatchStrategy.sameLineAsAnchor,
                anchorText: 'NIN:', // assuming it says something like "National Identification Number: 1234..."
                offsetOnLine: 1, // take the text box to the right of it
                //extract only numbers
                extractRegex: RegExp(r'\d+')
              ),
              FieldInstruction(
                attributeName: 'First Name',
                strategy: MatchStrategy.sameLineAsAnchor,
                anchorText: 'First Name:', // arbitrary mock index
                //extract the last part of the string after : and only capital letters
                extractRegex: RegExp(r': ([A-Z]+)'),
                // offsetOnLine: 0,
              ),
              //middle name
              FieldInstruction(
                attributeName: 'Middle Name',
                strategy: MatchStrategy.sameLineAsAnchor,
                anchorText: 'Middle Name:', // arbitrary mock index
                //extract the last part of the string after : and only capital letters
                extractRegex: RegExp(r': ([A-Z]+)'),
                // offsetOnLine: 0,
              ),
              //last name
              FieldInstruction(
                attributeName: 'Last Name',
                strategy: MatchStrategy.sameLineAsAnchor,
                anchorText: 'Surname:', // arbitrary mock index
                //extract the last part of the string after : and only capital letters
                extractRegex: RegExp(r': ([A-Z]+)'),
                // offsetOnLine: ,
              )
    ]  
};

enum DetectedType {
  nin_slip
}