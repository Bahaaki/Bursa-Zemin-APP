import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'models.dart';

/// Checks if [point] is inside or on the boundary of [polygon].
///
/// Semantics:
/// - BBox pre-check rejects points outside the bounding box in O(1).
/// - Points on the boundary of the outer ring are considered INSIDE (inclusive).
/// - Points strictly inside an interior ring (hole) are considered OUTSIDE.
bool isPointInPolygon(LatLng point, PolygonShape polygon) {
  // 1. BBox pre-check
  if (!polygon.bbox.contains(point)) {
    return false;
  }

  // 2. Check outer ring
  final outer = polygon.outerRing;
  if (outer.length < 3) return false;

  // Boundary check (inclusive per SPEC §2)
  for (int i = 0, j = outer.length - 1; i < outer.length; j = i++) {
    if (_isPointOnSegment(point, outer[j], outer[i])) {
      return true;
    }
  }

  // Ray-casting for outer ring
  if (!_rayCastContains(point, outer)) {
    return false;
  }

  // 3. Check holes (if strictly inside any hole, point is outside the polygon)
  for (final hole in polygon.holes) {
    if (hole.length < 3) continue;

    // Check if on hole boundary (hole edge is considered part of the polygon surface)
    bool onHoleBoundary = false;
    for (int i = 0, j = hole.length - 1; i < hole.length; j = i++) {
      if (_isPointOnSegment(point, hole[j], hole[i])) {
        onHoleBoundary = true;
        break;
      }
    }
    if (onHoleBoundary) {
      continue;
    }

    if (_rayCastContains(point, hole)) {
      return false; // Strictly inside a hole
    }
  }

  return true;
}

/// Checks if [point] is inside any of the polygon shapes composing [feature].
bool isPointInFeature(LatLng point, GeoFeature feature) {
  if (!feature.bbox.contains(point)) {
    return false;
  }
  for (final shape in feature.shapes) {
    if (isPointInPolygon(point, shape)) {
      return true;
    }
  }
  return false;
}

/// Standard horizontal ray casting algorithm.
bool _rayCastContains(LatLng point, List<LatLng> ring) {
  bool inside = false;
  final px = point.longitude;
  final py = point.latitude;

  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude;
    final yi = ring[i].latitude;
    final xj = ring[j].longitude;
    final yj = ring[j].latitude;

    final intersect = ((yi > py) != (yj > py)) &&
        (px < (xj - xi) * (py - yi) / (yj - yi) + xi);

    if (intersect) {
      inside = !inside;
    }
  }

  return inside;
}

/// Checks if [p] lies on the straight segment between [a] and [b].
bool _isPointOnSegment(LatLng p, LatLng a, LatLng b, [double eps = 1e-9]) {
  final minLat = math.min(a.latitude, b.latitude) - eps;
  final maxLat = math.max(a.latitude, b.latitude) + eps;
  final minLon = math.min(a.longitude, b.longitude) - eps;
  final maxLon = math.max(a.longitude, b.longitude) + eps;

  if (p.latitude < minLat ||
      p.latitude > maxLat ||
      p.longitude < minLon ||
      p.longitude > maxLon) {
    return false;
  }

  // Cross product (b - a) x (p - a)
  final cross = (b.longitude - a.longitude) * (p.latitude - a.latitude) -
      (b.latitude - a.latitude) * (p.longitude - a.longitude);
  return cross.abs() <= eps;
}
