import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import 'providers/map_providers.dart';
import 'widgets/layer_toggle_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;

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

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapStateProvider);
    final geologyAsync = ref.watch(geologyDataProvider);
    final faultsAsync = ref.watch(faultsDataProvider);

    final isDemo = (geologyAsync.valueOrNull?.isDemo ?? false) ||
        (faultsAsync.valueOrNull?.isDemo ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(kDefaultLat, kDefaultLon),
              initialZoom: 10.0,
              onTap: (TapPosition tapPosition, LatLng point) {
                ref.read(mapStateProvider.notifier).selectPoint(point);
                debugPrint(
                    'Haritada seçilen konum: [${point.latitude}, ${point.longitude}]');
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
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
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
                ],
              ),
            ],
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

          // Loading overlay if initial datasets are loading
          if (geologyAsync.isLoading || faultsAsync.isLoading)
            Positioned(
              top: isDemo ? 36 : 8,
              right: 8,
              child: Card(
                color: Colors.white.withOpacity(0.9),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Veriler yükleniyor...',
                          style: TextStyle(fontSize: 12)),
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
}
