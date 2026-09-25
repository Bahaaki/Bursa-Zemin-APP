import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'point_in_polygon.dart';

/// Geospatial index over geology features with classification lookup.
class GeoIndex {
  final List<GeoFeature> features;
  final Map<String, ClassificationRow> classifications;

  const GeoIndex({
    required this.features,
    required this.classifications,
  });

  /// Finds the geology feature containing [point].
  ///
  /// If multiple features contain [point] (overlapping boundaries),
  /// the feature with the highest `zemin_riski` wins (conservative rule per SPEC §2).
  GeoFeature? findAt(LatLng point) {
    final matching = <GeoFeature>[];

    for (final feature in features) {
      if (isPointInFeature(point, feature)) {
        matching.add(feature);
      }
    }

    if (matching.isEmpty) {
      return null;
    }

    if (matching.length == 1) {
      return matching.first;
    }

    // Overlap: highest zemin_riski wins
    matching.sort((a, b) {
      final riskA = classifications[a.birim]?.zeminRiski ?? RiskLevel.dusuk;
      final riskB = classifications[b.birim]?.zeminRiski ?? RiskLevel.dusuk;
      return riskB.compareTo(riskA); // Descending: yuksek first
    });

    return matching.first;
  }
}
