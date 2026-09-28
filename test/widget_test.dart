import 'package:bursa_zemin/app/app.dart';
import 'package:bursa_zemin/core/constants.dart';
import 'package:bursa_zemin/features/geology/domain/geo_index.dart';
import 'package:bursa_zemin/features/map/map_screen.dart';
import 'package:bursa_zemin/features/map/providers/map_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — shows app name', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BursaZeminApp(),
      ),
    );
    expect(find.text(kAppName), findsOneWidget);
  });

  test('Disclaimer constant is not empty', () {
    expect(kDisclaimer.isNotEmpty, isTrue);
    expect(kDisclaimer, contains('zemin etüdü'));
  });

  testWidgets(
      'MapScreen smoke test — renders map screen with layers and banner',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geologyDataProvider.overrideWith((ref) async => const GeologyData(
                features: [],
                classifications: {},
                geoIndex: GeoIndex(features: [], classifications: {}),
                cachedPolygons: [],
                isDemo: true,
                loadDuration: Duration.zero,
                polygonCount: 0,
              )),
          faultsDataProvider.overrideWith((ref) async => const FaultsData(
                faults: [],
                cachedPolylines: [],
                isDemo: true,
                loadDuration: Duration.zero,
              )),
        ],
        child: const MaterialApp(
          home: MapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('DEMO VERİ — Gerçek Jeoloji Değildir'), findsOneWidget);
    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets(
      'MapScreen error state — shows Turkish error screen when geology fails to parse',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geologyDataProvider.overrideWith(
            (ref) => Future.error(
                const FormatException('Geçersiz GeoJSON sözdizimi')),
          ),
          faultsDataProvider.overrideWith((ref) async => const FaultsData(
                faults: [],
                cachedPolylines: [],
                isDemo: true,
                loadDuration: Duration.zero,
              )),
        ],
        child: const MaterialApp(
          home: MapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jeoloji haritası yüklenemedi'), findsOneWidget);
    expect(
        find.text(
            'Harita verisi işlenirken bir hata oluştu. Lütfen veri dosyalarını kontrol ediniz.'),
        findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets(
      'MapScreen error state — shows Turkish error screen when faults fail to parse',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geologyDataProvider.overrideWith((ref) async => const GeologyData(
                features: [],
                classifications: {},
                geoIndex: GeoIndex(features: [], classifications: {}),
                cachedPolygons: [],
                isDemo: true,
                loadDuration: Duration.zero,
                polygonCount: 0,
              )),
          faultsDataProvider.overrideWith(
            (ref) => Future.error(
                const FormatException('Fay GeoJSON dosyası bozuk')),
          ),
        ],
        child: const MaterialApp(
          home: MapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fay hattı verisi yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}
