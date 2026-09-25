import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:bursa_zemin/features/geology/domain/point_in_polygon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('point_in_polygon ray casting', () {
    // A square: lat 40.0..40.2, lon 29.0..29.2
    final square = PolygonShape(
      outerRing: const [
        LatLng(40.0, 29.0),
        LatLng(40.2, 29.0),
        LatLng(40.2, 29.2),
        LatLng(40.0, 29.2),
        LatLng(40.0, 29.0),
      ],
      holes: const [],
    );

    test('point strictly inside polygon returns true', () {
      expect(isPointInPolygon(const LatLng(40.1, 29.1), square), isTrue);
    });

    test('point strictly outside polygon returns false', () {
      expect(isPointInPolygon(const LatLng(40.5, 29.5), square), isFalse);
      expect(isPointInPolygon(const LatLng(39.9, 29.1), square), isFalse);
    });

    test('point on boundary is inclusive (returns true)', () {
      // On western edge
      expect(isPointInPolygon(const LatLng(40.1, 29.0), square), isTrue);
      // On corner
      expect(isPointInPolygon(const LatLng(40.0, 29.0), square), isTrue);
      // On northern edge
      expect(isPointInPolygon(const LatLng(40.2, 29.1), square), isTrue);
    });

    // Square with a hole in the center: hole is lat 40.05..40.15, lon 29.05..29.15
    final squareWithHole = PolygonShape(
      outerRing: const [
        LatLng(40.0, 29.0),
        LatLng(40.2, 29.0),
        LatLng(40.2, 29.2),
        LatLng(40.0, 29.2),
        LatLng(40.0, 29.0),
      ],
      holes: const [
        [
          LatLng(40.05, 29.05),
          LatLng(40.15, 29.05),
          LatLng(40.15, 29.15),
          LatLng(40.05, 29.15),
          LatLng(40.05, 29.05),
        ]
      ],
    );

    test('point inside outer ring but outside hole returns true', () {
      expect(
          isPointInPolygon(const LatLng(40.02, 29.02), squareWithHole), isTrue);
    });

    test('point inside hole returns false', () {
      expect(isPointInPolygon(const LatLng(40.10, 29.10), squareWithHole),
          isFalse);
    });

    test('point on boundary of hole: strictly inside hole is outside', () {
      // Point in center of hole
      expect(isPointInPolygon(const LatLng(40.10, 29.10), squareWithHole),
          isFalse);
    });

    test(
        'MultiPolygon feature test: points in first or second part return true',
        () {
      // MultiPolygon with two disconnected squares: Part A (40.0..40.1, 29.0..29.1), Part B (40.3..40.4, 29.3..29.4)
      final partA = PolygonShape(
        outerRing: const [
          LatLng(40.0, 29.0),
          LatLng(40.1, 29.0),
          LatLng(40.1, 29.1),
          LatLng(40.0, 29.1),
          LatLng(40.0, 29.0),
        ],
        holes: const [],
      );
      final partB = PolygonShape(
        outerRing: const [
          LatLng(40.3, 29.3),
          LatLng(40.4, 29.3),
          LatLng(40.4, 29.4),
          LatLng(40.3, 29.4),
          LatLng(40.3, 29.3),
        ],
        holes: const [],
      );

      final multiFeature = GeoFeature(
        id: 'multi-1',
        properties: {'birim': 'TEST-MULTI'},
        shapes: [partA, partB],
      );

      // In part A
      expect(
          isPointInFeature(const LatLng(40.05, 29.05), multiFeature), isTrue);
      // In part B (second part of MultiPolygon)
      expect(
          isPointInFeature(const LatLng(40.35, 29.35), multiFeature), isTrue);
      // In gap between parts
      expect(isPointInFeature(const LatLng(40.2, 29.2), multiFeature), isFalse);
    });
  });
}
