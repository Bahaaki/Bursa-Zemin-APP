import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants.dart';
import '../calculator/domain/spt_calculator.dart';
import '../geology/domain/models.dart';

/// Container for TrueType fonts used in PDF rendering to ensure full Turkish character support.
class PdfFontPair {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font? italic;

  const PdfFontPair({
    required this.regular,
    required this.bold,
    this.italic,
  });
}

/// Structured SPT bearing capacity data for report formatting.
class BearingReportData {
  final String soilKind;
  final int nValue;
  final double effectiveN;
  final String footingShape;
  final double b;
  final double df;
  final double gamma;
  final double fs;
  final double? phiDeg;
  final double? cuKpa;
  final double nc;
  final double nq;
  final double ng;
  final double q;
  final double qUlt;
  final double qAll;
  final List<String> warnings;

  const BearingReportData({
    required this.soilKind,
    required this.nValue,
    required this.effectiveN,
    required this.footingShape,
    required this.b,
    required this.df,
    required this.gamma,
    required this.fs,
    this.phiDeg,
    this.cuKpa,
    required this.nc,
    required this.nq,
    required this.ng,
    required this.q,
    required this.qUlt,
    required this.qAll,
    required this.warnings,
  });

  factory BearingReportData.fromBearingResult(BearingResult result) {
    return BearingReportData(
      soilKind: result.soilKind.label,
      nValue: result.nValue,
      effectiveN: result.effectiveN,
      footingShape: result.footingShape.label,
      b: result.b,
      df: result.df,
      gamma: result.gamma,
      fs: result.fs,
      phiDeg: result.phiDeg,
      cuKpa: result.cuKpa,
      nc: result.nc,
      nq: result.nq,
      ng: result.ng,
      q: result.q,
      qUlt: result.qUlt,
      qAll: result.qAll,
      warnings: List.unmodifiable(result.warnings),
    );
  }
}

/// Pure data model containing all text fields of the report (SPEC §6).
///
/// Decoupled from the PDF widget tree to enable golden-string testing and headless validation.
class ReportTextData {
  final String title;
  final String dateString;
  final String coordinatesString;
  final String geologyUnit;
  final String soilType;
  final String swellingPotential;
  final String nearestFault;
  final String faultRiskLevel;
  final String overallRiskLevel;
  final String recommendation;
  final bool isDemo;
  final bool hasData;
  final BearingReportData? bearing;
  final String disclaimer;
  final String sources;
  final String developer;

  const ReportTextData({
    required this.title,
    required this.dateString,
    required this.coordinatesString,
    required this.geologyUnit,
    required this.soilType,
    required this.swellingPotential,
    required this.nearestFault,
    required this.faultRiskLevel,
    required this.overallRiskLevel,
    required this.recommendation,
    required this.isDemo,
    required this.hasData,
    this.bearing,
    required this.disclaimer,
    required this.sources,
    required this.developer,
  });

  /// Formats the report data into a deterministic plain text string.
  ///
  /// Used for golden string testing, logging, and accessibility.
  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('=== $title ===');
    buffer.writeln('Tarih: $dateString');
    buffer.writeln('Koordinat: $coordinatesString');
    buffer.writeln();
    buffer.writeln('--- ZEMİN ÖN DEĞERLENDİRMESİ ---');
    buffer.writeln('Jeolojik Birim: $geologyUnit');
    buffer.writeln('Zemin Türü: $soilType');
    buffer.writeln('Şişme Potansiyeli: $swellingPotential');
    buffer.writeln('En Yakın Fay: $nearestFault');
    buffer.writeln('Fay Risk Düzeyi: $faultRiskLevel');
    buffer.writeln('Genel Değerlendirme: $overallRiskLevel');
    buffer.writeln('Öneri: $recommendation');
    if (isDemo) {
      buffer.writeln('Uyarı: DEMO VERİ - Gerçek saha verisi değildir.');
    }
    if (bearing != null) {
      buffer.writeln();
      buffer.writeln('--- SPT TAŞIMA GÜCÜ HESABI (TERZAGHI) ---');
      buffer.writeln('Zemin Türü: ${bearing!.soilKind}');
      buffer.writeln(
          'SPT-N: ${bearing!.nValue} (Düzeltilmiş N: ${bearing!.effectiveN.toStringAsFixed(1)})');
      buffer.writeln(
          'Temel Geometrisi: ${bearing!.footingShape} (B: ${bearing!.b.toStringAsFixed(2)} m, Df: ${bearing!.df.toStringAsFixed(2)} m)');
      buffer.writeln(
          'Zemin Parametreleri: Birim Hacim Ağırlık γ: ${bearing!.gamma.toStringAsFixed(1)} kN/m³, Güvenlik Sayısı FS: ${bearing!.fs.toStringAsFixed(1)}');
      if (bearing!.phiDeg != null) {
        buffer.writeln(
            'İçsel Sürtünme Açısı φ: ${bearing!.phiDeg!.toStringAsFixed(2)}°');
      }
      if (bearing!.cuKpa != null) {
        buffer.writeln(
            'Drenajsız Kayma Mukavemeti cu: ${bearing!.cuKpa!.toStringAsFixed(1)} kPa');
      }
      buffer.writeln(
          'Taşıma Gücü Katsayıları: Nc: ${bearing!.nc.toStringAsFixed(2)}, Nq: ${bearing!.nq.toStringAsFixed(2)}, Nγ: ${bearing!.ng.toStringAsFixed(2)}');
      buffer.writeln('Sürşarj Basıncı q: ${bearing!.q.toStringAsFixed(1)} kPa');
      buffer.writeln(
          'Nihai Taşıma Gücü q_ult: ${bearing!.qUlt.toStringAsFixed(1)} kPa');
      buffer.writeln(
          'Emniyetli Taşıma Gücü q_all: ${bearing!.qAll.toStringAsFixed(1)} kPa');
      if (bearing!.warnings.isNotEmpty) {
        buffer.writeln('Hesap Uyarıları:');
        for (final w in bearing!.warnings) {
          buffer.writeln('  - $w');
        }
      }
    }
    buffer.writeln();
    buffer.writeln('Yasal Uyarı: $disclaimer');
    buffer.writeln('Veri Kaynakları: $sources');
    buffer.writeln(developer);
    return buffer.toString();
  }
}

/// Builds [ReportTextData] from assessment, coordinates, and optional bearing calculation.
ReportTextData buildReportTextData({
  Assessment? assessment,
  LatLng? coordinates,
  BearingResult? bearingResult,
  DateTime? date,
  String developerName = kDeveloperName,
}) {
  final now = date ?? DateTime.now();
  final d = now.day.toString().padLeft(2, '0');
  final m = now.month.toString().padLeft(2, '0');
  final y = now.year.toString();
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  final dateStr = '$d.$m.$y $hh:$mm';

  final coordStr = coordinates != null
      ? '${coordinates.latitude.toStringAsFixed(4)}° K, ${coordinates.longitude.toStringAsFixed(4)}° D'
      : 'Belirtilmedi';

  String geologyUnit = 'Veri yok';
  String soilType = 'Veri yok';
  String swellingPotential = 'Veri yok';
  String nearestFault = 'Fay verisi yok';
  String faultRiskLevel = 'Bilinmiyor';
  String overallRiskLevel = 'Veri yok';
  String recommendation = 'Veri yok – zemin etüdü gerekli';
  bool isDemo = false;
  bool hasData = false;

  if (assessment != null) {
    hasData = assessment.hasData;
    isDemo = assessment.isDemo;

    if (assessment.hasData) {
      geologyUnit = assessment.feature?.birim ?? 'Bilinmiyor';
      soilType = assessment.classification?.zeminTuru ?? 'Bilinmiyor';
      swellingPotential =
          assessment.classification?.sismePotansiyeli.turkishName ??
              'Bilinmiyor';
    }

    if (assessment.nearestFault != null) {
      final fault = assessment.nearestFault!;
      final faultName = fault.name ?? 'İsimsiz fay';
      nearestFault = '$faultName (${fault.distanceKm.toStringAsFixed(2)} km)';
      faultRiskLevel = assessment.faultRiskLevel?.turkishName ?? 'Bilinmiyor';
    } else {
      faultRiskLevel = 'Fay verisi yok';
    }

    if (assessment.overallRisk != null) {
      overallRiskLevel = assessment.overallRisk!.turkishName;
    }

    recommendation = assessment.recommendation;
  }

  return ReportTextData(
    title: 'Bursa Zemin – Ön Zemin Değerlendirme Raporu',
    dateString: dateStr,
    coordinatesString: coordStr,
    geologyUnit: geologyUnit,
    soilType: soilType,
    swellingPotential: swellingPotential,
    nearestFault: nearestFault,
    faultRiskLevel: faultRiskLevel,
    overallRiskLevel: overallRiskLevel,
    recommendation: recommendation,
    isDemo: isDemo,
    hasData: hasData,
    bearing: bearingResult != null
        ? BearingReportData.fromBearingResult(bearingResult)
        : null,
    disclaimer: kDisclaimer,
    sources: kSources,
    developer: 'Geliştirici: $developerName',
  );
}

/// Loads Turkish-capable TrueType fonts (Noto Sans Regular, Bold & Italic) from assets or file.
Future<PdfFontPair> loadReportFonts({
  ByteData? regularData,
  ByteData? boldData,
  ByteData? italicData,
}) async {
  if (regularData != null && boldData != null) {
    return PdfFontPair(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
      italic: italicData != null ? pw.Font.ttf(italicData) : null,
    );
  }

  ByteData reg;
  ByteData bld;
  ByteData? itl;

  try {
    reg = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    bld = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    itl = await rootBundle.load('assets/fonts/NotoSans-Italic.ttf');
  } catch (_) {
    // Fallback for standalone tests or CLI scripts without Flutter asset binding
    final regBytes =
        await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes();
    final bldBytes = await File('assets/fonts/NotoSans-Bold.ttf').readAsBytes();
    reg = regBytes.buffer.asByteData();
    bld = bldBytes.buffer.asByteData();
    final itlFile = File('assets/fonts/NotoSans-Italic.ttf');
    if (itlFile.existsSync()) {
      final itlBytes = await itlFile.readAsBytes();
      itl = itlBytes.buffer.asByteData();
    }
  }

  return PdfFontPair(
    regular: pw.Font.ttf(reg),
    bold: pw.Font.ttf(bld),
    italic: itl != null ? pw.Font.ttf(itl) : null,
  );
}

/// Builds a single A4 page PDF document per SPEC §6.
pw.Document buildPdfDocument({
  required ReportTextData reportData,
  Uint8List? mapImageBytes,
  required PdfFontPair fonts,
  bool compress = true,
}) {
  final doc = pw.Document(
    compress: compress,
    theme: pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.italic ?? fonts.regular,
      boldItalic: fonts.bold,
      fontFallback: [fonts.regular, fonts.bold],
    ),
    title: reportData.title,
    author: reportData.developer,
    creator: kAppName,
  );

  final italicFont = fonts.italic ?? fonts.regular;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // 1. Header (Title, Date, Coordinates)
            _buildHeader(reportData),
            pw.SizedBox(height: 8),

            // 2. Map snapshot or fallback
            _buildMapSnapshot(
              mapImageBytes,
              hasBearing: reportData.bearing != null,
              italicFont: italicFont,
            ),
            pw.SizedBox(height: 8),

            // 3. Ground Assessment Card
            _buildAssessmentSection(reportData),
            pw.SizedBox(height: 8),

            // 4. SPT Bearing Capacity Section (if present or omitted notice)
            _buildBearingSection(
              reportData.bearing,
              italicFont: italicFont,
            ),

            pw.Spacer(),

            // 5. Footer (Disclaimer, Sources, Developer)
            _buildFooter(reportData),
          ],
        );
      },
    ),
  );

  return doc;
}

/// Generates PDF bytes for the given report data and optional map snapshot.
Future<Uint8List> generatePdfReport({
  required ReportTextData reportData,
  Uint8List? mapImageBytes,
  PdfFontPair? fonts,
  bool compress = true,
}) async {
  final resolvedFonts = fonts ?? await loadReportFonts();
  final doc = buildPdfDocument(
    reportData: reportData,
    mapImageBytes: mapImageBytes,
    fonts: resolvedFonts,
    compress: compress,
  );
  return doc.save();
}

/// Shares or saves the generated PDF report via the platform share sheet.
Future<bool> sharePdfReport({
  required Uint8List pdfBytes,
  String filename = 'Bursa_Zemin_Raporu.pdf',
}) async {
  return Printing.sharePdf(
    bytes: pdfBytes,
    filename: filename,
    subject: 'Bursa Zemin Ön Değerlendirme Raporu',
  );
}

// ---------------------------------------------------------------------------
// Private Widget Builders for PDF Layout
// ---------------------------------------------------------------------------

pw.Widget _buildHeader(ReportTextData report) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          color: PdfColor.fromInt(0xFF00796B), // Teal 700
          width: 1.5,
        ),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              kAppName,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF00796B),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Ön Zemin Değerlendirme ve Taşıma Gücü Raporu',
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Tarih: ${report.dateString}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Koordinat: ${report.coordinatesString}',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Builds the map snapshot widget or fallback notice.
///
/// Exposed for testing fallback behavior when map capture fails or bytes are corrupted.
@visibleForTesting
pw.Widget buildMapSnapshotWidget(
  Uint8List? mapBytes, {
  required bool hasBearing,
  pw.Font? italicFont,
}) =>
    _buildMapSnapshot(mapBytes, hasBearing: hasBearing, italicFont: italicFont);

pw.Widget _buildMapSnapshot(
  Uint8List? mapBytes, {
  required bool hasBearing,
  pw.Font? italicFont,
}) {
  if (mapBytes != null && mapBytes.isNotEmpty) {
    try {
      final img = pw.MemoryImage(mapBytes);
      return pw.Container(
        height: hasBearing ? 120 : 160,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Image(
            img,
            fit: pw.BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      // Degrade gracefully if image bytes cannot be decoded
    }
  }

  return pw.Container(
    height: 36,
    width: double.infinity,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
    ),
    child: pw.Text(
      'Harita görüntüsü alınamadı',
      style: pw.TextStyle(
        font: italicFont,
        fontSize: 8,
        color: PdfColors.grey600,
      ),
    ),
  );
}

pw.Widget _buildAssessmentSection(ReportTextData report) {
  PdfColor badgeBg = const PdfColor.fromInt(0xFFE8F5E9);
  PdfColor badgeColor = const PdfColor.fromInt(0xFF2E7D32);

  if (report.overallRiskLevel == 'Orta') {
    badgeBg = const PdfColor.fromInt(0xFFFFF8E1);
    badgeColor = const PdfColor.fromInt(0xFFE65100);
  } else if (report.overallRiskLevel == 'Yüksek') {
    badgeBg = const PdfColor.fromInt(0xFFFFEBEE);
    badgeColor = const PdfColor.fromInt(0xFFC62828);
  } else if (report.overallRiskLevel == 'Veri yok') {
    badgeBg = const PdfColor.fromInt(0xFFF5F5F5);
    badgeColor = const PdfColor.fromInt(0xFF616161);
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Section Title & Badges
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ZEMİN ÖN DEĞERLENDİRMESİ',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF004D40),
              ),
            ),
            pw.Row(
              children: [
                if (report.isDemo) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFF3E0),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      'DEMO VERİ',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFFE65100),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                ],
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: badgeBg,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    'Genel Risk: ${report.overallRiskLevel}',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey200, thickness: 0.5),
        pw.SizedBox(height: 4),

        // 2-column key-value metrics
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildKeyValue('Jeolojik Birim', report.geologyUnit),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _buildKeyValue('En Yakın Fay', report.nearestFault),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildKeyValue('Zemin Türü', report.soilType),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _buildKeyValue('Fay Risk Düzeyi', report.faultRiskLevel),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              child:
                  _buildKeyValue('Şişme Potansiyeli', report.swellingPotential),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _buildKeyValue('Öneri', report.recommendation,
                  isHighlight: true),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildBearingSection(
  BearingReportData? bearing, {
  pw.Font? italicFont,
}) {
  if (bearing == null) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Text(
        'SPT Taşıma Gücü Hesabı: Bu değerlendirme için SPT hesaplaması yapılmamıştır.',
        style: pw.TextStyle(
          font: italicFont,
          fontSize: 7.5,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SPT TAŞIMA GÜCÜ HESABI (TERZAGHI GENEL KAYMA)',
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF004D40),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Divider(color: PdfColors.grey200, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left column: Inputs and derived soil properties
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildKeyValue('Zemin / SPT',
                      '${bearing.soilKind} (N: ${bearing.nValue}, N_düz: ${bearing.effectiveN.toStringAsFixed(1)})'),
                  pw.SizedBox(height: 3),
                  _buildKeyValue('Temel Geometrisi',
                      '${bearing.footingShape} (B: ${bearing.b.toStringAsFixed(2)} m, Df: ${bearing.df.toStringAsFixed(2)} m)'),
                  pw.SizedBox(height: 3),
                  _buildKeyValue('Parametreler',
                      'γ: ${bearing.gamma.toStringAsFixed(1)} kN/m³, FS: ${bearing.fs.toStringAsFixed(1)}'),
                  pw.SizedBox(height: 3),
                  if (bearing.phiDeg != null)
                    _buildKeyValue('İçsel Sürtünme Açısı (φ)',
                        '${bearing.phiDeg!.toStringAsFixed(2)}°')
                  else if (bearing.cuKpa != null)
                    _buildKeyValue('Drenajsız Mukavemet (cu)',
                        '${bearing.cuKpa!.toStringAsFixed(1)} kPa'),
                ],
              ),
            ),
            pw.SizedBox(width: 12),

            // Right column: Intermediate factors & Results
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildKeyValue('Taşıma Katsayıları',
                      'Nc: ${bearing.nc.toStringAsFixed(2)}, Nq: ${bearing.nq.toStringAsFixed(2)}, Nγ: ${bearing.ng.toStringAsFixed(2)}'),
                  pw.SizedBox(height: 3),
                  _buildKeyValue('Sürşarj Basıncı (q)',
                      '${bearing.q.toStringAsFixed(1)} kPa'),
                  pw.SizedBox(height: 5),

                  // Results Highlight Box
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE8F5E9),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Nihai Taşıma Gücü (q_ult)',
                                style: const pw.TextStyle(
                                    fontSize: 7, color: PdfColors.grey800)),
                            pw.Text(
                              '${bearing.qUlt.toStringAsFixed(1)} kPa',
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Emniyetli Taşıma Gücü (q_all)',
                                style: const pw.TextStyle(
                                    fontSize: 7, color: PdfColors.grey800)),
                            pw.Text(
                              '${bearing.qAll.toStringAsFixed(1)} kPa',
                              style: pw.TextStyle(
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (bearing.warnings.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey200, thickness: 0.5),
          pw.SizedBox(height: 2),
          for (final w in bearing.warnings)
            pw.Text(
              '• $w',
              style: pw.TextStyle(
                font: italicFont,
                fontSize: 6.5,
                color: PdfColors.amber900,
              ),
            ),
        ],
      ],
    ),
  );
}

pw.Widget _buildKeyValue(String key, String value, {bool isHighlight = false}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '$key: ',
        style: const pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey700,
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHighlight
                ? const PdfColor.fromInt(0xFF00796B)
                : PdfColors.black,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildFooter(ReportTextData report) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Disclaimer Banner (R10)
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFFF8E1), // Amber 50
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFFFD54F), // Amber 300
            width: 0.8,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'YASAL UYARI: ${report.disclaimer}',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFFB71C1C), // Red 900
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Bu rapor yalnızca bilgilendirme ve ön değerlendirme amaçlı hazırlanmıştır. Geoteknik tasarım ve inşaat uygulamalarında resmi zemin etüt raporu yerine kullanılamaz.',
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),

      // Attribution & Developer
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Veri Kaynakları: ${report.sources}',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            report.developer,
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    ],
  );
}
