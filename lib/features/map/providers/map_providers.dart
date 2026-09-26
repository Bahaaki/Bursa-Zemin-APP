import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../geology/domain/classification.dart';
import '../../geology/domain/geo_index.dart';
import '../../geology/domain/geojson_parser.dart';
import '../../geology/domain/models.dart';
import '../../geology/domain/risk_rules.dart';

/// Pre-computed and cached geology dataset with rendered polygons.
class GeologyData {
  final List<GeoFeature> features;
  final Map<String, ClassificationRow> classifications;
  final GeoIndex geoIndex;
  final List<Polygon> cachedPolygons;
  final bool isDemo;
  final Duration loadDuration;
  final int polygonCount;

  const GeologyData({
    required this.features,
    required this.classifications,
    required this.geoIndex,
    required this.cachedPolygons,
    required this.isDemo,
    required this.loadDuration,
    required this.polygonCount,
  });
}

/// Pre-computed and cached faults dataset with rendered polylines.
class FaultsData {
  final List<FaultLine> faults;
  final List<Polyline> cachedPolylines;
  final bool isDemo;
  final Duration loadDuration;

  const FaultsData({
    required this.faults,
    required this.cachedPolylines,
    required this.isDemo,
    required this.loadDuration,
  });
}

/// Helper to load an asset string, trying primary asset path then falling back to fallback asset path.
Future<({String content, bool isDemo})> loadAssetWithFallback({
  required String primaryPath,
  required String fallbackPath,
  AssetBundle? bundle,
}) async {
  final assetBundle = bundle ?? rootBundle;
  try {
    final content = await assetBundle.loadString(primaryPath);
    if (content.trim().isNotEmpty) {
      return (content: content, isDemo: false);
    }
  } catch (_) {
    // Primary path not found or failed, fall back
  }
  final fallbackContent = await assetBundle.loadString(fallbackPath);
  return (content: fallbackContent, isDemo: true);
}

/// Provider for loading and caching geology data.
final geologyDataProvider = FutureProvider<GeologyData>((ref) async {
  final stopwatch = Stopwatch()..start();

  // 1. Load geology GeoJSON (real or demo fallback)
  final geoRes = await loadAssetWithFallback(
    primaryPath: 'assets/data/geology.geojson',
    fallbackPath: 'assets/demo/geology_demo.geojson',
  );

  // 2. Load classification CSV (real or demo fallback)
  final csvRes = await loadAssetWithFallback(
    primaryPath: 'assets/data/classification.csv',
    fallbackPath: 'assets/demo/classification_demo.csv',
  );

  // 3. Parse in background isolates
  final features = await Isolate.run(() => parseGeologyGeoJson(geoRes.content));
  final classifications =
      await Isolate.run(() => parseClassificationCsv(csvRes.content));

  final geoIndex = GeoIndex(
    features: features,
    classifications: classifications,
  );

  // 4. Build cached Polygon widgets
  final cachedPolygons = <Polygon>[];
  int polyCount = 0;

  for (final feature in features) {
    final classification = classifications[feature.birim];
    final riskLevel = classification?.zeminRiski ?? RiskLevel.dusuk;

    final Color fillColor = switch (riskLevel) {
      RiskLevel.dusuk => const Color(0xFF4CAF50).withOpacity(0.45), // Green
      RiskLevel.orta =>
        const Color(0xFFFFC107).withOpacity(0.45), // Yellow/Amber
      RiskLevel.yuksek => const Color(0xFFF44336).withOpacity(0.45), // Red
    };

    final Color strokeColor = switch (riskLevel) {
      RiskLevel.dusuk => const Color(0xFF2E7D32),
      RiskLevel.orta => const Color(0xFFF57F17),
      RiskLevel.yuksek => const Color(0xFFC62828),
    };

    for (final shape in feature.shapes) {
      polyCount++;
      cachedPolygons.add(
        Polygon(
          points: shape.outerRing,
          holePointsList: shape.holes.isNotEmpty ? shape.holes : null,
          color: fillColor,
          borderColor: strokeColor,
          borderStrokeWidth: 1.0,
        ),
      );
    }
  }

  stopwatch.stop();

  final isDemo =
      geoRes.isDemo || csvRes.isDemo || features.any((f) => f.isDemo);

  return GeologyData(
    features: features,
    classifications: classifications,
    geoIndex: geoIndex,
    cachedPolygons: cachedPolygons,
    isDemo: isDemo,
    loadDuration: stopwatch.elapsed,
    polygonCount: polyCount,
  );
});

/// Provider for loading and caching faults data.
final faultsDataProvider = FutureProvider<FaultsData>((ref) async {
  final stopwatch = Stopwatch()..start();

  final faultsRes = await loadAssetWithFallback(
    primaryPath: 'assets/data/faults.geojson',
    fallbackPath: 'assets/demo/faults_demo.geojson',
  );

  final faults = await Isolate.run(() => parseFaultsGeoJson(faultsRes.content));

  final cachedPolylines = <Polyline>[];
  for (final fault in faults) {
    for (final line in fault.lines) {
      cachedPolylines.add(
        Polyline(
          points: line,
          color: const Color(0xFF212121), // Dark line per SPEC §3.2
          strokeWidth: 2.2,
        ),
      );
    }
  }

  stopwatch.stop();

  final isDemo = faultsRes.isDemo || faults.any((f) => f.isDemo);

  return FaultsData(
    faults: faults,
    cachedPolylines: cachedPolylines,
    isDemo: isDemo,
    loadDuration: stopwatch.elapsed,
  );
});

/// State for the MapScreen view.
class MapState {
  final bool showGeology;
  final bool showFaults;
  final bool showQuakes;
  final LatLng? selectedPoint;
  final LatLng? userLocation;

  const MapState({
    this.showGeology = true,
    this.showFaults = true,
    this.showQuakes = false,
    this.selectedPoint,
    this.userLocation,
  });

  MapState copyWith({
    bool? showGeology,
    bool? showFaults,
    bool? showQuakes,
    LatLng? selectedPoint,
    bool clearSelectedPoint = false,
    LatLng? userLocation,
  }) {
    return MapState(
      showGeology: showGeology ?? this.showGeology,
      showFaults: showFaults ?? this.showFaults,
      showQuakes: showQuakes ?? this.showQuakes,
      selectedPoint:
          clearSelectedPoint ? null : (selectedPoint ?? this.selectedPoint),
      userLocation: userLocation ?? this.userLocation,
    );
  }
}

class MapStateNotifier extends StateNotifier<MapState> {
  MapStateNotifier() : super(const MapState());

  void toggleGeology(bool value) {
    state = state.copyWith(showGeology: value);
  }

  void toggleFaults(bool value) {
    state = state.copyWith(showFaults: value);
  }

  void toggleQuakes(bool value) {
    state = state.copyWith(showQuakes: value);
  }

  void selectPoint(LatLng point) {
    state = state.copyWith(selectedPoint: point);
  }

  void clearSelectedPoint() {
    state = state.copyWith(clearSelectedPoint: true);
  }

  void setUserLocation(LatLng location) {
    state = state.copyWith(userLocation: location);
  }
}

final mapStateProvider =
    StateNotifierProvider<MapStateNotifier, MapState>((ref) {
  return MapStateNotifier();
});

/// Provider for loading fault distance rules from assets/config/risk_rules.json.
final riskRulesProvider = FutureProvider<FaultDistanceRules>((ref) async {
  try {
    final content =
        await rootBundle.loadString('assets/config/risk_rules.json');
    final json = jsonDecode(content) as Map<String, dynamic>;
    return FaultDistanceRules.fromJson(json);
  } catch (_) {
    return const FaultDistanceRules();
  }
});
