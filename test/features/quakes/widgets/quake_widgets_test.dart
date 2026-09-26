import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bursa_zemin/features/map/map_screen.dart';
import 'package:bursa_zemin/features/map/providers/map_providers.dart';
import 'package:bursa_zemin/features/quakes/domain/quake.dart';
import 'package:bursa_zemin/features/quakes/providers/quake_providers.dart';
import 'package:bursa_zemin/features/quakes/widgets/quake_detail_card.dart';

void main() {
  final testQuake = Quake(
    eventId: '728231',
    location: 'Yenişehir (Bursa)',
    latitude: 40.317,
    longitude: 29.46917,
    depth: 7.0,
    type: 'ML',
    magnitude: 2.9,
    country: 'Türkiye',
    province: 'Bursa',
    district: 'Yenişehir',
    neighborhood: 'Yeniköy',
    date: DateTime.parse('2026-09-10T00:20:41'),
  );

  group('QuakeDetailCard widget tests', () {
    testWidgets('renders all earthquake details correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuakeDetailCard(quake: testQuake),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deprem Bilgisi'), findsOneWidget);
      expect(find.text('M 2.9'), findsOneWidget);
      expect(find.text('Yenişehir (Bursa)'), findsOneWidget);
      expect(find.text('7.0 km'), findsOneWidget);
      expect(find.text('2.9 (ML)'), findsOneWidget);
      expect(find.textContaining('10.09.2026'), findsOneWidget);
      expect(find.textContaining('deprem tahmini değildir'), findsOneWidget);
    });
  });

  group('MapScreen Quakes Layer integration tests', () {
    testWidgets(
        'renders error banner "Deprem verisi alınamadı" when quakesProvider fails',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapStateProvider.overrideWith((ref) {
              final notifier = MapStateNotifier();
              notifier.toggleQuakes(true);
              return notifier;
            }),
            quakesProvider.overrideWith((ref) async {
              throw Exception('Connection failed');
            }),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Deprem verisi alınamadı'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('renders earthquake marker and opens detail card on tap',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapStateProvider.overrideWith((ref) {
              final notifier = MapStateNotifier();
              notifier.toggleQuakes(true);
              return notifier;
            }),
            quakesProvider.overrideWith((ref) async {
              return [testQuake];
            }),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find marker with magnitude "2.9"
      final markerFinder = find.text('2.9');
      expect(markerFinder, findsOneWidget);

      // Tap marker -> detail card opens
      await tester.tap(markerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(QuakeDetailCard), findsOneWidget);
      expect(find.text('Yenişehir (Bursa)'), findsOneWidget);
      expect(find.textContaining('deprem tahmini değildir'), findsOneWidget);
    });
  });
}
