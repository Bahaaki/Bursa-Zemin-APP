import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bursa_zemin/features/calculator/domain/spt_calculator.dart';

void main() {
  group('SPEC §4 (a) - Bearing capacity factors at phi = 0', () {
    test('phi=0 yields Nc=5.7, Nq=1.0, Ng=0.0', () {
      final nq = SptCalculator.calculateNq(0.0);
      final nc = SptCalculator.calculateNc(0.0, nq);
      final ng = SptCalculator.interpolateNgamma(0.0);

      expect(nq, equals(1.0));
      expect(nc, equals(5.7));
      expect(ng, equals(0.0));
    });
  });

  group('SPEC §4 (b) - Bearing capacity factors at phi = 30°', () {
    test('phi=30° yields Nc approx 37.2 (±0.2) and Nq approx 22.5 (±0.2)', () {
      final nq = SptCalculator.calculateNq(30.0);
      final nc = SptCalculator.calculateNc(30.0, nq);
      final ng = SptCalculator.interpolateNgamma(30.0);

      expect(nq, closeTo(22.5, 0.2));
      expect(nc, closeTo(37.2, 0.2));
      expect(ng, equals(19.7));
    });
  });

  group('SPEC §4 (c) - Three reference cases from bearing_reference.json', () {
    test('all reference cases match within stated tolerances', () {
      final file = File('test/fixtures/bearing_reference.json');
      expect(file.existsSync(), isTrue,
          reason: 'bearing_reference.json fixture must exist');

      final rawJson = file.readAsStringSync();
      final fixtureList = jsonDecode(rawJson) as List<dynamic>;

      expect(fixtureList.length, equals(3),
          reason: 'Fixture must contain exactly 3 reference cases');

      for (final item in fixtureList) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String;
        final soilKind = SoilKind.fromString(map['soil_kind'] as String);
        final nValue = map['n_value'] as int;
        final nCorrection = (map['n_correction'] as num?)?.toDouble() ?? 1.0;
        final footingShape =
            FootingShape.fromString(map['footing_shape'] as String);
        final bM = (map['b_m'] as num).toDouble();
        final dfM = (map['df_m'] as num).toDouble();
        final gamma = (map['gamma_kn_m3'] as num).toDouble();
        final fs = (map['fs'] as num).toDouble();

        final expectedQUlt = (map['expected_q_ult_kpa'] as num).toDouble();
        final expectedQAll = (map['expected_q_all_kpa'] as num).toDouble();
        final tolerancePercent = (map['tolerance_percent'] as num).toDouble();

        final input = BearingInput(
          soilKind: soilKind,
          nValue: nValue,
          nCorrection: nCorrection,
          footingShape: footingShape,
          b: bM,
          df: dfM,
          gamma: gamma,
          fs: fs,
        );

        final result = SptCalculator.calculate(input);

        // Check tolerance bounds: |actual - expected| / expected <= tolerancePercent / 100
        final qUltDiffPercent =
            ((result.qUlt - expectedQUlt).abs() / expectedQUlt) * 100.0;
        final qAllDiffPercent =
            ((result.qAll - expectedQAll).abs() / expectedQAll) * 100.0;

        expect(
          qUltDiffPercent,
          lessThanOrEqualTo(tolerancePercent),
          reason:
              '$id: q_ult ${result.qUlt} differs from expected $expectedQUlt by $qUltDiffPercent%, exceeding tolerance $tolerancePercent%',
        );

        expect(
          qAllDiffPercent,
          lessThanOrEqualTo(tolerancePercent),
          reason:
              '$id: q_all ${result.qAll} differs from expected $expectedQAll by $qAllDiffPercent%, exceeding tolerance $tolerancePercent%',
        );
      }
    });
  });

  group('SPEC §4 (d) - Monotonicity: q_ult increases with N', () {
    test('q_ult increases monotonically with N for granular soil', () {
      double? prevQUlt;
      for (int n = 1; n <= 50; n++) {
        final result = SptCalculator.calculate(BearingInput(
          soilKind: SoilKind.kum,
          nValue: n,
          footingShape: FootingShape.kare,
          b: 2.0,
          df: 1.0,
        ));

        if (prevQUlt != null) {
          expect(result.qUlt, greaterThan(prevQUlt),
              reason:
                  'q_ult must increase when N increases from ${n - 1} to $n');
        }
        prevQUlt = result.qUlt;
      }
    });

    test('q_ult increases monotonically with N for cohesive soil', () {
      double? prevQUlt;
      for (int n = 1; n <= 50; n++) {
        final result = SptCalculator.calculate(BearingInput(
          soilKind: SoilKind.kil,
          nValue: n,
          footingShape: FootingShape.kare,
          b: 2.0,
          df: 1.0,
        ));

        if (prevQUlt != null) {
          expect(result.qUlt, greaterThan(prevQUlt),
              reason:
                  'q_ult must increase when N increases from ${n - 1} to $n');
        }
        prevQUlt = result.qUlt;
      }
    });
  });

  group('SPEC §4 (e) - Input validation errors', () {
    test('rejects N < 1', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 0,
          footingShape: FootingShape.serit,
          b: 1.0,
          df: 1.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });

    test('rejects N > 100', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 101,
          footingShape: FootingShape.serit,
          b: 1.0,
          df: 1.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });

    test('rejects B <= 0', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 10,
          footingShape: FootingShape.serit,
          b: 0.0,
          df: 1.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 10,
          footingShape: FootingShape.serit,
          b: -1.0,
          df: 1.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });

    test('rejects Df < 0', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 10,
          footingShape: FootingShape.serit,
          b: 1.0,
          df: -0.5,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });

    test('rejects gamma <= 0', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 10,
          footingShape: FootingShape.serit,
          b: 1.0,
          df: 1.0,
          gamma: 0.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });

    test('rejects FS <= 0', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 10,
          footingShape: FootingShape.serit,
          b: 1.0,
          df: 1.0,
          fs: 0.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });

    test('rejects nCorrection <= 0', () {
      expect(
        () => SptCalculator.calculate(const BearingInput(
          soilKind: SoilKind.kum,
          nValue: 10,
          footingShape: FootingShape.serit,
          b: 1.0,
          df: 1.0,
          nCorrection: 0.0,
        )),
        throwsA(isA<BearingCapacityException>()),
      );
    });
  });

  group('Warnings and Disclaimers', () {
    test('contains water table and soil kind warnings', () {
      final result = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kum,
        nValue: 15,
        footingShape: FootingShape.kare,
        b: 2.0,
        df: 1.0,
      ));

      expect(
        result.warnings.any((w) => w.contains('su seviyesi')),
        isTrue,
        reason: 'Must include water table warning',
      );
      expect(
        result.warnings.any((w) => w.contains('zemin türü')),
        isTrue,
        reason: 'Must include soil kind correlation warning',
      );
    });

    test('N > 50 triggers refüsü warning', () {
      final normalResult = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kum,
        nValue: 50,
        footingShape: FootingShape.kare,
        b: 2.0,
        df: 1.0,
      ));
      expect(normalResult.warnings.any((w) => w.contains('refüs')), isFalse);

      final refuseResult = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kum,
        nValue: 51,
        footingShape: FootingShape.kare,
        b: 2.0,
        df: 1.0,
      ));
      expect(refuseResult.warnings.any((w) => w.contains('refüs')), isTrue);
    });
  });

  group('Footing shape factors effect', () {
    test(
        'Strip vs Square vs Circular formulas apply correct shape coefficients',
        () {
      // In clay (c_u = 60, q = 0, Df = 0):
      // Strip: q_ult = c*Nc = 60 * 5.7 = 342.0
      // Square: q_ult = 1.3 * c*Nc = 1.3 * 342 = 444.6
      // Circular: q_ult = 1.3 * c*Nc = 1.3 * 342 = 444.6
      final stripClay = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kil,
        nValue: 10,
        footingShape: FootingShape.serit,
        b: 1.0,
        df: 0.0,
      ));
      final squareClay = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kil,
        nValue: 10,
        footingShape: FootingShape.kare,
        b: 1.0,
        df: 0.0,
      ));
      final circularClay = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kil,
        nValue: 10,
        footingShape: FootingShape.dairesel,
        b: 1.0,
        df: 0.0,
      ));

      expect(stripClay.qUlt, closeTo(342.0, 0.01));
      expect(squareClay.qUlt, closeTo(444.6, 0.01));
      expect(circularClay.qUlt, closeTo(444.6, 0.01));

      // In sand with Df=0:
      // Strip: q_ult = 0.5 * gamma * B * Ng
      // Square: q_ult = 0.4 * gamma * B * Ng
      // Circular: q_ult = 0.3 * gamma * B * Ng
      final stripSand = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kum,
        nValue: 10,
        footingShape: FootingShape.serit,
        b: 2.0,
        df: 0.0,
      ));
      final squareSand = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kum,
        nValue: 10,
        footingShape: FootingShape.kare,
        b: 2.0,
        df: 0.0,
      ));
      final circularSand = SptCalculator.calculate(const BearingInput(
        soilKind: SoilKind.kum,
        nValue: 10,
        footingShape: FootingShape.dairesel,
        b: 2.0,
        df: 0.0,
      ));

      expect(squareSand.qUlt, lessThan(stripSand.qUlt));
      expect(circularSand.qUlt, lessThan(squareSand.qUlt));
      expect(squareSand.qUlt / stripSand.qUlt, closeTo(0.4 / 0.5, 0.01));
      expect(circularSand.qUlt / stripSand.qUlt, closeTo(0.3 / 0.5, 0.01));
    });
  });
}
