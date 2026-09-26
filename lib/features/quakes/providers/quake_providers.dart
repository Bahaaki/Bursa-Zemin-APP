import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/afad_client.dart';
import '../domain/quake.dart';

/// Riverpod provider for [AfadClient].
final afadClientProvider = Provider<AfadClient>((ref) {
  final client = AfadClient();
  ref.onDispose(() => client.close());
  return client;
});

/// Riverpod provider that fetches earthquakes for Bursa from AFAD.
///
/// Automatically uses 10-minute cache in AfadClient.
final quakesProvider = FutureProvider<List<Quake>>((ref) async {
  final client = ref.watch(afadClientProvider);
  return client.fetchEarthquakes();
});
