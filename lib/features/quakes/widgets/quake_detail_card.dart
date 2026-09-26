import 'package:flutter/material.dart';
import '../domain/quake.dart';

/// Card displayed when an earthquake marker is tapped on the map (SPEC §5).
///
/// Shows:
/// - Zaman (time)
/// - Büyüklük (magnitude)
/// - Derinlik (depth)
/// - Konum (place)
///
/// Never presents data as a prediction.
class QuakeDetailCard extends StatelessWidget {
  final Quake quake;

  const QuakeDetailCard({super.key, required this.quake});

  static Future<void> show(BuildContext context, Quake quake) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => QuakeDetailCard(quake: quake),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = quake.date;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepOrange.shade700),
                  ),
                  child: Text(
                    'M ${quake.magnitude.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deprem Bilgisi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Kaynak: AFAD (${quake.type})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow(
              icon: Icons.place_outlined,
              label: 'Konum',
              value: quake.location,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.access_time_outlined,
              label: 'Zaman',
              value: dateStr,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.straighten_outlined,
              label: 'Derinlik',
              value: '${quake.depth.toStringAsFixed(1)} km',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.radar_outlined,
              label: 'Büyüklük Türü',
              value: '${quake.magnitude.toStringAsFixed(1)} (${quake.type})',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bu veriler gerçekleşmiş sismik kayıtları gösterir, deprem tahmini değildir.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
