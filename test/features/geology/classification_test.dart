import 'dart:io';
import 'package:bursa_zemin/features/geology/domain/classification.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classification CSV parser', () {
    test('parses demo classification CSV correctly', () {
      final csvContent =
          File('assets/demo/classification_demo.csv').readAsStringSync();
      final map = parseClassificationCsv(csvContent);

      expect(map.length, equals(5));
      expect(map.keys,
          containsAll({'DEMO-1', 'DEMO-2', 'DEMO-3', 'DEMO-4', 'DEMO-5'}));

      final demo1 = map['DEMO-1']!;
      expect(demo1.birim, equals('DEMO-1'));
      expect(demo1.ad, equals('Demo Birim 1 (Kil)'));
      expect(demo1.zeminTuru, equals('Kil'));
      expect(demo1.sismePotansiyeli, equals(RiskLevel.yuksek));
      expect(demo1.zeminRiski, equals(RiskLevel.yuksek));

      final demo2 = map['DEMO-2']!;
      expect(demo2.zeminTuru, equals('Kum'));
      expect(demo2.sismePotansiyeli, equals(RiskLevel.orta));
      expect(demo2.zeminRiski, equals(RiskLevel.orta));

      final demo3 = map['DEMO-3']!;
      expect(demo3.zeminTuru, equals('Kaya'));
      expect(demo3.sismePotansiyeli, equals(RiskLevel.dusuk));
      expect(demo3.zeminRiski, equals(RiskLevel.dusuk));
    });

    test('throws ClassificationParseException on header mismatch', () {
      const badHeaderCsv =
          'birim,ad,wrong_col,sisme_potansiyeli,zemin_riski\nDEMO-1,Ad,Kil,Orta,Orta';
      expect(
        () => parseClassificationCsv(badHeaderCsv),
        throwsA(isA<ClassificationParseException>().having(
          (e) => e.message,
          'message',
          contains('Header mismatch'),
        )),
      );
    });

    test('throws ClassificationParseException on bad zemin_turu enum', () {
      const badCsv =
          'birim,ad,zemin_turu,sisme_potansiyeli,zemin_riski\nDEMO-1,Ad,Toprak,Orta,Orta';
      expect(
        () => parseClassificationCsv(badCsv),
        throwsA(isA<ClassificationParseException>().having(
          (e) => e.message,
          'message',
          contains('Toprak'),
        )),
      );
    });

    test('throws ClassificationParseException on bad sisme_potansiyeli enum',
        () {
      const badCsv =
          'birim,ad,zemin_turu,sisme_potansiyeli,zemin_riski\nDEMO-1,Ad,Kil,Bilinmeyen,Orta';
      expect(
        () => parseClassificationCsv(badCsv),
        throwsA(isA<ClassificationParseException>().having(
          (e) => e.message,
          'message',
          contains('Bilinmeyen'),
        )),
      );
    });

    test('throws ClassificationParseException on bad zemin_riski enum', () {
      const badCsv =
          'birim,ad,zemin_turu,sisme_potansiyeli,zemin_riski\nDEMO-1,Ad,Kil,Orta,VeryHigh';
      expect(
        () => parseClassificationCsv(badCsv),
        throwsA(isA<ClassificationParseException>().having(
          (e) => e.message,
          'message',
          contains('VeryHigh'),
        )),
      );
    });

    test('throws ClassificationParseException when row has missing column', () {
      const badCsv =
          'birim,ad,zemin_turu,sisme_potansiyeli,zemin_riski\nDEMO-1,Ad,Kil,Orta';
      expect(
        () => parseClassificationCsv(badCsv),
        throwsA(isA<ClassificationParseException>().having(
          (e) => e.message,
          'message',
          contains('5 columns'),
        )),
      );
    });
  });
}
