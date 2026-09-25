import 'package:bursa_zemin/features/geology/domain/fault_distance.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('fault_distance calculations', () {
    // A fault along latitude 40.0, from lon 29.0 to lon 29.2
    const faultAlongParallel = FaultLine(
      name: 'Test Parallel Fault',
      lines: [
        [
          LatLng(40.0, 29.0),
          LatLng(40.0, 29.2),
        ]
      ],
    );

    test(
        'point 0.01° away perpendicular to parallel line has distance ≈ 1.11 km (within 2%)',
        () {
      const point = LatLng(40.01, 29.10);
      final result = findNearestFault(point, [faultAlongParallel]);

      expect(result, isNotNull);
      expect(result!.name, equals('Test Parallel Fault'));
      // 0.01° of latitude ≈ 1.111 km. Tolerance 2%: 1.111 * 0.02 ≈ 0.022 km
      expect(result.distanceKm, closeTo(1.11, 0.03));
    });

    test(
        'point beyond segment ends calculates distance to the closest endpoint',
        () {
      // Point east of (40.0, 29.2), at (40.0, 29.3)
      const point = LatLng(40.0, 29.3);
      final result = findNearestFault(point, [faultAlongParallel]);

      expect(result, isNotNull);
      // Distance from (40.0, 29.3) to (40.0, 29.2) along 40° latitude:
      // Delta lon = 0.1° -> 0.1 * cos(40°) * 111.32 km ≈ 0.1 * 0.7660 * 111.32 ≈ 8.53 km
      expect(result!.distanceKm, closeTo(8.53, 0.25));
    });

    test('empty faults list returns null', () {
      final result = findNearestFault(const LatLng(40.0, 29.0), []);
      expect(result, isNull);
    });

    test('multiple faults selects the closest one', () {
      const closeFault = FaultLine(
        name: 'Close Fault',
        lines: [
          [LatLng(40.10, 29.0), LatLng(40.10, 29.2)]
        ],
      );
      const farFault = FaultLine(
        name: 'Far Fault',
        lines: [
          [LatLng(40.50, 29.0), LatLng(40.50, 29.2)]
        ],
      );

      final result =
          findNearestFault(const LatLng(40.11, 29.1), [farFault, closeFault]);
      expect(result, isNotNull);
      expect(result!.name, equals('Close Fault'));
      expect(result.distanceKm, closeTo(1.11, 0.03));
    });
  });
}
