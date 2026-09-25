import 'dart:io';
import 'package:bursa_zemin/features/geology/domain/geojson_parser.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('geojson_parser geology parsing', () {
    test('parses demo geology GeoJSON successfully', () {
      final content =
          File('assets/demo/geology_demo.geojson').readAsStringSync();
      final features = parseGeologyGeoJson(content);

      expect(features.length, equals(5));
      expect(features.map((f) => f.birim).toSet(),
          containsAll({'DEMO-1', 'DEMO-2', 'DEMO-3', 'DEMO-4', 'DEMO-5'}));

      // Verify coordinate order: [lon, lat] in GeoJSON becomes LatLng(lat, lon)
      // DEMO-1 first coordinate in GeoJSON is [28.90, 40.10]
      final demo1 = features.firstWhere((f) => f.birim == 'DEMO-1');
      expect(demo1.shapes.first.outerRing.first.latitude, equals(40.10));
      expect(demo1.shapes.first.outerRing.first.longitude, equals(28.90));

      // DEMO-5 is a MultiPolygon with 2 polygons
      final demo5 = features.firstWhere((f) => f.birim == 'DEMO-5');
      expect(demo5.shapes.length, equals(2));
    });

    test('throws GeoJsonParseException on invalid JSON syntax', () {
      expect(
        () => parseGeologyGeoJson('{ invalid json '),
        throwsA(isA<GeoJsonParseException>()),
      );
    });

    test('throws GeoJsonParseException when type is not FeatureCollection', () {
      expect(
        () => parseGeologyGeoJson('{"type": "Polygon", "coordinates": []}'),
        throwsA(isA<GeoJsonParseException>().having(
          (e) => e.message,
          'message',
          contains('FeatureCollection'),
        )),
      );
    });

    test('throws GeoJsonParseException when feature has no birim property', () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[[29.0, 40.0], [29.1, 40.0], [29.1, 40.1], [29.0, 40.1], [29.0, 40.0]]]
            }
          }
        ]
      }
      ''';
      expect(
        () => parseGeologyGeoJson(geoJson),
        throwsA(isA<GeoJsonParseException>().having(
          (e) => e.message,
          'message',
          contains('birim'),
        )),
      );
    });

    test(
        'throws GeoJsonParseException for unknown or disallowed geometry types (not silently dropped)',
        () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"birim": "TEST"},
            "geometry": {
              "type": "Point",
              "coordinates": [29.0, 40.0]
            }
          }
        ]
      }
      ''';
      expect(
        () => parseGeologyGeoJson(geoJson),
        throwsA(isA<GeoJsonParseException>().having(
          (e) => e.message,
          'message',
          contains('Point'),
        )),
      );
    });
  });

  group('geojson_parser faults parsing', () {
    test('parses demo faults GeoJSON successfully', () {
      final content =
          File('assets/demo/faults_demo.geojson').readAsStringSync();
      final faults = parseFaultsGeoJson(content);

      expect(faults.length, equals(2));
      // First is LineString, second is MultiLineString
      expect(faults[0].name, equals('DEMO Fay 1'));
      expect(faults[0].lines.length, equals(1));
      expect(faults[0].lines.first.first.latitude, equals(40.05));
      expect(faults[0].lines.first.first.longitude, equals(28.85));

      expect(faults[1].name, equals('DEMO Fay 2'));
      expect(faults[1].lines.length, equals(2));
    });

    test(
        'throws GeoJsonParseException when fault has disallowed geometry type like Polygon',
        () {
      const geoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"ad": "Bad Fault"},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[[29.0, 40.0], [29.1, 40.0], [29.1, 40.1], [29.0, 40.1], [29.0, 40.0]]]
            }
          }
        ]
      }
      ''';
      expect(
        () => parseFaultsGeoJson(geoJson),
        throwsA(isA<GeoJsonParseException>().having(
          (e) => e.message,
          'message',
          contains('Polygon'),
        )),
      );
    });

    test(
        'swapped [lat, lon] input parses faithfully as [lon, lat] without error in parser (bbox validation is tool responsibility)',
        () {
      // If someone erroneously enters [40.1, 29.0] instead of [29.0, 40.1]:
      // The parser faithfully assigns lon = 40.1, lat = 29.0.
      // It does not throw a parser syntax error, but creates a LatLng(29.0, 40.1).
      const swappedGeoJson = '''
      {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {"birim": "SWAPPED"},
            "geometry": {
              "type": "Polygon",
              "coordinates": [[[40.1, 29.0], [40.2, 29.0], [40.2, 29.1], [40.1, 29.1], [40.1, 29.0]]]
            }
          }
        ]
      }
      ''';
      final parsed = parseGeologyGeoJson(swappedGeoJson);
      expect(parsed.length, equals(1));
      // First point latitude is 29.0, longitude is 40.1
      expect(parsed.first.shapes.first.outerRing.first.latitude, equals(29.0));
      expect(parsed.first.shapes.first.outerRing.first.longitude, equals(40.1));
      // Outside Bursa region bbox (lat 39-41, lon 27.5-30.5), which is caught by tool/validate_data.dart
      const bursaBBox =
          BBox(minLat: 39.0, maxLat: 41.0, minLon: 27.5, maxLon: 30.5);
      expect(bursaBBox.contains(parsed.first.shapes.first.outerRing.first),
          isFalse);
    });
  });
}
