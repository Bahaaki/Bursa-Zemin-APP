import 'package:bursa_zemin/core/constants.dart';
import 'package:bursa_zemin/features/calculator/calculator_screen.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:bursa_zemin/features/map/widgets/ground_assessment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Widget buildTestableWidget({
    required Assessment assessment,
    required LatLng point,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GroundAssessmentSheet(
          assessment: assessment,
          point: point,
        ),
      ),
    );
  }

  const testPoint = LatLng(40.1932, 29.0611);

  group('GroundAssessmentSheet widget tests', () {
    testWidgets('renders Düşük risk level and all detail fields',
        (tester) async {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: '1',
          properties: {'birim': 'DEMO-1'},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-1',
          ad: 'Alüvyon Çökelleri',
          zeminTuru: 'Alüvyon',
          sismePotansiyeli: RiskLevel.dusuk,
          zeminRiski: RiskLevel.dusuk,
        ),
        nearestFault: const NearestFaultResult(
          name: 'Bursa Fayı',
          distanceKm: 6.2,
        ),
        faultRiskLevel: RiskLevel.dusuk,
        overallRisk: RiskLevel.dusuk,
        recommendation: 'Uygun (ön değerlendirme)',
        isDemo: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      // Header & Demo badge
      expect(find.text('Zemin Ön Değerlendirmesi'), findsOneWidget);
      expect(find.text('DEMO VERİ'), findsOneWidget);

      // Overall risk & recommendation
      expect(find.text('Genel Değerlendirme: Düşük'), findsOneWidget);
      expect(find.text('Uygun (ön değerlendirme)'), findsOneWidget);

      // Details
      expect(find.text('40.1932° K, 29.0611° D'), findsOneWidget);
      expect(find.text('DEMO-1 — Alüvyon Çökelleri'), findsOneWidget);
      expect(find.text('Alüvyon'), findsOneWidget);
      expect(find.text('Düşük'), findsOneWidget);
      expect(find.text('Bursa Fayı (6.2 km)'), findsOneWidget);
      expect(find.text('MTA, AFAD'), findsOneWidget);

      // Disclaimer
      expect(find.text(kDisclaimer), findsOneWidget);

      // Action buttons
      expect(find.text('SPT Hesabı'), findsOneWidget);
      expect(find.text('Rapor Oluştur (Yakında)'), findsOneWidget);
    });

    testWidgets('renders Orta risk level and recommendation', (tester) async {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: '2',
          properties: {'birim': 'DEMO-2'},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-2',
          ad: 'Gölsel Kireçtaşı',
          zeminTuru: 'Kaya',
          sismePotansiyeli: RiskLevel.orta,
          zeminRiski: RiskLevel.orta,
        ),
        nearestFault: const NearestFaultResult(
          name: 'Çekirge Fayı',
          distanceKm: 3.1,
        ),
        faultRiskLevel: RiskLevel.orta,
        overallRisk: RiskLevel.orta,
        recommendation: 'Dikkatli',
        isDemo: false,
      );

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      // Demo badge should NOT be present when isDemo is false
      expect(find.text('DEMO VERİ'), findsNothing);

      expect(find.text('Genel Değerlendirme: Orta'), findsOneWidget);
      expect(find.text('Dikkatli'), findsOneWidget);
      expect(find.text('DEMO-2 — Gölsel Kireçtaşı'), findsOneWidget);
      expect(find.text('Kaya'), findsOneWidget);
      expect(find.text('Orta'), findsOneWidget);
      expect(find.text('Çekirge Fayı (3.1 km)'), findsOneWidget);
    });

    testWidgets('renders Yüksek risk level and recommendation', (tester) async {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: '3',
          properties: {'birim': 'DEMO-3'},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-3',
          ad: 'Yumuşak Kil',
          zeminTuru: 'Kil',
          sismePotansiyeli: RiskLevel.yuksek,
          zeminRiski: RiskLevel.yuksek,
        ),
        nearestFault: const NearestFaultResult(
          name: 'Nilüfer Fayı',
          distanceKm: 0.7,
        ),
        faultRiskLevel: RiskLevel.yuksek,
        overallRisk: RiskLevel.yuksek,
        recommendation: 'Sondaj Gerekli',
        isDemo: false,
      );

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      expect(find.text('Genel Değerlendirme: Yüksek'), findsOneWidget);
      expect(find.text('Sondaj Gerekli'), findsOneWidget);
      expect(find.text('Nilüfer Fayı (0.7 km)'), findsOneWidget);
    });

    testWidgets('renders "Veri yok" when point is outside all polygons',
        (tester) async {
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

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      expect(find.text('Genel Değerlendirme'), findsOneWidget);
      expect(find.text('Veri yok – zemin etüdü gerekli'), findsNWidgets(2));
      expect(find.text('Veri yok'), findsNWidgets(2)); // soil type and swelling
      expect(find.text('Fay verisi yok'), findsOneWidget);
      expect(find.text(kDisclaimer), findsOneWidget);
    });

    testWidgets('renders "Fay verisi yok" when nearestFault is null',
        (tester) async {
      final assessment = Assessment(
        hasData: true,
        feature: GeoFeature(
          id: '1',
          properties: {'birim': 'DEMO-1'},
          shapes: [],
        ),
        classification: const ClassificationRow(
          birim: 'DEMO-1',
          ad: 'Alüvyon',
          zeminTuru: 'Alüvyon',
          sismePotansiyeli: RiskLevel.dusuk,
          zeminRiski: RiskLevel.dusuk,
        ),
        nearestFault: null,
        faultRiskLevel: null,
        overallRisk: RiskLevel.dusuk,
        recommendation: 'Uygun (ön değerlendirme)',
        isDemo: false,
      );

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      expect(find.text('Fay verisi yok'), findsOneWidget);
      expect(find.text('DEMO-1 — Alüvyon'), findsOneWidget);
      expect(find.text('Alüvyon'), findsOneWidget);
    });

    testWidgets('SPT button navigates to CalculatorScreen when tapped',
        (tester) async {
      const assessment = Assessment(
        hasData: false,
        recommendation: 'Veri yok – zemin etüdü gerekli',
      );

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      await tester.tap(find.text('SPT Hesabı'));
      await tester.pumpAndSettle();

      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.text('SPT Taşıma Gücü Hesabı'), findsOneWidget);
      expect(find.textContaining('40.1932° K'), findsOneWidget);
    });

    testWidgets('Rapor button shows "Yakında" snackbar when tapped',
        (tester) async {
      const assessment = Assessment(
        hasData: false,
        recommendation: 'Veri yok – zemin etüdü gerekli',
      );

      await tester.pumpWidget(
        buildTestableWidget(assessment: assessment, point: testPoint),
      );

      await tester.tap(find.text('Rapor Oluştur (Yakında)'));
      await tester.pump();
      expect(find.text('Rapor oluşturma özelliği yakında eklenecektir (P7)'),
          findsOneWidget);
    });
  });
}
