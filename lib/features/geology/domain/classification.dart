import 'package:csv/csv.dart';
import 'models.dart';

/// Exception thrown when classification CSV parsing fails.
class ClassificationParseException implements FormatException {
  @override
  final String message;
  @override
  final dynamic source;
  @override
  final int? offset;

  const ClassificationParseException(this.message, [this.source, this.offset]);

  @override
  String toString() => 'ClassificationParseException: $message';
}

const Set<String> kAllowedZeminTuru = {
  'Kaya',
  'Kil',
  'Alüvyon',
  'Kum',
  'Diğer'
};
const Set<String> kAllowedRiskStrings = {'Düşük', 'Orta', 'Yüksek'};

/// Parses a CSV string into a map of `birim` -> [ClassificationRow].
///
/// Throws [ClassificationParseException] on:
/// - Empty CSV
/// - Header mismatch
/// - Invalid column count
/// - Values outside the allowed strict enums (SPEC §1)
Map<String, ClassificationRow> parseClassificationCsv(String csvStr) {
  if (csvStr.trim().isEmpty) {
    throw const ClassificationParseException('CSV content is empty.');
  }

  // Normalize Windows/Unix line endings to \n
  final normalizedCsv = csvStr.replaceAll('\r\n', '\n');

  // Use CsvToListConverter with shouldParseNumbers: false to keep strings intact
  // and explicit eol: '\n'
  const converter = CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: false,
  );

  final List<List<dynamic>> rows;
  try {
    rows = converter.convert(normalizedCsv);
  } catch (e) {
    throw ClassificationParseException('Failed to parse CSV format: $e');
  }

  if (rows.isEmpty) {
    throw const ClassificationParseException('CSV has no rows.');
  }

  // 1. Verify header
  final headerRow = rows.first;
  if (headerRow.length != 5) {
    throw ClassificationParseException(
      'Header mismatch: expected 5 columns, got ${headerRow.length} ($headerRow).',
    );
  }

  final expectedHeader = [
    'birim',
    'ad',
    'zemin_turu',
    'sisme_potansiyeli',
    'zemin_riski'
  ];
  for (int i = 0; i < 5; i++) {
    final actualCol = headerRow[i].toString().trim();
    if (actualCol != expectedHeader[i]) {
      throw ClassificationParseException(
        'Header mismatch at column $i: expected "${expectedHeader[i]}", got "$actualCol".',
      );
    }
  }

  // 2. Parse data rows
  final result = <String, ClassificationRow>{};

  for (int ri = 1; ri < rows.length; ri++) {
    final row = rows[ri];
    if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
      continue; // Skip blank lines
    }

    if (row.length != 5) {
      throw ClassificationParseException(
        'Row ${ri + 1}: expected 5 columns, got ${row.length} ($row).',
      );
    }

    final birim = row[0].toString().trim();
    final ad = row[1].toString().trim();
    final zeminTuru = row[2].toString().trim();
    final sismePotStr = row[3].toString().trim();
    final zeminRiskStr = row[4].toString().trim();

    if (birim.isEmpty) {
      throw ClassificationParseException('Row ${ri + 1}: "birim" is empty.');
    }

    if (!kAllowedZeminTuru.contains(zeminTuru)) {
      throw ClassificationParseException(
        'Row ${ri + 1} ($birim): invalid zemin_turu "$zeminTuru". '
        'Allowed: ${kAllowedZeminTuru.join(", ")}.',
      );
    }

    if (!kAllowedRiskStrings.contains(sismePotStr)) {
      throw ClassificationParseException(
        'Row ${ri + 1} ($birim): invalid sisme_potansiyeli "$sismePotStr". '
        'Allowed: ${kAllowedRiskStrings.join(", ")}.',
      );
    }

    if (!kAllowedRiskStrings.contains(zeminRiskStr)) {
      throw ClassificationParseException(
        'Row ${ri + 1} ($birim): invalid zemin_riski "$zeminRiskStr". '
        'Allowed: ${kAllowedRiskStrings.join(", ")}.',
      );
    }

    final sismePot = RiskLevel.fromTurkish(sismePotStr);
    final zeminRisk = RiskLevel.fromTurkish(zeminRiskStr);

    result[birim] = ClassificationRow(
      birim: birim,
      ad: ad,
      zeminTuru: zeminTuru,
      sismePotansiyeli: sismePot,
      zeminRiski: zeminRisk,
    );
  }

  return result;
}
