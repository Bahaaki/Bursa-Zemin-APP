import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Risk levels defined in SPEC §2: Düşük, Orta, Yüksek.
enum RiskLevel implements Comparable<RiskLevel> {
  dusuk('Düşük'),
  orta('Orta'),
  yuksek('Yüksek');

  final String turkishName;
  const RiskLevel(this.turkishName);

  static RiskLevel fromTurkish(String val) {
    switch (val.trim()) {
      case 'Düşük':
        return RiskLevel.dusuk;
      case 'Orta':
        return RiskLevel.orta;
      case 'Yüksek':
        return RiskLevel.yuksek;
      default:
        throw ArgumentError.value(val, 'val', 'Unknown Turkish RiskLevel');
    }
  }

  bool operator <(RiskLevel other) => index < other.index;
  bool operator <=(RiskLevel other) => index <= other.index;
  bool operator >(RiskLevel other) => index > other.index;
  bool operator >=(RiskLevel other) => index >= other.index;

  @override
  int compareTo(RiskLevel other) => index.compareTo(other.index);
}

/// 2D Bounding Box for geospatial fast-rejection checks.
class BBox {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const BBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  factory BBox.fromPoints(Iterable<LatLng> points) {
    if (points.isEmpty) {
      return const BBox(minLat: 0, maxLat: 0, minLon: 0, maxLon: 0);
    }
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }

    return BBox(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }

  factory BBox.combine(Iterable<BBox> boxes) {
    if (boxes.isEmpty) {
      return const BBox(minLat: 0, maxLat: 0, minLon: 0, maxLon: 0);
    }
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;

    for (final b in boxes) {
      minLat = math.min(minLat, b.minLat);
      maxLat = math.max(maxLat, b.maxLat);
      minLon = math.min(minLon, b.minLon);
      maxLon = math.max(maxLon, b.maxLon);
    }

    return BBox(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }

  bool contains(LatLng p) {
    return p.latitude >= minLat &&
        p.latitude <= maxLat &&
        p.longitude >= minLon &&
        p.longitude <= maxLon;
  }
}

/// Represents a single Polygon with an outer ring and optional interior rings (holes).
class PolygonShape {
  final List<LatLng> outerRing;
  final List<List<LatLng>> holes;
  final BBox bbox;

  PolygonShape({
    required this.outerRing,
    this.holes = const [],
    BBox? bbox,
  }) : bbox = bbox ?? BBox.fromPoints(outerRing);
}

/// A geological feature representing one or more polygon shapes (supporting MultiPolygon).
class GeoFeature {
  final String id;
  final Map<String, dynamic> properties;
  final List<PolygonShape> shapes;
  final BBox bbox;

  GeoFeature({
    required this.id,
    required this.properties,
    required this.shapes,
    BBox? bbox,
  }) : bbox = bbox ?? BBox.combine(shapes.map((s) => s.bbox));

  String get birim => (properties['birim'] as String?)?.trim() ?? '';
  bool get isDemo => properties['demo'] == true;
}

/// A fault feature consisting of one or more line strings.
class FaultLine {
  final String? name;
  final List<List<LatLng>> lines;
  final bool isDemo;

  const FaultLine({
    this.name,
    required this.lines,
    this.isDemo = false,
  });
}

/// Row from assets/config/classification.csv (or demo equivalent).
class ClassificationRow {
  final String birim;
  final String ad;
  final String zeminTuru;
  final RiskLevel sismePotansiyeli;
  final RiskLevel zeminRiski;

  const ClassificationRow({
    required this.birim,
    required this.ad,
    required this.zeminTuru,
    required this.sismePotansiyeli,
    required this.zeminRiski,
  });
}

/// Result of nearest fault calculation.
class NearestFaultResult {
  final String? name;
  final double distanceKm;

  const NearestFaultResult({
    this.name,
    required this.distanceKm,
  });
}

/// Comprehensive preliminary ground assessment result (SPEC §2, §3.3).
class Assessment {
  final bool hasData;
  final GeoFeature? feature;
  final ClassificationRow? classification;
  final NearestFaultResult? nearestFault;
  final RiskLevel? faultRiskLevel;
  final RiskLevel? overallRisk;
  final String recommendation;
  final bool isDemo;

  const Assessment({
    required this.hasData,
    this.feature,
    this.classification,
    this.nearestFault,
    this.faultRiskLevel,
    this.overallRisk,
    required this.recommendation,
    this.isDemo = false,
  });
}
