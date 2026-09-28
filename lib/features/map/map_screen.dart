import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../calculator/calculator_screen.dart';
import '../geology/domain/assessment.dart';
import '../geology/domain/risk_rules.dart';
import '../quakes/domain/quake.dart';
import '../quakes/providers/quake_providers.dart';
import '../quakes/widgets/quake_detail_card.dart';
import 'providers/map_providers.dart';
import 'widgets/ground_assessment_sheet.dart';
import 'widgets/layer_toggle_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _handleLocationButton() async {
    // 1. Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum servisi kapalı'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum izni reddedildi'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Konum izni kalıcı olarak reddedildi, ayarlardan açınız'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 3. Obtain position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);
      ref.read(mapStateProvider.notifier).setUserLocation(userLatLng);
      _mapController.move(userLatLng, 14.0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Konum alınamadı: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<Uint8List?> _captureMapSnapshot() async {
    try {
      final binding = WidgetsBinding.instance;

      // 1. Wait for post-frame callback so the tap marker and state changes are painted
      final completer = Completer<void>();
      binding.addPostFrameCallback((_) {
        completer.complete();
      });
      await completer.future;

      // 2. Brief settle delay to allow vector graphics / tile layout to settle
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final boundary =
          _mapKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 3. If boundary still needs paint, wait for the frame end
      if (boundary.debugNeedsPaint) {
        await binding.endOfFrame;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Harita görüntüsü alınamadı: $e');
      return null;
    }
  }

  Future<void> _showAssessmentSheet({
    required LatLng point,
    required GeologyData geology,
    FaultsData? faults,
    FaultDistanceRules? rules,
  }) async {
    final mapBytes = await _captureMapSnapshot();
    final assessment = assess(
      point: point,
      geoIndex: geology.geoIndex,
      faults: faults?.faults,
      faultRules: rules ?? const FaultDistanceRules(),
    );

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GroundAssessmentSheet(
        assessment: assessment,
        point: point,
        mapSnapshotBytes: mapBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapStateProvider);
    final geologyAsync = ref.watch(geologyDataProvider);
    final faultsAsync = ref.watch(faultsDataProvider);
    final quakesAsync = mapState.showQuakes ? ref.watch(quakesProvider) : null;

    // Handle GeoJSON / dataset parse or load failures gracefully (P8 hardening)
    if (geologyAsync.hasError || faultsAsync.hasError) {
      final error = geologyAsync.error ?? faultsAsync.error;
      final isGeology = geologyAsync.hasError;
      return Scaffold(
        appBar: AppBar(title: const Text(kAppName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  isGeology
                      ? 'Jeoloji haritası yüklenemedi'
                      : 'Fay hattı verisi yüklenemedi',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Harita verisi işlenirken bir hata oluştu. Lütfen veri dosyalarını kontrol ediniz.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (geologyAsync.hasError) {
                      ref.invalidate(geologyDataProvider);
                    }
                    if (faultsAsync.hasError) {
                      ref.invalidate(faultsDataProvider);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDemo = (geologyAsync.valueOrNull?.isDemo ?? false) ||
        (faultsAsync.valueOrNull?.isDemo ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'SPT Hesabı',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalculatorScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Katmanlar',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (_) => const LayerToggleSheet(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            key: _mapKey,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(kDefaultLat, kDefaultLon),
                initialZoom: 10.0,
                onTap: (TapPosition tapPosition, LatLng point) {
                  ref.read(mapStateProvider.notifier).selectPoint(point);
                  final geology = geologyAsync.valueOrNull;
                  if (geology == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Veriler yükleniyor, lütfen bekleyiniz...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    return;
                  }
                  final faults = faultsAsync.valueOrNull;
                  final rules = ref.read(riskRulesProvider).valueOrNull;
                  _showAssessmentSheet(
                    point: point,
                    geology: geology,
                    faults: faults,
                    rules: rules,
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: kAppId,
                ),
                if (mapState.showGeology && geologyAsync.hasValue)
                  PolygonLayer(
                    polygons: geologyAsync.requireValue.cachedPolygons,
                  ),
                if (mapState.showFaults && faultsAsync.hasValue)
                  PolylineLayer(
                    polylines: faultsAsync.requireValue.cachedPolylines,
                  ),
                MarkerLayer(
                  markers: [
                    if (mapState.selectedPoint != null)
                      Marker(
                        point: mapState.selectedPoint!,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            final geology = geologyAsync.valueOrNull;
                            if (geology != null) {
                              final faults = faultsAsync.valueOrNull;
                              final rules =
                                  ref.read(riskRulesProvider).valueOrNull;
                              _showAssessmentSheet(
                                point: mapState.selectedPoint!,
                                geology: geology,
                                faults: faults,
                                rules: rules,
                              );
                            }
                          },
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ),
                    if (mapState.userLocation != null)
                      Marker(
                        point: mapState.userLocation!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (mapState.showQuakes && quakesAsync?.valueOrNull != null)
                      for (final quake in quakesAsync!.valueOrNull!)
                        _buildQuakeMarker(context, quake),
                  ],
                ),
              ],
            ),
          ),

          // OSM Attribution
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.white.withOpacity(0.7),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),

          // Demo Data Banner
          if (isDemo)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.amber.shade800,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'DEMO VERİ — Gerçek Jeoloji Değildir',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Quakes Error Banner (SPEC §5)
          if (mapState.showQuakes && quakesAsync?.hasError == true)
            Positioned(
              top: isDemo ? 36 : 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.red.shade800,
                elevation: 3,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Deprem verisi alınamadı',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(quakesProvider),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 24),
                        ),
                        child: const Text('Tekrar Dene',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading overlay if initial datasets or quakes are loading
          if (geologyAsync.isLoading ||
              faultsAsync.isLoading ||
              (mapState.showQuakes && (quakesAsync?.isLoading ?? false)))
            Positioned(
              top: (isDemo ||
                      (mapState.showQuakes && quakesAsync?.hasError == true))
                  ? 40
                  : 8,
              right: 8,
              child: Card(
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (mapState.showQuakes &&
                                (quakesAsync?.isLoading ?? false))
                            ? 'Depremler yükleniyor...'
                            : 'Veriler yükleniyor...',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleLocationButton,
        tooltip: 'Konumumu Göster',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Marker _buildQuakeMarker(BuildContext context, Quake quake) {
    final size = (quake.magnitude * 8.0).clamp(20.0, 48.0);
    final color = quake.magnitude >= 4.5
        ? Colors.red.shade700
        : quake.magnitude >= 3.0
            ? Colors.deepOrange
            : Colors.orange.shade700;

    return Marker(
      point: quake.coordinates,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          QuakeDetailCard.show(context, quake);
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            quake.magnitude.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white,
              fontSize: (size * 0.42).clamp(8.0, 14.0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
