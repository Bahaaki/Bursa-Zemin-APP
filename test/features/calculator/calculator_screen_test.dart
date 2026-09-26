import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:bursa_zemin/core/constants.dart';
import 'package:bursa_zemin/features/calculator/calculator_screen.dart';
import 'package:bursa_zemin/features/calculator/domain/spt_calculator.dart';

void main() {
  Widget buildTestableScreen({
    LatLng? initialCoordinates,
    List<SptSample>? initialSamples,
  }) {
    return MaterialApp(
      home: CalculatorScreen(
        initialCoordinates: initialCoordinates,
        initialSamples: initialSamples ??
            const [
              SptSample(
                id: 'test-spt-01',
                depthM: 2.5,
                nValue: 18,
                soil: SoilKind.kum,
                isDemo: true,
              ),
              SptSample(
                id: 'test-spt-02',
                depthM: 1.5,
                nValue: 10,
                soil: SoilKind.kil,
                isDemo: false,
              ),
            ],
      ),
    );
  }

  group('CalculatorScreen widget tests', () {
    testWidgets('renders all initial fields, results, and disclaimer',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('SPT Taşıma Gücü Hesabı'), findsOneWidget);
      expect(find.text('Zemin ve Temel Parametreleri'), findsOneWidget);
      expect(find.text('Kum (Kohezyonsuz)'), findsOneWidget);
      expect(find.text('Kil (Kohezyonlu)'), findsOneWidget);
      expect(find.text('Şerit'), findsOneWidget);
      expect(find.text('Kare'), findsOneWidget);
      expect(find.text('Dairesel'), findsOneWidget);

      // Default inputs exist
      expect(find.byKey(const ValueKey('n_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('b_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('df_input')), findsOneWidget);

      // Default calculation result is rendered (q_all, q_ult)
      expect(find.byKey(const ValueKey('q_all_result')), findsOneWidget);
      expect(find.byKey(const ValueKey('q_ult_result')), findsOneWidget);

      // Intermediate values section
      expect(find.text('Hesaplanan Ara Değerler'), findsOneWidget);
      expect(find.text('Nc Katsayısı'), findsOneWidget);
      expect(find.text('Nq Katsayısı'), findsOneWidget);
      expect(find.text('Nγ Katsayısı'), findsOneWidget);

      // Warnings section
      expect(find.text('Önemli Uyarılar'), findsOneWidget);
      expect(find.textContaining('su seviyesi'), findsOneWidget);

      // Legal disclaimer (R10)
      expect(find.text(kDisclaimer), findsOneWidget);
    });

    testWidgets('displays prefilled map coordinates when provided',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const coords = LatLng(40.1932, 29.0611);
      await tester.pumpWidget(
        buildTestableScreen(initialCoordinates: coords),
      );
      await tester.pumpAndSettle();

      expect(find.text('Seçilen Konum Koordinatı'), findsOneWidget);
      expect(find.textContaining('40.1932° K'), findsOneWidget);
      expect(find.textContaining('29.0611° D'), findsOneWidget);
    });

    testWidgets('enter values -> result updates live (Reference Case 3)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Enter N=20, B=2.0, Df=1.5 (Sand, Square)
      final nFinder = find.byKey(const ValueKey('n_input'));
      final bFinder = find.byKey(const ValueKey('b_input'));
      final dfFinder = find.byKey(const ValueKey('df_input'));

      await tester.enterText(nFinder, '20');
      await tester.enterText(bFinder, '2.0');
      await tester.enterText(dfFinder, '1.5');
      await tester.pumpAndSettle();

      // Reference Case 3: expected q_all = 443.4 kPa, q_ult = 1330.1 kPa
      expect(find.text('443.4 kPa'), findsOneWidget);
      expect(find.text('1330.1 kPa'), findsOneWidget);
      expect(find.textContaining('32.88°'), findsOneWidget); // phi
    });

    testWidgets('invalid input shows clear error message and hides results',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final nFinder = find.byKey(const ValueKey('n_input'));

      // Enter N=0 (out of bounds)
      await tester.enterText(nFinder, '0');
      await tester.pumpAndSettle();

      expect(find.textContaining('N değeri 1 ile 100 arasında olmalıdır'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('q_all_result')), findsNothing);

      // Enter non-numeric value
      await tester.enterText(nFinder, 'abc');
      await tester.pumpAndSettle();

      expect(find.text('Lütfen tüm alanlara geçerli sayısal değerler giriniz.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('q_all_result')), findsNothing);

      // Enter negative B
      await tester.enterText(nFinder, '10');
      final bFinder = find.byKey(const ValueKey('b_input'));
      await tester.enterText(bFinder, '-2.0');
      await tester.pumpAndSettle();

      expect(find.textContaining("Temel genişliği (B) 0'dan büyük olmalıdır"),
          findsOneWidget);
    });

    testWidgets('selecting sample from dropdown populates inputs',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Find dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget);

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Select 'test-spt-02' (Kil, N=10, D=1.5 m)
      final sampleItem = find.textContaining('test-spt-02').last;
      await tester.tap(sampleItem);
      await tester.pumpAndSettle();

      final nFinder = find.byKey(const ValueKey('n_input'));
      final dfFinder = find.byKey(const ValueKey('df_input'));

      final nWidget = tester.widget<TextFormField>(nFinder);
      final dfWidget = tester.widget<TextFormField>(dfFinder);

      expect(nWidget.controller?.text, equals('10'));
      expect(dfWidget.controller?.text, equals('1.5'));
      expect(find.textContaining('cu'), findsOneWidget); // Clay shows cu
    });

    testWidgets('shows refüsü warning when N > 50', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      final nFinder = find.byKey(const ValueKey('n_input'));
      await tester.enterText(nFinder, '55');
      await tester.pumpAndSettle();

      expect(find.textContaining('SPT refüsü'), findsOneWidget);
    });

    testWidgets('shows "DEMO VERİ" badge when demo samples are active',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('DEMO VERİ'), findsOneWidget);
    });
  });
}
