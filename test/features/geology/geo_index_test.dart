import 'package:bursa_zemin/features/geology/domain/geo_index.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoIndex point lookup', () {
    // Square A: (40.0..40.2, 29.0..29.2) -> Low risk
    final featureLow = GeoFeature(
      id: 'feat-low',
      properties: {'birim': 'UNIT-LOW'},
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

    // Square B: overlapping (40.1..40.3, 29.1..29.3) -> High risk
    final featureHigh = GeoFeature(
      id: 'feat-high',
      properties: {'birim': 'UNIT-HIGH'},
      shapes: [
        PolygonShape(
          outerRing: const [
            LatLng(40.1, 29.1),
            LatLng(40.3, 29.1),
            LatLng(40.3, 29.3),
            LatLng(40.1, 29.3),
            LatLng(40.1, 29.1),
          ],
          holes: const [],
        )
      ],
    );

    // Square C: overlapping (40.1..40.3, 29.1..29.3) -> Medium risk
    final featureMedium = GeoFeature(
      id: 'feat-medium',
      properties: {'birim': 'UNIT-MED'},
      shapes: [
        PolygonShape(
          outerRing: const [
            LatLng(40.1, 29.1),
            LatLng(40.3, 29.1),
            LatLng(40.3, 29.3),
            LatLng(40.1, 29.3),
            LatLng(40.1, 29.1),
          ],
          holes: const [],
        )
      ],
    );

    final classificationMap = {
      'UNIT-LOW': const ClassificationRow(
        birim: 'UNIT-LOW',
        ad: 'Low Risk Unit',
        zeminTuru: 'Kaya',
        sismePotansiyeli: RiskLevel.dusuk,
        zeminRiski: RiskLevel.dusuk,
      ),
      'UNIT-MED': const ClassificationRow(
        birim: 'UNIT-MED',
        ad: 'Medium Risk Unit',
        zeminTuru: 'Kum',
        sismePotansiyeli: RiskLevel.orta,
        zeminRiski: RiskLevel.orta,
      ),
      'UNIT-HIGH': const ClassificationRow(
        birim: 'UNIT-HIGH',
        ad: 'High Risk Unit',
        zeminTuru: 'Alüvyon',
        sismePotansiyeli: RiskLevel.yuksek,
        zeminRiski: RiskLevel.yuksek,
      ),
    };

    test('point in single feature returns that feature', () {
      final index = GeoIndex(
        features: [featureLow, featureHigh],
        classifications: classificationMap,
      );

      // Point only inside featureLow: (40.05, 29.05)
      final match = index.findAt(const LatLng(40.05, 29.05));
      expect(match, isNotNull);
      expect(match!.birim, equals('UNIT-LOW'));
    });

    test(
        'point in overlapping features selects the one with the highest zemin_riski',
        () {
      final index = GeoIndex(
        features: [featureLow, featureMedium, featureHigh],
        classifications: classificationMap,
      );

      // Overlap point: (40.15, 29.15) is inside featureLow, featureMedium, and featureHigh
      final match = index.findAt(const LatLng(40.15, 29.15));
      expect(match, isNotNull);
      // High risk wins (conservative per SPEC §2)
      expect(match!.birim, equals('UNIT-HIGH'));
    });

    test('point outside all features returns null', () {
      final index = GeoIndex(
        features: [featureLow, featureHigh],
        classifications: classificationMap,
      );

      final match = index.findAt(const LatLng(41.0, 30.0));
      expect(match, isNull);
    });
  });
}
