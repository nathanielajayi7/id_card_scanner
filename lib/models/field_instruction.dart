import 'dart:developer';
import 'dart:ui';

enum MatchStrategy {
  boundingBox, // Matches based on a defined expected area
  absoluteIndex, // Matches the N-th text block found in the document
  sameLineAsAnchor, // Finds an anchor text and selects a block on the same line
  linesBelowAnchor, // Finds an anchor text and selects the next N lines below it
  regex, // Finds an anchor text and selects the next N lines below it
  regexAnchor, // Finds an anchor using regex and selects a block based on offsetOnLine or numLinesBelow
  relativeToKnownField, // Uses the bounding box of a previously extracted field as anchor
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

  // Used for regexAnchor matching
  final RegExp? anchorRegex;

  // Used for linesBelowAnchor matching
  final int? numLinesBelow;

  // Used for relativeToKnownField matching
  final String? knownFieldAnchor;

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
    this.anchorRegex,
    this.knownFieldAnchor,
    this.offsetOnLine = 0,
    this.numLinesBelow,
    this.fallback,
    this.formatter,
    this.extractRegex,
  });
}

Map<DetectedType, List<FieldInstruction>> get instructionSet => {
  DetectedType.verified_nin: [
    FieldInstruction(
      attributeName: 'Middle Name',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText: 'Middle', // arbitrary mock index
      offsetOnLine: 1,
    ),

    FieldInstruction(
      attributeName: "First Name",
      strategy: MatchStrategy.relativeToKnownField,
      knownFieldAnchor: "Middle Name",
      numLinesBelow: -1,
      formatter: (p0) {
        if (p0.contains(":")) {
          return p0.split(":").last.trim();
        }
        return p0;
      },
      // fallback: FieldInstruction(
      //   attributeName: 'First Name',
      //   strategy: MatchStrategy.sameLineAsAnchor,
      //   anchorText: 'First', // arbitrary mock index
      //   offsetOnLine: 1,
      // ),
    ),

    FieldInstruction(
      attributeName: "Last Name",
      strategy: MatchStrategy.relativeToKnownField,
      knownFieldAnchor: "Middle Name",
      numLinesBelow: 1,
      formatter: (p0) {
        if (p0.contains(":")) {
          return p0.split(":").last.trim();
        }
        return p0;
      },
      fallback: FieldInstruction(
        attributeName: 'Last Name',
        strategy: MatchStrategy.relativeToKnownField,
        knownFieldAnchor: 'First Name', // arbitrary mock index
        numLinesBelow: 4,
        formatter: (p0) {
          if (p0.contains(":")) {
            return p0.split(":").last.trim();
          }
          return p0;
        },
      ),
    ),

    FieldInstruction(
      attributeName: 'Gender',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText: 'Gender', // arbitrary mock index
      offsetOnLine: 1,
    ),

    FieldInstruction(
      attributeName: 'Address',
      strategy: MatchStrategy.sameLineAsAnchor,
      anchorText: 'Address', // arbitrary mock index
      offsetOnLine: 1,
    ),

    FieldInstruction(
      attributeName: 'Date of Birth',
      strategy: MatchStrategy.regex,
      extractRegex: RegExp(r'\b\d{2}-\d{2}-\d{4}\b'),
      fallback: FieldInstruction(
        attributeName: 'Date of Birth',
        strategy: MatchStrategy.regex,
        extractRegex: RegExp(r'\b\d{2}/\d{2}/\d{4}\b'),
        fallback: FieldInstruction(
          attributeName: 'Date of Birth',
          strategy: MatchStrategy.regex,
          extractRegex: RegExp(r'\b\d{4}-\d{2}-\d{2}\b'),
        ),
      ),
    ),

    FieldInstruction(
      attributeName: "Tracking ID",
      // extractRegex:
      extractRegex: RegExp(r'^[A-Z]{3}[a-zA-Z0-9]{12}$'),
      anchorText: "Tracking",
      // offsetOnLine: 1,
      strategy: MatchStrategy.regex,
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
        fallback: FieldInstruction(
          attributeName: "NIN",
          strategy: MatchStrategy.regex,
          // extractRegex: RegExp(r'
          extractRegex: RegExp(r'\b\d{4}\s?\d{3}\s?\d{4}\b'),
        ),
      ),
    ),
  ],
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
        attributeName: "Tracking ID",
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
        fallback: FieldInstruction(
          attributeName: "NIN",
          strategy: MatchStrategy.regex,
          // extractRegex: RegExp(r'
          extractRegex: RegExp(r'\b\d{4}\s?\d{3}\s?\d{4}\b'),
        ),
      ),
    ),
  ],

  DetectedType.digital_nin_slip: [
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
      extractRegex: RegExp(r'\b\d{4}\s?\d{3}\s?\d{4}\b'),
      formatter: (p0) => p0.replaceAll(' ', ''),
      // numLinesBelow: 1,
      // anchorText: "NATIONAL IDENTIFICATION ",
      fallback: FieldInstruction(
        attributeName: "NIN",
        anchorText: "National ldentification Number (NIN)",
        strategy: MatchStrategy.linesBelowAnchor,
        numLinesBelow: 1,
        extractRegex: RegExp(r'\d{11}'),
      ),
    ),
    FieldInstruction(
      attributeName: "Gender",

      // strategy: MatchStrategy.linesBelowAnchor,
      // anchorText: "Sex",
      // numLinesBelow: 1,
      strategy: MatchStrategy.regex,
      extractRegex: RegExp(r'\b[MF]\b'),

      fallback: FieldInstruction(
        attributeName: "Gender",
        strategy: MatchStrategy.regex,
        extractRegex: RegExp(r'\b[MF]\b'),
      ),
    ),
  ],

  DetectedType.passort: [
    FieldInstruction(
      attributeName: 'Given Names',
      strategy: MatchStrategy.regexAnchor,
      anchorRegex: RegExp(r'^P[A-Z<]NGA(?<surname>[A-Z]+)<<'),
      formatter: (p0) {
        return extractAllGivenNames(p0);
      },
    ),
    FieldInstruction(
      attributeName: 'Surname',
      strategy: MatchStrategy.regex,
      extractRegex: RegExp(r'^P[A-Z<]NGA(?<surname>[A-Z]+)<<'),
      formatter: (p0) {
        return p0;
      },
    ),
    // FieldInstruction(
    //   attributeName: 'Date of Birth',
    //   strategy: MatchStrategy.linesBelowAnchor,
    //   anchorText: "Birth",
    //   numLinesBelow: 1,
    //   extractRegex: RegExp(r'\b\d{2}\s+[a-zA-Z]{3}'),
    //   fallback: FieldInstruction(
    //     attributeName: 'Date of Birth',
    //     strategy: MatchStrategy.regex,
    //     extractRegex: RegExp(r'\b\d{2}\s+[a-zA-Z]{3}'),
    //   ),
    // ),
    FieldInstruction(
      attributeName: "NIN",
      // anchorText: "National ldentification Number (NIN)",
      strategy: MatchStrategy.regex,
      // numLinesBelow: 1,
      extractRegex: RegExp(r'\d{11}'),
    ),
    FieldInstruction(
      attributeName: 'Passport Number',
      strategy: MatchStrategy.regex,
      extractRegex: RegExp(r'^[A-Z][0-9]{8}'),
      fallback: FieldInstruction(
        attributeName: "Passport Number",
        strategy: MatchStrategy.linesBelowAnchor,
        anchorText: "<<",
        numLinesBelow: 1,
        formatter: (p0) {
          // 1. Grab the first 9 characters of Line 2
          if (p0.length < 9) return '';
          String rawNumber = p0.substring(0, 9).toUpperCase();

          // 2. OCR Auto-Correction: Fix the first character if it was misread as a number
          String firstChar = rawNumber.substring(0, 1);
          String remainingDigits = rawNumber.substring(1, 9);

          // Common typo fix: If the first char is a '0' (zero), it was likely an 'O'
          if (firstChar == '0') {
            firstChar = 'O';
          } else if (firstChar == '1') {
            firstChar = 'I';
          }

          // Common typo fix: Turn any accidental letters in the remaining 8 slots into numbers
          remainingDigits = remainingDigits
              .replaceAll('O', '0')
              .replaceAll('I', '1');

          String processedNumber = firstChar + remainingDigits;

          // 3. Apply your strict regex verification to the healed string
          final RegExp strictPassportRegex = RegExp(r'^[A-Z][0-9]{8}$');

          if (strictPassportRegex.hasMatch(processedNumber)) {
            return processedNumber;
          }
          return '';
        },
      ),
    ),
  ],
};

enum DetectedType {
  nin_slip,
  nin_improved_slip,
  digital_nin_slip,
  passort,
  verified_nin,
}

// Your anchored given names regex
// final RegExp anchoredGivenNamesRegex = RegExp(
//   r'^P[A-Z<]{4}[A-Z]+<<(?<givenNames>[A-Z<]+?)(?:<<|<|$)',
// );

String extractAllGivenNames(String mrzLine1) {
  // Strip OCR whitespaces
  final String cleanLine = mrzLine1.replaceAll(' ', '').toUpperCase();

  // The corrected pattern with strict double-chevron or end-of-line boundaries
  final RegExp correctedRegex = RegExp(
    r'^P[A-Z<]{4}[A-Z]+<<(?<givenNames>[A-Z<]+?)(?:<<|$)',
  );

  final RegExpMatch? match = correctedRegex.firstMatch(cleanLine);

  if (match != null) {
    String rawNames = match.namedGroup('givenNames') ?? '';

    // Converts the internal single chevrons back to a clean space for your app
    return rawNames.replaceAll('<', ' ').trim();
  }
  return '';
}
