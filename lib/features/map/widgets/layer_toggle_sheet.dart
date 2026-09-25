import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/map_providers.dart';

/// Modal bottom sheet allowing users to toggle visible map layers.
class LayerToggleSheet extends ConsumerWidget {
  const LayerToggleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapStateProvider);
    final notifier = ref.read(mapStateProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Harita Katmanları',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.terrain, color: Colors.teal),
              title: const Text('Jeoloji Katmanı'),
              subtitle: const Text('Zemin birimleri ve risk bölgeleri'),
              value: mapState.showGeology,
              onChanged: (val) => notifier.toggleGeology(val),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.show_chart, color: Colors.redAccent),
              title: const Text('Fay Hatları'),
              subtitle: const Text('Diri fay çizgileri'),
              value: mapState.showFaults,
              onChanged: (val) => notifier.toggleFaults(val),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.sensors, color: Colors.grey),
              title: const Text('Son Depremler'),
              subtitle: const Text('AFAD son 24 saat depremleri (Pek yakında)'),
              value: mapState.showQuakes,
              onChanged: null, // Disabled placeholder for P6 per SPEC §3.2
            ),
          ],
        ),
      ),
    );
  }
}
