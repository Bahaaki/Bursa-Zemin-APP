import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'models.dart';

/// Mean radius of Earth in kilometers (WGS-84).
const double kEarthRadiusKm = 6371.0088;

/// Finds the nearest fault and its distance in kilometers using a local
/// equirectangular projection centered at [point]'s latitude (SPEC §2).
///
/// Returns `null` if [faults] is empty.
NearestFaultResult? findNearestFault(LatLng point, List<FaultLine> faults) {
  if (faults.isEmpty) {
    return null;
  }

  final lat0Rad = point.latitude * math.pi / 180.0;
  final cosLat0 = math.cos(lat0Rad);

  String? nearestName;
  double minDistanceKm = double.infinity;

  // Local projection coordinates of a LatLng point:
  // x = (lon - lon0) * (pi / 180) * cos(lat0) * R
  // y = (lat - lat0) * (pi / 180) * R
  // The query point is at (0, 0).
  for (final fault in faults) {
    for (final line in fault.lines) {
      if (line.length < 2) continue;

      for (int i = 0; i < line.length - 1; i++) {
        final p1 = line[i];
        final p2 = line[i + 1];

        final x1 = (p1.longitude - point.longitude) *
            (math.pi / 180.0) *
            cosLat0 *
            kEarthRadiusKm;
        final y1 =
            (p1.latitude - point.latitude) * (math.pi / 180.0) * kEarthRadiusKm;

        final x2 = (p2.longitude - point.longitude) *
            (math.pi / 180.0) *
            cosLat0 *
            kEarthRadiusKm;
        final y2 =
            (p2.latitude - point.latitude) * (math.pi / 180.0) * kEarthRadiusKm;

        final dist = _pointToSegmentDistance(x1, y1, x2, y2);
        if (dist < minDistanceKm) {
          minDistanceKm = dist;
          nearestName = fault.name;
        }
      }
    }
  }

  if (minDistanceKm.isInfinite) {
    return null;
  }

  return NearestFaultResult(
    name: nearestName,
    distanceKm: minDistanceKm,
  );
}

/// Distance from origin (0, 0) to line segment (x1, y1)-(x2, y2).
double _pointToSegmentDistance(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final l2 = dx * dx + dy * dy;

  if (l2 == 0.0) {
    // Degenerate segment: distance to (x1, y1)
    return math.sqrt(x1 * x1 + y1 * y1);
  }

  // Projection of (0, 0) onto segment:
  // Vector AP = (-x1, -y1), AB = (dx, dy)
  // t = (AP . AB) / |AB|^2 = (-x1 * dx - y1 * dy) / l2
  final t = (-x1 * dx - y1 * dy) / l2;
  final tClamped = t.clamp(0.0, 1.0);

  final nx = x1 + tClamped * dx;
  final ny = y1 + tClamped * dy;

  return math.sqrt(nx * nx + ny * ny);
}
