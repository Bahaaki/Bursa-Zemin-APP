import 'dart:io';
import 'dart:typed_data';

import 'package:bursa_zemin/core/constants.dart';
import 'package:bursa_zemin/features/calculator/domain/spt_calculator.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:bursa_zemin/features/report/pdf_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  late PdfFontPair testFonts;
  late Uint8List samplePngBytes;

  setUpAll(() async {
    // 1. Load local OFL Noto Sans TrueType fonts
    final regularFile = File('assets/fonts/NotoSans-Regular.ttf');
    final boldFile = File('assets/fonts/NotoSans-Bold.ttf');
    final italicFile = File('assets/fonts/NotoSans-Italic.ttf');

    expect(regularFile.existsSync(), isTrue,
        reason: 'NotoSans-Regular.ttf must exist in assets/fonts/');
    expect(boldFile.existsSync(), isTrue,
        reason: 'NotoSans-Bold.ttf must exist in assets/fonts/');
    expect(italicFile.existsSync(), isTrue,
        reason: 'NotoSans-Italic.ttf must exist in assets/fonts/');

    final regBytes = await regularFile.readAsBytes();
    final boldBytes = await boldFile.readAsBytes();
    final itlBytes = await italicFile.readAsBytes();

    testFonts = PdfFontPair(
      regular: pw.Font.ttf(regBytes.buffer.asByteData()),
      bold: pw.Font.ttf(boldBytes.buffer.asByteData()),
      italic: pw.Font.ttf(itlBytes.buffer.asByteData()),
    );

    // 2. Load valid test PNG fixture for map snapshot testing
    final pngFile = File('test/fixtures/sample_map.png');
    expect(pngFile.existsSync(), isTrue);
    samplePngBytes = await pngFile.readAsBytes();
    expect(samplePngBytes.isNotEmpty, isTrue);
  });

  group('ReportTextData builder & Golden String tests', () {
    test('buildReportTextData generates exact deterministic golden string', () {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: 'feature-1',
          properties: {'birim': 'DEMO-1', 'demo': true},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-1',
          ad: 'Alüvyon Çökelleri',
          zeminTuru: 'Alüvyon',
          sismePotansiyeli: RiskLevel.yuksek,
          zeminRiski: RiskLevel.orta,
        ),
        nearestFault: const NearestFaultResult(
          name: 'Bursa Fayı',
          distanceKm: 2.34,
        ),
        faultRiskLevel: RiskLevel.orta,
        overallRisk: RiskLevel.yuksek,
        recommendation: 'Sondaj Gerekli',
        isDemo: true,
      );

      const bearingResult = BearingResult(
        soilKind: SoilKind.kum,
        nValue: 15,
        effectiveN: 15.0,
        phiDeg: 31.48,
        nc: 42.15,
        nq: 27.82,
        ng: 26.54,
        q: 27.0,
        qUlt: 1142.3,
        qAll: 380.8,
        footingShape: FootingShape.kare,
        b: 2.0,
        df: 1.5,
        gamma: 18.0,
        fs: 3.0,
        warnings: ['Yeraltı su seviyesi dikkate alınmamıştır.'],
      );

      final reportData = buildReportTextData(
        assessment: assessment,
        coordinates: const LatLng(40.1885, 29.0610),
        bearingResult: bearingResult,
        date: DateTime(2026, 9, 26, 14, 30),
        developerName: 'Ahmed',
      );

      const expectedGoldenString = '''
=== Bursa Zemin – Ön Zemin Değerlendirme Raporu ===
Tarih: 26.09.2026 14:30
Koordinat: 40.1885° K, 29.0610° D

--- ZEMİN ÖN DEĞERLENDİRMESİ ---
Jeolojik Birim: DEMO-1
Zemin Türü: Alüvyon
Şişme Potansiyeli: Yüksek
En Yakın Fay: Bursa Fayı (2.34 km)
Fay Risk Düzeyi: Orta
Genel Değerlendirme: Yüksek
Öneri: Sondaj Gerekli
Uyarı: DEMO VERİ - Gerçek saha verisi değildir.

--- SPT TAŞIMA GÜCÜ HESABI (TERZAGHI) ---
Zemin Türü: Kum (Kohezyonsuz)
SPT-N: 15 (Düzeltilmiş N: 15.0)
Temel Geometrisi: Kare (B: 2.00 m, Df: 1.50 m)
Zemin Parametreleri: Birim Hacim Ağırlık γ: 18.0 kN/m³, Güvenlik Sayısı FS: 3.0
İçsel Sürtünme Açısı φ: 31.48°
Taşıma Gücü Katsayıları: Nc: 42.15, Nq: 27.82, Nγ: 26.54
Sürşarj Basıncı q: 27.0 kPa
Nihai Taşıma Gücü q_ult: 1142.3 kPa
Emniyetli Taşıma Gücü q_all: 380.8 kPa
Hesap Uyarıları:
  - Yeraltı su seviyesi dikkate alınmamıştır.

Yasal Uyarı: Ön değerlendirmedir, zemin etüdünün yerine geçmez.
Veri Kaynakları: MTA, AFAD, OpenStreetMap
Geliştirici: Ahmed
''';

      final actualText = reportData.toPlainText();
      expect(actualText, equals(expectedGoldenString));

      // Explicit verification of Turkish characters in source strings
      expect(reportData.swellingPotential, equals('Yüksek'));
      expect(reportData.disclaimer, equals(kDisclaimer));
      expect(reportData.sources, equals(kSources));
      expect(reportData.developer, equals('Geliştirici: Ahmed'));
      expect(actualText, contains('Şişme Potansiyeli: Yüksek'));
      expect(actualText,
          contains('Ön değerlendirmedir, zemin etüdünün yerine geçmez.'));
    });

    test('buildReportTextData handles outside-polygons ("Veri yok") assessment',
        () {
      const assessment = Assessment(
        hasData: false,
        feature: null,
        classification: null,
        nearestFault: null,
        faultRiskLevel: null,
        overallRisk: null,
        recommendation: 'Veri yok – zemin etüdü gerekli',
        isDemo: false,
      );

      final reportData = buildReportTextData(
        assessment: assessment,
        coordinates: const LatLng(40.1000, 29.0000),
        date: DateTime(2026, 9, 26, 12, 0),
        developerName: 'Ahmed',
      );

      final text = reportData.toPlainText();
      expect(reportData.geologyUnit, equals('Veri yok'));
      expect(reportData.soilType, equals('Veri yok'));
      expect(reportData.swellingPotential, equals('Veri yok'));
      expect(reportData.nearestFault, equals('Fay verisi yok'));
      expect(reportData.overallRiskLevel, equals('Veri yok'));
      expect(
          reportData.recommendation, equals('Veri yok – zemin etüdü gerekli'));
      expect(reportData.bearing, isNull);
      expect(text, contains('Genel Değerlendirme: Veri yok'));
      expect(text, contains('Öneri: Veri yok – zemin etüdü gerekli'));
    });
  });

  group('PDF Document Rendering & Structure tests (SPEC §6)', () {
    test(
        'generates valid PDF bytes starting with %PDF for full assessment and bearing',
        () async {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: 'f1',
          properties: {'birim': 'DEMO-1'},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-1',
          ad: 'Alüvyon Çökelleri',
          zeminTuru: 'Alüvyon',
          sismePotansiyeli: RiskLevel.yuksek,
          zeminRiski: RiskLevel.orta,
        ),
        nearestFault: const NearestFaultResult(
          name: 'Bursa Fayı',
          distanceKm: 1.85,
        ),
        faultRiskLevel: RiskLevel.orta,
        overallRisk: RiskLevel.yuksek,
        recommendation: 'Sondaj Gerekli',
        isDemo: true,
      );

      const bearingResult = BearingResult(
        soilKind: SoilKind.kum,
        nValue: 20,
        effectiveN: 20.0,
        phiDeg: 32.88,
        nc: 47.60,
        nq: 31.77,
        ng: 32.79,
        q: 27.0,
        qUlt: 1330.1,
        qAll: 443.4,
        footingShape: FootingShape.kare,
        b: 2.0,
        df: 1.5,
        gamma: 18.0,
        fs: 3.0,
        warnings: ['Yeraltı su seviyesi dikkate alınmamıştır.'],
      );

      final reportData = buildReportTextData(
        assessment: assessment,
        coordinates: const LatLng(40.1932, 29.0611),
        bearingResult: bearingResult,
        developerName: 'Ahmed',
      );

      final pdfDoc = buildPdfDocument(
        reportData: reportData,
        mapImageBytes: samplePngBytes,
        fonts: testFonts,
        compress: false,
      );

      // Verify single A4 page constraint (SPEC §6: single A4 page)
      expect(pdfDoc.document.catalog.pdfPageList.pages.length, equals(1));

      final bytes = await pdfDoc.save();

      // Assert non-empty and starts with %PDF
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, greaterThan(5000));
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, equals('%PDF'));

      // Assert uncompressed PDF contains the TrueType font name
      final rawPdfText = String.fromCharCodes(bytes);
      expect(rawPdfText, contains('NotoSans'));

      // Write sample PDF to build/ for manual inspection and verification
      final buildDir = Directory('build');
      if (!buildDir.existsSync()) {
        buildDir.createSync(recursive: true);
      }
      final samplePdfFile = File('build/bursa_zemin_ornek_rapor.pdf');
      await samplePdfFile.writeAsBytes(bytes);
      expect(samplePdfFile.existsSync(), isTrue);
      expect(samplePdfFile.lengthSync(), greaterThan(5000));
    });

    test('generates valid PDF when map snapshot capture fails (null bytes)',
        () async {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: 'f2',
          properties: {'birim': 'DEMO-2'},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-2',
          ad: 'Gölsel Kireçtaşı',
          zeminTuru: 'Kaya',
          sismePotansiyeli: RiskLevel.dusuk,
          zeminRiski: RiskLevel.dusuk,
        ),
        nearestFault: const NearestFaultResult(
          name: 'Nilüfer Fayı',
          distanceKm: 7.5,
        ),
        faultRiskLevel: RiskLevel.dusuk,
        overallRisk: RiskLevel.dusuk,
        recommendation: 'Uygun (ön değerlendirme)',
        isDemo: false,
      );

      final reportData = buildReportTextData(
        assessment: assessment,
        coordinates: const LatLng(40.2000, 29.0500),
        developerName: 'Ahmed',
      );

      final pdfDoc = buildPdfDocument(
        reportData: reportData,
        mapImageBytes: null, // Simulated snapshot failure
        fonts: testFonts,
        compress: false,
      );

      expect(pdfDoc.document.catalog.pdfPageList.pages.length, equals(1));

      final bytes = await pdfDoc.save();
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    });
  });
}
