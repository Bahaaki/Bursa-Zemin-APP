import 'models.dart';

/// Distance thresholds from assets/config/risk_rules.json (or defaults).
class FaultDistanceRules {
  final double yuksekMaxKm;
  final double ortaMaxKm;

  const FaultDistanceRules({
    this.yuksekMaxKm = 1.0,
    this.ortaMaxKm = 5.0,
  });

  factory FaultDistanceRules.fromJson(Map<String, dynamic> json) {
    final faultDist = json['fault_distance_km'] as Map<String, dynamic>?;
    if (faultDist == null) {
      return const FaultDistanceRules();
    }
    return FaultDistanceRules(
      yuksekMaxKm: (faultDist['yuksek_max'] as num?)?.toDouble() ?? 1.0,
      ortaMaxKm: (faultDist['orta_max'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

/// Classifies a fault distance into [RiskLevel] according to [rules] (SPEC §2).
///
/// - `d <= yuksek_max` -> Yüksek
/// - `d <= orta_max`   -> Orta
/// - else              -> Düşük
RiskLevel classifyFaultDistance(double distanceKm, FaultDistanceRules rules) {
  if (distanceKm <= rules.yuksekMaxKm) {
    return RiskLevel.yuksek;
  } else if (distanceKm <= rules.ortaMaxKm) {
    return RiskLevel.orta;
  } else {
    return RiskLevel.dusuk;
  }
}
