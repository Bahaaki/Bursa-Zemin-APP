import 'package:bursa_zemin/features/geology/domain/assessment.dart';
import 'package:bursa_zemin/features/geology/domain/geo_index.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:bursa_zemin/features/geology/domain/risk_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('calculateOverallRisk helper', () {
    test('computes max of zemin_riski, sisme_potansiyeli, faultRiskLevel', () {
      // All combinations test
      final levels = [RiskLevel.dusuk, RiskLevel.orta, RiskLevel.yuksek];

      for (final z in levels) {
        for (final s in levels) {
          for (final f in levels) {
            final expectedMax = [z, s, f].reduce((a, b) => a >= b ? a : b);
            final overall = calculateOverallRisk(
                zeminRiski: z, sismePotansiyeli: s, faultLevel: f);
            expect(overall, equals(expectedMax),
                reason: 'Failed for zemin=$z, sisme=$s, fault=$f');
          }
        }
      }
    });

    test('ignores faultRiskLevel when it is null (unknown fault)', () {
      expect(
        calculateOverallRisk(
          zeminRiski: RiskLevel.dusuk,
          sismePotansiyeli: RiskLevel.orta,
          faultLevel: null,
        ),
        equals(RiskLevel.orta),
      );

      expect(
        calculateOverallRisk(
          zeminRiski: RiskLevel.dusuk,
          sismePotansiyeli: RiskLevel.dusuk,
          faultLevel: null,
        ),
        equals(RiskLevel.dusuk),
      );

      expect(
        calculateOverallRisk(
          zeminRiski: RiskLevel.yuksek,
          sismePotansiyeli: RiskLevel.dusuk,
          faultLevel: null,
        ),
        equals(RiskLevel.yuksek),
      );
    });
  });

  group('recommendation texts', () {
    test('maps risk levels to exact SPEC §2 strings', () {
      expect(getRecommendation(RiskLevel.dusuk),
          equals('Uygun (ön değerlendirme)'));
      expect(getRecommendation(RiskLevel.orta), equals('Dikkatli'));
      expect(getRecommendation(RiskLevel.yuksek), equals('Sondaj Gerekli'));
      expect(getRecommendation(null), equals('Veri yok – zemin etüdü gerekli'));
    });
  });

  group('fault distance risk classification', () {
    const rules = FaultDistanceRules(yuksekMaxKm: 1.0, ortaMaxKm: 5.0);

    test('d <= 1.0 km -> Yüksek', () {
      expect(classifyFaultDistance(0.5, rules), equals(RiskLevel.yuksek));
      expect(classifyFaultDistance(1.0, rules), equals(RiskLevel.yuksek));
    });

    test('1.0 < d <= 5.0 km -> Orta', () {
      expect(classifyFaultDistance(1.01, rules), equals(RiskLevel.orta));
      expect(classifyFaultDistance(3.0, rules), equals(RiskLevel.orta));
      expect(classifyFaultDistance(5.0, rules), equals(RiskLevel.orta));
    });

    test('d > 5.0 km -> Düşük', () {
      expect(classifyFaultDistance(5.01, rules), equals(RiskLevel.dusuk));
      expect(classifyFaultDistance(10.0, rules), equals(RiskLevel.dusuk));
    });
  });

  group('full assess function', () {
    final feature = GeoFeature(
      id: 'f1',
      properties: {'birim': 'DEMO-1', 'demo': true},
      shapes: [
        PolygonShape(
          outerRing: const [
            LatLng(40.0, 29.0),
            LatLng(40.2, 29.0),
            LatLng(40.2, 29.2),
            LatLng(40.0, 29.2),
            LatLng(40.0, 29.0),
          ],
          holes: const [],
        )
      ],
    );

    final classificationMap = {
      'DEMO-1': const ClassificationRow(
        birim: 'DEMO-1',
        ad: 'Demo Kil',
        zeminTuru: 'Kil',
        sismePotansiyeli: RiskLevel.dusuk,
        zeminRiski: RiskLevel.dusuk,
      ),
    };

    final geoIndex =
        GeoIndex(features: [feature], classifications: classificationMap);
    const faultRules = FaultDistanceRules(yuksekMaxKm: 1.0, ortaMaxKm: 5.0);

    const faultNear = FaultLine(
      name: 'Yakın Fay',
      lines: [
        [LatLng(40.1, 28.995), LatLng(40.1, 29.005)]
      ],
    );

    test('point outside all polygons returns "Veri yok – zemin etüdü gerekli"',
        () {
      final assessment = assess(
        point: const LatLng(45.0, 35.0),
        geoIndex: geoIndex,
        faults: [faultNear],
        faultRules: faultRules,
      );

      expect(assessment.hasData, isFalse);
      expect(assessment.feature, isNull);
      expect(assessment.classification, isNull);
      expect(assessment.overallRisk, isNull);
      expect(
          assessment.recommendation, equals('Veri yok – zemin etüdü gerekli'));
    });

    test('point inside polygon with nearby fault takes fault risk (Yüksek)',
        () {
      // Point at (40.1, 29.006) is ~0.1 km from faultNear -> fault level Yüksek
      final assessment = assess(
        point: const LatLng(40.1, 29.006),
        geoIndex: geoIndex,
        faults: [faultNear],
        faultRules: faultRules,
      );

      expect(assessment.hasData, isTrue);
      expect(assessment.feature, isNotNull);
      expect(assessment.classification, isNotNull);
      expect(assessment.faultRiskLevel, equals(RiskLevel.yuksek));
      // Soil is dusuk, sisme is dusuk, fault is yuksek -> overall yuksek
      expect(assessment.overallRisk, equals(RiskLevel.yuksek));
      expect(assessment.recommendation, equals('Sondaj Gerekli'));
      expect(assessment.isDemo, isTrue);
    });

    test(
        'point inside polygon with NO fault data sets faultLevel to null and calculates overall without it',
        () {
      final assessment = assess(
        point: const LatLng(40.1, 29.05),
        geoIndex: geoIndex,
        faults: null, // No fault data loaded
        faultRules: faultRules,
      );

      expect(assessment.hasData, isTrue);
      expect(assessment.nearestFault, isNull);
      expect(assessment.faultRiskLevel, isNull);
      // Soil is dusuk, sisme is dusuk, fault is null -> overall dusuk
      expect(assessment.overallRisk, equals(RiskLevel.dusuk));
      expect(assessment.recommendation, equals('Uygun (ön değerlendirme)'));
    });
  });
}
