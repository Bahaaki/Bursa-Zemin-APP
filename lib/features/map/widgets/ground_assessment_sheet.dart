import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants.dart';
import '../../calculator/calculator_screen.dart';
import '../../geology/domain/models.dart';

/// Modal bottom sheet displaying ground assessment details (SPEC §3.3).
class GroundAssessmentSheet extends StatelessWidget {
  final Assessment assessment;
  final LatLng point;

  const GroundAssessmentSheet({
    super.key,
    required this.assessment,
    required this.point,
  });

  Color _getRiskColor(RiskLevel? level) {
    if (level == null) return Colors.grey.shade600;
    switch (level) {
      case RiskLevel.dusuk:
        return const Color(0xFF2E7D32); // Green 800
      case RiskLevel.orta:
        return const Color(0xFFE65100); // Amber 900
      case RiskLevel.yuksek:
        return const Color(0xFFC62828); // Red 800
    }
  }

  Color _getRiskBgColor(RiskLevel? level) {
    if (level == null) return Colors.grey.shade100;
    switch (level) {
      case RiskLevel.dusuk:
        return const Color(0xFFE8F5E9); // Green 50
      case RiskLevel.orta:
        return const Color(0xFFFFF8E1); // Amber 50
      case RiskLevel.yuksek:
        return const Color(0xFFFFEBEE); // Red 50
    }
  }

  Color _getRiskBorderColor(RiskLevel? level) {
    if (level == null) return Colors.grey.shade300;
    switch (level) {
      case RiskLevel.dusuk:
        return const Color(0xFF81C784); // Green 300
      case RiskLevel.orta:
        return const Color(0xFFFFD54F); // Amber 300
      case RiskLevel.yuksek:
        return const Color(0xFFE57373); // Red 300
    }
  }

  IconData _getRiskIcon(RiskLevel? level) {
    if (level == null) return Icons.help_outline_rounded;
    switch (level) {
      case RiskLevel.dusuk:
        return Icons.check_circle_outline_rounded;
      case RiskLevel.orta:
        return Icons.warning_amber_rounded;
      case RiskLevel.yuksek:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overallColor = _getRiskColor(assessment.overallRisk);
    final overallBg = _getRiskBgColor(assessment.overallRisk);
    final overallBorder = _getRiskBorderColor(assessment.overallRisk);
    final overallIcon = _getRiskIcon(assessment.overallRisk);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Demo Chip
            Row(
              children: [
                Icon(
                  Icons.terrain_rounded,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Zemin Ön Değerlendirmesi',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (assessment.isDemo)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DEMO VERİ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Overall Risk Banner Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: overallBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: overallBorder, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(overallIcon, color: overallColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assessment.hasData && assessment.overallRisk != null
                              ? 'Genel Değerlendirme: ${assessment.overallRisk!.turkishName}'
                              : 'Genel Değerlendirme',
                          style: TextStyle(
                            color: overallColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assessment.recommendation,
                          style: TextStyle(
                            color: overallColor.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Details Table / List
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: [
                    _buildRow(
                      context,
                      icon: Icons.pin_drop_outlined,
                      label: 'Koordinat',
                      value:
                          '${point.latitude.toStringAsFixed(4)}° K, ${point.longitude.toStringAsFixed(4)}° D',
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      context,
                      icon: Icons.layers_outlined,
                      label: 'Jeolojik birim',
                      value: assessment.hasData
                          ? (assessment.classification?.ad != null &&
                                  assessment.classification!.ad.isNotEmpty
                              ? '${assessment.feature?.birim ?? '-'} — ${assessment.classification!.ad}'
                              : (assessment.feature?.birim ?? '-'))
                          : 'Veri yok – zemin etüdü gerekli',
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      context,
                      icon: Icons.landscape_outlined,
                      label: 'Zemin türü',
                      value: assessment.hasData
                          ? (assessment.classification?.zeminTuru ??
                              'Bilinmiyor')
                          : 'Veri yok',
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      context,
                      icon: Icons.waves_outlined,
                      label: 'Şişme Potansiyeli',
                      value: assessment.hasData
                          ? (assessment.classification?.sismePotansiyeli
                                  .turkishName ??
                              'Bilinmiyor')
                          : 'Veri yok',
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      context,
                      icon: Icons.timeline_outlined,
                      label: 'En yakın fay',
                      value: assessment.nearestFault != null
                          ? '${(assessment.nearestFault!.name != null && assessment.nearestFault!.name!.isNotEmpty) ? assessment.nearestFault!.name! : "İsimsiz Fay"} (${assessment.nearestFault!.distanceKm.toStringAsFixed(1)} km)'
                          : 'Fay verisi yok',
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      context,
                      icon: Icons.source_outlined,
                      label: 'Kaynak',
                      value: 'MTA, AFAD',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Legal Disclaimer (R10, SPEC §3.3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (SPEC §3.3 & Task 3)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CalculatorScreen(
                            initialCoordinates: point,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('SPT Hesabı'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Rapor oluşturma özelliği yakında eklenecektir (P7)'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Rapor Oluştur (Yakında)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
