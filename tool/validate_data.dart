/// validate_data.dart — Bursa Zemin data validator (P1)
///
/// Usage:
///   dart run tool/validate_data.dart \
///     --geology assets/demo/geology_demo.geojson \
///     --faults  assets/demo/faults_demo.geojson \
///     --classification assets/demo/classification_demo.csv
///
/// Exit 0 = all checks passed (warnings may still be printed).
/// Exit 1 = one or more errors found.
// ignore_for_file: avoid_print
library validate_data;

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Bounding-box constants for Bursa region (WGS-84, [lon, lat])
// ---------------------------------------------------------------------------
const double kLatMin = 39.0;
const double kLatMax = 41.0;
const double kLonMin = 27.5;
const double kLonMax = 30.5;

// ---------------------------------------------------------------------------
// File-size limits
// ---------------------------------------------------------------------------
const int kWarnBytes = 3 * 1024 * 1024; // 3 MB
const int kErrorBytes = 8 * 1024 * 1024; // 8 MB

// ---------------------------------------------------------------------------
// Allowed geometry types per file kind
// ---------------------------------------------------------------------------
const Set<String> kGeologyGeomTypes = {'Polygon', 'MultiPolygon'};
const Set<String> kFaultGeomTypes = {'LineString', 'MultiLineString'};

// ---------------------------------------------------------------------------
// CSV enum sets (case-sensitive, per SPEC §1)
// ---------------------------------------------------------------------------
const Set<String> kZeminTuru = {'Kaya', 'Kil', 'Alüvyon', 'Kum', 'Diğer'};
const Set<String> kRiskValues = {'Düşük', 'Orta', 'Yüksek'};

// ---------------------------------------------------------------------------
// Collector
// ---------------------------------------------------------------------------
final List<String> _errors = [];
final List<String> _warnings = [];

void error(String msg) => _errors.add('[ERROR] $msg');
void warn(String msg) => _warnings.add('[WARN]  $msg');

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
void main(List<String> args) {
  String? geologyPath;
  String? faultsPath;
  String? classificationPath;

  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--geology':
        geologyPath = args[++i];
      case '--faults':
        faultsPath = args[++i];
      case '--classification':
        classificationPath = args[++i];
    }
  }

  if (geologyPath == null || faultsPath == null || classificationPath == null) {
    stderr.writeln(
      'Usage: dart run tool/validate_data.dart '
      '--geology <path> --faults <path> --classification <path>',
    );
    exit(2);
  }

  // 1. Parse CSV first — needed to cross-check birim values.
  final Set<String> csvBirims = _validateCsv(classificationPath);

  // 2. Validate geology GeoJSON.
  _validateGeoJson(
    path: geologyPath,
    label: 'geology',
    allowedGeomTypes: kGeologyGeomTypes,
    csvBirims: csvBirims,
  );

  // 3. Validate faults GeoJSON.
  _validateGeoJson(
    path: faultsPath,
    label: 'faults',
    allowedGeomTypes: kFaultGeomTypes,
    csvBirims: null, // faults don't need birim
  );

  // 4. Print results.
  for (final w in _warnings) {
    stdout.writeln(w);
  }
  for (final e in _errors) {
    stderr.writeln(e);
  }

  if (_errors.isEmpty) {
    stdout.writeln('\n✓ All checks passed'
        '${_warnings.isNotEmpty ? " (${_warnings.length} warning(s))" : ""}.');
    exit(0);
  } else {
    stderr.writeln(
      '\n✗ ${_errors.length} error(s), ${_warnings.length} warning(s). '
      'Fix errors before use.',
    );
    exit(1);
  }
}

// ---------------------------------------------------------------------------
// CSV validator — returns the set of valid birim values found
// ---------------------------------------------------------------------------
Set<String> _validateCsv(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    error('CSV not found: $path');
    return {};
  }

  _checkSize(file, 'classification CSV');

  final lines = file.readAsLinesSync();
  if (lines.isEmpty) {
    error('CSV is empty: $path');
    return {};
  }

  // Header check — exact match required (SPEC §1)
  const expectedHeader = 'birim,ad,zemin_turu,sisme_potansiyeli,zemin_riski';
  final actualHeader = lines[0].trimRight();
  if (actualHeader != expectedHeader) {
    error(
      'CSV header mismatch.\n'
      '  Expected: $expectedHeader\n'
      '  Got:      $actualHeader',
    );
  }

  final birims = <String>{};
  int rowErrors = 0;

  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trimRight();
    if (line.isEmpty) continue; // skip blank trailing lines

    final cols = line.split(',');
    if (cols.length != 5) {
      error('CSV row ${i + 1}: expected 5 columns, got ${cols.length}: $line');
      rowErrors++;
      continue;
    }

    final birim = cols[0].trim();
    final zeminTuru = cols[2].trim();
    final sismePot = cols[3].trim();
    final zeminRisk = cols[4].trim();

    if (birim.isEmpty) {
      error('CSV row ${i + 1}: birim is empty');
      rowErrors++;
    } else {
      birims.add(birim);
    }

    if (!kZeminTuru.contains(zeminTuru)) {
      error(
        'CSV row ${i + 1}: invalid zemin_turu "$zeminTuru". '
        'Allowed: ${kZeminTuru.join(", ")}',
      );
      rowErrors++;
    }
    if (!kRiskValues.contains(sismePot)) {
      error(
        'CSV row ${i + 1}: invalid sisme_potansiyeli "$sismePot". '
        'Allowed: ${kRiskValues.join(", ")}',
      );
      rowErrors++;
    }
    if (!kRiskValues.contains(zeminRisk)) {
      error(
        'CSV row ${i + 1}: invalid zemin_riski "$zeminRisk". '
        'Allowed: ${kRiskValues.join(", ")}',
      );
      rowErrors++;
    }
  }

  final dataRows = lines.length - 1; // excluding header
  stdout.writeln(
    '[INFO]  CSV "$path": $dataRows data row(s), '
    '${birims.length} distinct birim(s)'
    '${rowErrors > 0 ? ", $rowErrors row error(s)" : ""}.',
  );

  return birims;
}

// ---------------------------------------------------------------------------
// GeoJSON validator
// ---------------------------------------------------------------------------
void _validateGeoJson({
  required String path,
  required String label,
  required Set<String> allowedGeomTypes,
  required Set<String>? csvBirims, // null = skip birim cross-check
}) {
  final file = File(path);
  if (!file.existsSync()) {
    error('$label GeoJSON not found: $path');
    return;
  }

  _checkSize(file, '$label GeoJSON');

  // Parse JSON
  final Map<String, dynamic> root;
  try {
    root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    error('$label GeoJSON is not valid JSON: $e');
    return;
  }

  // Must be FeatureCollection
  if (root['type'] != 'FeatureCollection') {
    error(
      '$label GeoJSON: top-level type must be "FeatureCollection", '
      'got "${root['type']}".',
    );
    return;
  }

  final features = root['features'];
  if (features is! List) {
    error('$label GeoJSON: "features" must be a JSON array.');
    return;
  }

  if (features.isEmpty) {
    warn('$label GeoJSON: features array is empty.');
  }

  int featureErrors = 0;
  final birims = <String>{};
  final missingBirims = <String>{};

  for (int fi = 0; fi < features.length; fi++) {
    final feat = features[fi];
    if (feat is! Map<String, dynamic>) {
      error('$label feature[$fi]: not a JSON object.');
      featureErrors++;
      continue;
    }

    if (feat['type'] != 'Feature') {
      error(
          '$label feature[$fi]: type must be "Feature", got "${feat['type']}".');
      featureErrors++;
    }

    final geom = feat['geometry'];
    if (geom == null) {
      error('$label feature[$fi]: geometry is null.');
      featureErrors++;
      continue;
    }
    if (geom is! Map<String, dynamic>) {
      error('$label feature[$fi]: geometry is not a JSON object.');
      featureErrors++;
      continue;
    }

    final geomType = geom['type'] as String?;
    if (geomType == null || !allowedGeomTypes.contains(geomType)) {
      error(
        '$label feature[$fi]: geometry type "$geomType" not allowed. '
        'Allowed: ${allowedGeomTypes.join(", ")}.',
      );
      featureErrors++;
      continue;
    }

    // Check coordinates
    final coords = geom['coordinates'];
    if (coords == null) {
      error('$label feature[$fi]: coordinates is null.');
      featureErrors++;
      continue;
    }

    switch (geomType) {
      case 'Polygon':
        _checkPolygonCoords(coords, '$label feature[$fi]');
      case 'MultiPolygon':
        if (coords is! List) {
          error(
              '$label feature[$fi]: MultiPolygon coordinates must be an array.');
          featureErrors++;
        } else {
          for (int pi = 0; pi < coords.length; pi++) {
            _checkPolygonCoords(coords[pi], '$label feature[$fi] polygon[$pi]');
          }
        }
      case 'LineString':
        _checkLineStringCoords(coords, '$label feature[$fi]');
      case 'MultiLineString':
        if (coords is! List) {
          error(
            '$label feature[$fi]: MultiLineString coordinates must be an array.',
          );
          featureErrors++;
        } else {
          for (int li = 0; li < coords.length; li++) {
            _checkLineStringCoords(
              coords[li],
              '$label feature[$fi] line[$li]',
            );
          }
        }
    }

    // Birim checks (geology only)
    if (csvBirims != null) {
      final props = feat['properties'];
      if (props == null || props is! Map<String, dynamic>) {
        error('$label feature[$fi]: properties missing or not an object.');
        featureErrors++;
        continue;
      }
      final birim = props['birim'];
      if (birim == null || birim is! String || birim.trim().isEmpty) {
        error('$label feature[$fi]: "birim" property missing or empty.');
        featureErrors++;
        continue;
      }
      birims.add(birim);
      if (!csvBirims.contains(birim)) {
        missingBirims.add(birim);
      }
    }
  }

  if (missingBirims.isNotEmpty) {
    error(
      '$label GeoJSON: ${missingBirims.length} birim(s) have no matching row '
      'in the classification CSV: ${missingBirims.join(", ")}',
    );
  }

  stdout.writeln(
    '[INFO]  $label GeoJSON "$path": ${features.length} feature(s)'
    '${birims.isNotEmpty ? ", ${birims.length} distinct birim(s)" : ""}'
    '${featureErrors > 0 ? ", $featureErrors feature error(s)" : ""}.',
  );
}

// ---------------------------------------------------------------------------
// Coordinate helpers
// ---------------------------------------------------------------------------

/// Checks a single [lon, lat] position.
bool _checkPosition(List<dynamic> pos, String ctx) {
  if (pos.length < 2) {
    error('$ctx: position has fewer than 2 elements: $pos');
    return false;
  }
  final lon = (pos[0] as num).toDouble();
  final lat = (pos[1] as num).toDouble();
  if (lat < kLatMin || lat > kLatMax || lon < kLonMin || lon > kLonMax) {
    error(
      '$ctx: coordinate [$lon, $lat] outside Bursa bbox '
      '(lat $kLatMin–$kLatMax, lon $kLonMin–$kLonMax).',
    );
    return false;
  }
  return true;
}

/// Validates a LinearRing (closed ring with >= 4 positions).
void _checkRing(List<dynamic> ring, String ctx) {
  if (ring.length < 4) {
    error('$ctx: ring must have >= 4 positions (got ${ring.length}).');
    return;
  }
  // Check every position is in bbox
  for (int i = 0; i < ring.length; i++) {
    final pos = ring[i];
    if (pos is! List) {
      error('$ctx position[$i]: not an array.');
      continue;
    }
    _checkPosition(pos.cast<dynamic>(), '$ctx position[$i]');
  }
  // Check closed: first == last
  final first = ring.first as List;
  final last = ring.last as List;
  if (first[0] != last[0] || first[1] != last[1]) {
    error('$ctx: ring is not closed (first != last position).');
  }
}

void _checkPolygonCoords(dynamic coords, String ctx) {
  if (coords is! List || coords.isEmpty) {
    error('$ctx: Polygon coordinates must be a non-empty array of rings.');
    return;
  }
  // First ring = outer, rest = holes
  for (int ri = 0; ri < coords.length; ri++) {
    final ring = coords[ri];
    if (ring is! List) {
      error('$ctx ring[$ri]: not an array.');
      continue;
    }
    _checkRing(ring.cast<dynamic>(), '$ctx ring[$ri]');
  }
}

void _checkLineStringCoords(dynamic coords, String ctx) {
  if (coords is! List || coords.length < 2) {
    error(
      '$ctx: LineString must have >= 2 positions (got '
      '${coords is List ? coords.length : "non-array"}).',
    );
    return;
  }
  for (int i = 0; i < coords.length; i++) {
    final pos = coords[i];
    if (pos is! List) {
      error('$ctx position[$i]: not an array.');
      continue;
    }
    _checkPosition(pos.cast<dynamic>(), '$ctx position[$i]');
  }
}

// ---------------------------------------------------------------------------
// File-size check
// ---------------------------------------------------------------------------
void _checkSize(File file, String label) {
  final bytes = file.lengthSync();
  final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
  if (bytes > kErrorBytes) {
    error('$label exceeds 8 MB limit: $mb MB (${file.path}).');
  } else if (bytes > kWarnBytes) {
    warn('$label is large (> 3 MB): $mb MB. Consider tiling.');
  }
}
