import 'dart:convert';
import 'dart:io';

import 'package:bursa_zemin/features/geology/domain/assessment.dart';
import 'package:bursa_zemin/features/geology/domain/classification.dart';
import 'package:bursa_zemin/features/geology/domain/geo_index.dart';
import 'package:bursa_zemin/features/geology/domain/geojson_parser.dart';
import 'package:bursa_zemin/features/geology/domain/risk_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('P8 Performance Benchmark — Demo Dataset & Tap Lookup Metrics', () {
    // 1. Read dataset files from disk
    final geojsonString =
        File('assets/demo/geology_demo.geojson').readAsStringSync();
    final faultsString =
        File('assets/demo/faults_demo.geojson').readAsStringSync();
    final csvString =
        File('assets/demo/classification_demo.csv').readAsStringSync();
    final rulesString =
        File('assets/config/risk_rules.json').readAsStringSync();

    // 2. Measure parse times
    final parseStopwatch = Stopwatch()..start();
    final features = parseGeologyGeoJson(geojsonString);
    final faults = parseFaultsGeoJson(faultsString);
    final classifications = parseClassificationCsv(csvString);
    final rulesJson = jsonDecode(rulesString) as Map<String, dynamic>;
    final rules = FaultDistanceRules.fromJson(rulesJson);
    final geoIndex = GeoIndex(
      features: features,
      classifications: classifications,
    );
    parseStopwatch.stop();
    final parseTimeMs = parseStopwatch.elapsedMicroseconds / 1000.0;

    // 3. Count features & vertices
    final featureCount = features.length;
    int totalPolygonVertices = 0;
    int polygonCount = 0;
    for (final feature in features) {
      for (final shape in feature.shapes) {
        polygonCount++;
        totalPolygonVertices += shape.outerRing.length;
        for (final hole in shape.holes) {
          totalPolygonVertices += hole.length;
        }
      }
    }

    int faultVertices = 0;
    for (final fault in faults) {
      for (final line in fault.lines) {
        faultVertices += line.length;
      }
    }

    // 4. Measure tap lookup performance
    // Sample points: inside polygon, near fault, outside all polygons
    final testPoints = [
      const LatLng(40.1885, 29.0610), // Central Bursa (DEMO-1)
      const LatLng(40.2100, 29.0200), // Northwest (DEMO-2)
      const LatLng(40.1700, 29.1000), // Southeast (DEMO-3)
      const LatLng(40.1932, 29.0611), // Near fault line
      const LatLng(40.1000, 29.0000), // Outside all polygons
    ];

    // Warm-up
    for (final pt in testPoints) {
      assess(
        point: pt,
        geoIndex: geoIndex,
        faults: faults,
        faultRules: rules,
      );
    }

    // Benchmark single tap lookups
    final singleTapTimes = <double>[];
    for (final pt in testPoints) {
      final sw = Stopwatch()..start();
      final res = assess(
        point: pt,
        geoIndex: geoIndex,
        faults: faults,
        faultRules: rules,
      );
      sw.stop();
      expect(res, isNotNull);
      singleTapTimes.add(sw.elapsedMicroseconds / 1000.0);
    }

    // 1,000 iterations stress test to compute reliable average and max
    const iterations = 1000;
    final iterStopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final pt = testPoints[i % testPoints.length];
      assess(
        point: pt,
        geoIndex: geoIndex,
        faults: faults,
        faultRules: rules,
      );
    }
    iterStopwatch.stop();
    final avgLookupMs =
        (iterStopwatch.elapsedMicroseconds / 1000.0) / iterations;

    // Print measured metrics for inspection and report
    // ignore: avoid_print
    print('''
=== P8 PERFORMANCE BENCHMARK RESULTS ===
Feature Count (Geology): $featureCount
Polygon Count: $polygonCount
Total Polygon Vertices: $totalPolygonVertices
Fault Line Count: ${faults.length}
Total Fault Vertices: $faultVertices
Dataset Parse Time: ${parseTimeMs.toStringAsFixed(3)} ms
Single Tap Lookup Times (5 test points): ${singleTapTimes.map((t) => '${t.toStringAsFixed(3)}ms').join(', ')}
Average Tap Lookup Time ($iterations runs): ${avgLookupMs.toStringAsFixed(4)} ms
Max Measured Single Tap Time: ${singleTapTimes.reduce((a, b) => a > b ? a : b).toStringAsFixed(3)} ms
Under 50ms requirement: ${avgLookupMs < 50.0 ? 'PASSED (<<50ms)' : 'FAILED'}
========================================
''');

    // Invariants
    expect(featureCount, greaterThan(0));
    expect(totalPolygonVertices, greaterThan(0));
    expect(avgLookupMs, lessThan(50.0),
        reason: 'Tap lookup must be well under 50ms');
    for (final t in singleTapTimes) {
      expect(t, lessThan(50.0));
    }
  });
}
