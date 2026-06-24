import 'dart:ui';

enum MatchStrategy {
  boundingBox, // Matches based on a defined expected area
  absoluteIndex, // Matches the N-th text block found in the document
  sameLineAsAnchor, // Finds an anchor text and selects a block on the same line
  linesBelowAnchor, // Finds an anchor text and selects the next N lines below it
  regex, // Finds an anchor text and selects the next N lines below it
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
  final int? offsetOnLine; // e.g. 1 means the next text block to the right

  // Used for linesBelowAnchor matching
  final int? numLinesBelow;

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
    this.numLinesBelow,
    this.fallback,
    this.formatter,
    this.extractRegex,
  });
}

Map<DetectedType, List<FieldInstruction>> get instructionSet => {
  DetectedType.nin_slip: [
    FieldInstruction(
      attributeName: 'NIN Number',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText:
          'NIN:', // assuming it says something like "National Identification Number: 1234..."
      offsetOnLine: 1, // take the text box to the right of it
      //extract only numbers
      extractRegex: RegExp(r'\d+'),
      fallback: FieldInstruction(
        attributeName: "NIN Number",
        // extractRegex:
        extractRegex: RegExp(r'\d{11}'),
        strategy: MatchStrategy.regex,
      ),
    ),
    FieldInstruction(
      attributeName: 'First Name',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText: 'First Name:', // arbitrary mock index
      //extract the last part of the string after : and only capital letters
      extractRegex: RegExp(r': ([A-Z]+)'),
      // offsetOnLine: 0,
      fallback: FieldInstruction(
        attributeName: 'First Name',
        strategy: MatchStrategy.linesBelowAnchor,
        anchorText: 'Middle Name:', // arbitrary mock index
        numLinesBelow: -1,
        formatter: (p0) {
          if (p0.contains(":")) {
            return p0.split(":").last.trim();
          }
          return p0.trim();
        },
        // offsetOnLine: ,
      ),
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
      // extractRegex: RegExp(r': ([A-Z]+)'),
      fallback: FieldInstruction(
        attributeName: 'Last Name',
        strategy: MatchStrategy.linesBelowAnchor,
        anchorText: 'Middle Name:', // arbitrary mock index
        numLinesBelow: -2,
        formatter: (p0) {
          if (p0.contains(":")) {
            return p0.split(":").last.trim();
          }
          return p0.trim();
        },
        // offsetOnLine: ,
      ),
      formatter: (p0) {
        if (p0.contains(":")) {
          return p0.split(":").last.trim();
        }
        return p0.trim();
      },
      // offsetOnLine: ,
    ),
    FieldInstruction(
      attributeName: 'Tracking ID',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText: 'Surname:', // arbitrary mock index
      //return the unbroken text with 15 chars
      extractRegex: RegExp(r'\b\S{15}\b'),
      fallback: FieldInstruction(
        attributeName: "NIN Number",
        // extractRegex:
        extractRegex: RegExp(r'\b\S{15}\b'),
        strategy: MatchStrategy.regex,
      ),
    ),

    //gender
    FieldInstruction(
      attributeName: 'Gender',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText: 'Gender:',
      fallback: FieldInstruction(
        attributeName: 'Gender',
        strategy: MatchStrategy.sameLineAsAnchor,
        anchorText: 'Gender:',
        // fallback: ,
        offsetOnLine: 1,
        formatter: (p0) {
          if (p0.contains(":")) {
            return p0.split(":").last.trim();
          }
          return p0.trim();
        },
      ),
      formatter: (p0) {
        if (p0.contains(":")) {
          return p0.split(":").last.trim();
        }
        return p0.trim();
      },
    ),

    // Address
    FieldInstruction(
      attributeName: 'Address',
      strategy: MatchStrategy.linesBelowAnchor,
      anchorText: 'Address',
      numLinesBelow: 3,
    ),
  ],

  DetectedType.nin_improved_slip: [
    FieldInstruction(
      attributeName: "Surname",
      strategy: MatchStrategy.linesBelowAnchor,
      numLinesBelow: 1,
      anchorText: "Surname",
      fallback: FieldInstruction(
        attributeName: "Surname",
        strategy: MatchStrategy.linesBelowAnchor,
        numLinesBelow: 1,
        anchorText: "Nom",
      ),
    ),
    FieldInstruction(
      attributeName: "First Name",
      strategy: MatchStrategy.linesBelowAnchor,
      numLinesBelow: 1,
      anchorText: "Given Name",
      formatter: (p0) {
        if (!p0.contains(",")) {
          return p0.trim();
        }
        return p0.split(",").first.trim();
      },
    ),
    FieldInstruction(
      attributeName: "Middle Name",
      strategy: MatchStrategy.linesBelowAnchor,
      numLinesBelow: 1,
      anchorText: "Given Name",
      formatter: (p0) {
        if (!p0.contains(",")) {
          return '';
        }
        return p0.split(",").last.trim();
      },
    ),

    //date of birth
    FieldInstruction(
      attributeName: 'Date of Birth',
      strategy: MatchStrategy.regex,
      extractRegex: RegExp(r'\b\d{2}\s+[a-zA-Z]{3}\s+\d{4}\b'),
      fallback: FieldInstruction(
        attributeName: 'Date of Birth',
        strategy: MatchStrategy.regex,
        extractRegex: RegExp(r'\b\d{2}\s+[a-zA-Z]{3}\s+\d{2}\b'),
      ),
    ),
    FieldInstruction(
      attributeName: "NIN",
      strategy: MatchStrategy.regex,

      extractRegex: RegExp(r'\d{4}\s\d{3}\s\d{4}'),
      formatter: (p0) => p0.replaceAll(' ', ''),
      // numLinesBelow: 1,
      // anchorText: "NATIONAL IDENTIFICATION ",
      fallback: FieldInstruction(
        attributeName: "NIN",
        strategy: MatchStrategy.regex,
        extractRegex: RegExp(r'\d{11}'),
      ),
    ),
  ],
};

enum DetectedType { nin_slip, nin_improved_slip }
