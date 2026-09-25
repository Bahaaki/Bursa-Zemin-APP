import 'dart:io';
import 'dart:isolate';
import 'package:bursa_zemin/features/geology/domain/classification.dart';
import 'package:bursa_zemin/features/geology/domain/geo_index.dart';
import 'package:bursa_zemin/features/geology/domain/geojson_parser.dart';
import 'package:bursa_zemin/features/geology/domain/models.dart';
import 'package:bursa_zemin/features/map/providers/map_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// In-memory asset bundle for deterministic test execution without network.
class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  FakeAssetBundle(this.assets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = assets[key];
    if (value != null) {
      return value;
    }
    throw FlutterError('Asset not found in fake bundle: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    final str = await loadString(key);
    return ByteData.view(Uint8List.fromList(str.codeUnits).buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadAssetWithFallback', () {
    test('loads primary asset when present', () async {
      final bundle = FakeAssetBundle({
        'assets/data/geology.geojson':
            '{"type": "FeatureCollection", "features": []}',
        'assets/demo/geology_demo.geojson':
            '{"type": "FeatureCollection", "features": []}',
      });

      final result = await loadAssetWithFallback(
        primaryPath: 'assets/data/geology.geojson',
        fallbackPath: 'assets/demo/geology_demo.geojson',
        bundle: bundle,
      );

      expect(result.isDemo, isFalse);
      expect(result.content, contains('FeatureCollection'));
    });

    test('falls back to demo asset when primary asset is absent', () async {
      final bundle = FakeAssetBundle({
        'assets/demo/geology_demo.geojson':
            '{"type": "FeatureCollection", "features": [], "demo": true}',
      });

      final result = await loadAssetWithFallback(
        primaryPath: 'assets/data/geology.geojson',
        fallbackPath: 'assets/demo/geology_demo.geojson',
        bundle: bundle,
      );

      expect(result.isDemo, isTrue);
      expect(result.content, contains('"demo": true'));
    });
  });

  group('MapStateNotifier', () {
    test('initial state has geology=true, faults=true, quakes=false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(mapStateProvider);
      expect(state.showGeology, isTrue);
      expect(state.showFaults, isTrue);
      expect(state.showQuakes, isFalse);
      expect(state.selectedPoint, isNull);
      expect(state.userLocation, isNull);
    });

    test('toggles layers correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapStateProvider.notifier);

      notifier.toggleGeology(false);
      expect(container.read(mapStateProvider).showGeology, isFalse);

      notifier.toggleFaults(false);
      expect(container.read(mapStateProvider).showFaults, isFalse);

      notifier.toggleQuakes(true);
      expect(container.read(mapStateProvider).showQuakes, isTrue);
    });

    test('selects and clears points correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapStateProvider.notifier);
      const point = LatLng(40.19, 29.06);

      notifier.selectPoint(point);
      expect(container.read(mapStateProvider).selectedPoint, equals(point));

      notifier.clearSelectedPoint();
      expect(container.read(mapStateProvider).selectedPoint, isNull);
    });

    test('sets user location correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mapStateProvider.notifier);
      const userLoc = LatLng(40.20, 29.07);

      notifier.setUserLocation(userLoc);
      expect(container.read(mapStateProvider).userLocation, equals(userLoc));
    });
  });

  group('Dataset providers with real demo files', () {
    test('loads demo geology dataset and verifies polygon count and colors',
        () async {
      final geoJson =
          File('assets/demo/geology_demo.geojson').readAsStringSync();
      final csv =
          File('assets/demo/classification_demo.csv').readAsStringSync();

      final fakeBundle = FakeAssetBundle({
        'assets/demo/geology_demo.geojson': geoJson,
        'assets/demo/classification_demo.csv': csv,
      });

      final container = ProviderContainer(
        overrides: [
          geologyDataProvider.overrideWith((ref) async {
            final geoRes = await loadAssetWithFallback(
              primaryPath: 'assets/data/geology.geojson',
              fallbackPath: 'assets/demo/geology_demo.geojson',
              bundle: fakeBundle,
            );
            final csvRes = await loadAssetWithFallback(
              primaryPath: 'assets/data/classification.csv',
              fallbackPath: 'assets/demo/classification_demo.csv',
              bundle: fakeBundle,
            );

            final stopwatch = Stopwatch()..start();
            final features =
                await Isolate.run(() => parseGeologyGeoJson(geoRes.content));
            final classifications =
                await Isolate.run(() => parseClassificationCsv(csvRes.content));
            final geoIndex =
                GeoIndex(features: features, classifications: classifications);

            final cachedPolygons = <Polygon>[];
            int polyCount = 0;
            for (final feature in features) {
              final classification = classifications[feature.birim];
              final RiskLevel riskLevel =
                  classification?.zeminRiski ?? RiskLevel.dusuk;
              final Color fillColor = switch (riskLevel) {
                RiskLevel.dusuk => const Color(0xFF4CAF50).withOpacity(0.45),
                RiskLevel.orta => const Color(0xFFFFC107).withOpacity(0.45),
                RiskLevel.yuksek => const Color(0xFFF44336).withOpacity(0.45),
              };
              for (final shape in feature.shapes) {
                polyCount++;
                cachedPolygons.add(
                  Polygon(
                    points: shape.outerRing,
                    holePointsList: shape.holes.isNotEmpty ? shape.holes : null,
                    color: fillColor,
                    borderColor: const Color(0xFF333333),
                    borderStrokeWidth: 1.0,
                  ),
                );
              }
            }
            stopwatch.stop();

            return GeologyData(
              features: features,
              classifications: classifications,
              geoIndex: geoIndex,
              cachedPolygons: cachedPolygons,
              isDemo: true,
              loadDuration: stopwatch.elapsed,
              polygonCount: polyCount,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(geologyDataProvider.future);
      expect(data.isDemo, isTrue);
      expect(data.features.length, equals(5));
      // DEMO-1 through DEMO-4 are single polygons, DEMO-5 is a MultiPolygon of 2 polygons -> 4 + 2 = 6 polygons
      expect(data.polygonCount, equals(6));
      expect(data.cachedPolygons.length, equals(6));
      expect(data.loadDuration.inMilliseconds, lessThan(1000));
    });

    test('loads demo faults dataset and verifies polyline count', () async {
      final faultsJson =
          File('assets/demo/faults_demo.geojson').readAsStringSync();
      final fakeBundle = FakeAssetBundle({
        'assets/demo/faults_demo.geojson': faultsJson,
      });

      final container = ProviderContainer(
        overrides: [
          faultsDataProvider.overrideWith((ref) async {
            final faultsRes = await loadAssetWithFallback(
              primaryPath: 'assets/data/faults.geojson',
              fallbackPath: 'assets/demo/faults_demo.geojson',
              bundle: fakeBundle,
            );
            final stopwatch = Stopwatch()..start();
            final faults =
                await Isolate.run(() => parseFaultsGeoJson(faultsRes.content));
            final cachedPolylines = <Polyline>[];
            for (final fault in faults) {
              for (final line in fault.lines) {
                cachedPolylines.add(
                  Polyline(
                    points: line,
                    color: const Color(0xFF212121),
                    strokeWidth: 2.2,
                  ),
                );
              }
            }
            stopwatch.stop();

            return FaultsData(
              faults: faults,
              cachedPolylines: cachedPolylines,
              isDemo: true,
              loadDuration: stopwatch.elapsed,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(faultsDataProvider.future);
      expect(data.isDemo, isTrue);
      expect(data.faults.length, equals(2));
      // Fault 1 has 1 line, Fault 2 has 2 lines (MultiLineString) -> 3 polylines
      expect(data.cachedPolylines.length, equals(3));
    });
  });
}
