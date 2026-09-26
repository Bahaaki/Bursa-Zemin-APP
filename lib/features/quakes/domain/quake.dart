import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Exception thrown when AFAD earthquake JSON fails to parse.
class QuakeParseException implements Exception {
  final String message;
  const QuakeParseException(this.message);

  @override
  String toString() => 'QuakeParseException: $message';
}

/// Domain model representing an earthquake recorded by AFAD (SPEC §5).
/// Pure Dart model with zero Flutter imports (R8).
class Quake {
  final String eventId;
  final String location;
  final double latitude;
  final double longitude;
  final double depth;
  final String type;
  final double magnitude;
  final String country;
  final String? province;
  final String? district;
  final String? neighborhood;
  final DateTime date;
  final double? rms;
  final bool? isEventUpdate;

  const Quake({
    required this.eventId,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.depth,
    required this.type,
    required this.magnitude,
    required this.country,
    this.province,
    this.district,
    this.neighborhood,
    required this.date,
    this.rms,
    this.isEventUpdate,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  /// Factory constructor to parse from a single JSON map from AFAD.
  factory Quake.fromJson(Map<String, dynamic> json) {
    try {
      final eventId = json['eventID']?.toString() ?? '';
      if (eventId.isEmpty) {
        throw const QuakeParseException('Eksik eventID alanı');
      }

      final location = json['location'] as String? ?? 'Bilinmeyen Konum';

      final latRaw = json['latitude'];
      final lonRaw = json['longitude'];
      final depthRaw = json['depth'];
      final magRaw = json['magnitude'];

      if (latRaw == null ||
          lonRaw == null ||
          depthRaw == null ||
          magRaw == null) {
        throw const QuakeParseException(
            'Zorunlu koordinat/büyüklük alanları eksik');
      }

      final latitude =
          latRaw is num ? latRaw.toDouble() : double.parse(latRaw.toString());
      final longitude =
          lonRaw is num ? lonRaw.toDouble() : double.parse(lonRaw.toString());
      final depth = depthRaw is num
          ? depthRaw.toDouble()
          : double.parse(depthRaw.toString());
      final magnitude =
          magRaw is num ? magRaw.toDouble() : double.parse(magRaw.toString());

      final type = json['type'] as String? ?? 'ML';
      final country = json['country'] as String? ?? 'Türkiye';
      final province = json['province'] as String?;
      final district = json['district'] as String?;
      final neighborhood = json['neighborhood'] as String?;

      final dateStr = json['date'] as String?;
      if (dateStr == null || dateStr.isEmpty) {
        throw const QuakeParseException('Eksik date alanı');
      }
      final date = DateTime.parse(dateStr);

      final rmsRaw = json['rms'];
      final rms = rmsRaw == null
          ? null
          : (rmsRaw is num
              ? rmsRaw.toDouble()
              : double.tryParse(rmsRaw.toString()));

      final isEventUpdate = json['isEventUpdate'] as bool?;

      return Quake(
        eventId: eventId,
        location: location,
        latitude: latitude,
        longitude: longitude,
        depth: depth,
        type: type,
        magnitude: magnitude,
        country: country,
        province: province,
        district: district,
        neighborhood: neighborhood,
        date: date,
        rms: rms,
        isEventUpdate: isEventUpdate,
      );
    } catch (e) {
      if (e is QuakeParseException) rethrow;
      throw QuakeParseException('Deprem kaydı ayrıştırılamadı: $e');
    }
  }

  /// Parse a JSON list string returned by AFAD API.
  static List<Quake> parseList(String rawJson) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (e) {
      throw QuakeParseException('Geçersiz JSON formatı: $e');
    }

    if (decoded is! List) {
      throw const QuakeParseException('JSON kökü bir dizi (List) olmalıdır');
    }

    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const QuakeParseException('Dizi öğeleri Map olmalıdır');
      }
      return Quake.fromJson(item);
    }).toList();
  }
}
