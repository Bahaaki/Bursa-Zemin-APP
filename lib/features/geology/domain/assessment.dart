import 'package:latlong2/latlong.dart';
import 'fault_distance.dart';
import 'geo_index.dart';
import 'models.dart';
import 'risk_rules.dart';

/// Calculates the overall risk level as max(zemin_riski, sisme_potansiyeli, faultLevel).
///
/// If [faultLevel] is `null` (unknown / no fault data), it is ignored per SPEC §2.
RiskLevel calculateOverallRisk({
  required RiskLevel zeminRiski,
  required RiskLevel sismePotansiyeli,
  RiskLevel? faultLevel,
}) {
  RiskLevel maxLevel =
      zeminRiski > sismePotansiyeli ? zeminRiski : sismePotansiyeli;
  if (faultLevel != null && faultLevel > maxLevel) {
    maxLevel = faultLevel;
  }
  return maxLevel;
}

/// Returns the exact Turkish recommendation string for a given [overallRisk] (SPEC §2).
///
/// - Düşük -> "Uygun (ön değerlendirme)"
/// - Orta  -> "Dikkatli"
/// - Yüksek -> "Sondaj Gerekli"
/// - null (outside all polygons) -> "Veri yok – zemin etüdü gerekli"
String getRecommendation(RiskLevel? overallRisk) {
  if (overallRisk == null) {
    return 'Veri yok – zemin etüdü gerekli';
  }
  switch (overallRisk) {
    case RiskLevel.dusuk:
      return 'Uygun (ön değerlendirme)';
    case RiskLevel.orta:
      return 'Dikkatli';
    case RiskLevel.yuksek:
      return 'Sondaj Gerekli';
  }
}

/// Performs a comprehensive preliminary ground assessment at [point].
Assessment assess({
  required LatLng point,
  required GeoIndex geoIndex,
  List<FaultLine>? faults,
  FaultDistanceRules? faultRules,
}) {
  final feature = geoIndex.findAt(point);
  if (feature == null) {
    return const Assessment(
      hasData: false,
      feature: null,
      classification: null,
      nearestFault: null,
      faultRiskLevel: null,
      overallRisk: null,
      recommendation: 'Veri yok – zemin etüdü gerekli',
      isDemo: false,
    );
  }

  final classification = geoIndex.classifications[feature.birim];

  NearestFaultResult? nearestFault;
  RiskLevel? faultRiskLevel;

  if (faults != null && faults.isNotEmpty) {
    nearestFault = findNearestFault(point, faults);
    if (nearestFault != null) {
      faultRiskLevel = classifyFaultDistance(
        nearestFault.distanceKm,
        faultRules ?? const FaultDistanceRules(),
      );
    }
  }

  final zeminRiski = classification?.zeminRiski ?? RiskLevel.dusuk;
  final sismePot = classification?.sismePotansiyeli ?? RiskLevel.dusuk;

  final overallRisk = calculateOverallRisk(
    zeminRiski: zeminRiski,
    sismePotansiyeli: sismePot,
    faultLevel: faultRiskLevel,
  );

  final recommendation = getRecommendation(overallRisk);
  final isDemo =
      feature.isDemo || (faults != null && faults.any((f) => f.isDemo));

  return Assessment(
    hasData: true,
    feature: feature,
    classification: classification,
    nearestFault: nearestFault,
    faultRiskLevel: faultRiskLevel,
    overallRisk: overallRisk,
    recommendation: recommendation,
    isDemo: isDemo,
  );
}
