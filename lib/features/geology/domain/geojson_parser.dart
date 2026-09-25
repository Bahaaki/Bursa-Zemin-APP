import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'models.dart';

/// Exception thrown when GeoJSON parsing fails.
class GeoJsonParseException implements FormatException {
  @override
  final String message;
  @override
  final dynamic source;
  @override
  final int? offset;

  const GeoJsonParseException(this.message, [this.source, this.offset]);

  @override
  String toString() => 'GeoJsonParseException: $message';
}

/// Parses a GeoJSON FeatureCollection string into a list of [GeoFeature]s.
///
/// Throws [GeoJsonParseException] on:
/// - Malformed JSON
/// - Not a FeatureCollection
/// - Disallowed geometry types (only Polygon and MultiPolygon allowed)
/// - Missing or empty `birim` property
List<GeoFeature> parseGeologyGeoJson(String jsonStr) {
  final Map<String, dynamic> root =
      _decodeAndValidateCollection(jsonStr, 'Geology');
  final featuresList = root['features'] as List;
  final results = <GeoFeature>[];

  for (int i = 0; i < featuresList.length; i++) {
    final feat = featuresList[i];
    if (feat is! Map<String, dynamic>) {
      throw GeoJsonParseException('Feature at index $i is not a JSON object.');
    }

    final props = feat['properties'];
    if (props is! Map<String, dynamic>) {
      throw GeoJsonParseException(
          'Feature at index $i is missing "properties" object.');
    }

    final birim = props['birim'];
    if (birim is! String || birim.trim().isEmpty) {
      throw GeoJsonParseException(
        'Feature at index $i is missing required non-empty "birim" property.',
      );
    }

    final geom = feat['geometry'];
    if (geom is! Map<String, dynamic>) {
      throw GeoJsonParseException(
          'Feature at index $i is missing "geometry" object.');
    }

    final geomType = geom['type'];
    final coords = geom['coordinates'];
    final shapes = <PolygonShape>[];

    if (geomType == 'Polygon') {
      shapes.add(
          _parsePolygonCoordinates(coords, 'Feature at index $i ($birim)'));
    } else if (geomType == 'MultiPolygon') {
      if (coords is! List || coords.isEmpty) {
        throw GeoJsonParseException(
          'Feature at index $i ($birim): MultiPolygon coordinates must be a non-empty array.',
        );
      }
      for (int pi = 0; pi < coords.length; pi++) {
        shapes.add(
          _parsePolygonCoordinates(
              coords[pi], 'Feature at index $i ($birim) polygon $pi'),
        );
      }
    } else {
      throw GeoJsonParseException(
        'Feature at index $i ($birim) has disallowed geometry type "$geomType". '
        'Allowed: Polygon, MultiPolygon.',
      );
    }

    results.add(GeoFeature(
      id: feat['id']?.toString() ?? 'feat_$i',
      properties: props,
      shapes: shapes,
    ));
  }

  return results;
}

/// Parses a GeoJSON FeatureCollection string into a list of [FaultLine]s.
///
/// Throws [GeoJsonParseException] on:
/// - Malformed JSON
/// - Not a FeatureCollection
/// - Disallowed geometry types (only LineString and MultiLineString allowed)
List<FaultLine> parseFaultsGeoJson(String jsonStr) {
  final Map<String, dynamic> root =
      _decodeAndValidateCollection(jsonStr, 'Faults');
  final featuresList = root['features'] as List;
  final results = <FaultLine>[];

  for (int i = 0; i < featuresList.length; i++) {
    final feat = featuresList[i];
    if (feat is! Map<String, dynamic>) {
      throw GeoJsonParseException(
          'Fault feature at index $i is not a JSON object.');
    }

    final props = (feat['properties'] is Map<String, dynamic>)
        ? feat['properties'] as Map<String, dynamic>
        : <String, dynamic>{};

    final name = props['ad'] as String?;
    final isDemo = feat['demo'] == true || props['demo'] == true;

    final geom = feat['geometry'];
    if (geom is! Map<String, dynamic>) {
      throw GeoJsonParseException(
          'Fault feature at index $i is missing "geometry" object.');
    }

    final geomType = geom['type'];
    final coords = geom['coordinates'];
    final lines = <List<LatLng>>[];

    if (geomType == 'LineString') {
      lines.add(_parseLineStringCoordinates(coords, 'Fault at index $i'));
    } else if (geomType == 'MultiLineString') {
      if (coords is! List || coords.isEmpty) {
        throw GeoJsonParseException(
          'Fault at index $i: MultiLineString coordinates must be a non-empty array.',
        );
      }
      for (int li = 0; li < coords.length; li++) {
        lines.add(
          _parseLineStringCoordinates(coords[li], 'Fault at index $i line $li'),
        );
      }
    } else {
      throw GeoJsonParseException(
        'Fault feature at index $i has disallowed geometry type "$geomType". '
        'Allowed: LineString, MultiLineString.',
      );
    }

    results.add(FaultLine(
      name: name,
      lines: lines,
      isDemo: isDemo,
    ));
  }

  return results;
}

Map<String, dynamic> _decodeAndValidateCollection(
    String jsonStr, String label) {
  dynamic decoded;
  try {
    decoded = jsonDecode(jsonStr);
  } catch (e) {
    throw GeoJsonParseException('Malformed JSON for $label GeoJSON: $e');
  }

  if (decoded is! Map<String, dynamic>) {
    throw GeoJsonParseException('$label GeoJSON root must be a JSON object.');
  }

  if (decoded['type'] != 'FeatureCollection') {
    throw GeoJsonParseException(
      '$label GeoJSON root type must be "FeatureCollection", got "${decoded['type']}".',
    );
  }

  final features = decoded['features'];
  if (features is! List) {
    throw GeoJsonParseException(
        '$label GeoJSON must contain a "features" array.');
  }

  return decoded;
}

PolygonShape _parsePolygonCoordinates(dynamic coords, String context) {
  if (coords is! List || coords.isEmpty) {
    throw GeoJsonParseException(
        '$context: Polygon coordinates must be a non-empty array.');
  }

  final outer = _parseLinearRing(coords.first, '$context outer ring');
  final holes = <List<LatLng>>[];

  for (int i = 1; i < coords.length; i++) {
    holes.add(_parseLinearRing(coords[i], '$context hole $i'));
  }

  return PolygonShape(outerRing: outer, holes: holes);
}

List<LatLng> _parseLinearRing(dynamic ringCoords, String context) {
  if (ringCoords is! List || ringCoords.length < 4) {
    throw GeoJsonParseException(
      '$context: LinearRing must have at least 4 coordinates (got ${ringCoords is List ? ringCoords.length : "non-list"}).',
    );
  }

  final points = <LatLng>[];
  for (int i = 0; i < ringCoords.length; i++) {
    points.add(_parsePosition(ringCoords[i], '$context position $i'));
  }

  return points;
}

List<LatLng> _parseLineStringCoordinates(dynamic lineCoords, String context) {
  if (lineCoords is! List || lineCoords.length < 2) {
    throw GeoJsonParseException(
      '$context: LineString must have at least 2 coordinates (got ${lineCoords is List ? lineCoords.length : "non-list"}).',
    );
  }

  final points = <LatLng>[];
  for (int i = 0; i < lineCoords.length; i++) {
    points.add(_parsePosition(lineCoords[i], '$context position $i'));
  }

  return points;
}

LatLng _parsePosition(dynamic pos, String context) {
  if (pos is! List || pos.length < 2) {
    throw GeoJsonParseException(
        '$context: Coordinate position must be [lon, lat].');
  }

  final lon = pos[0];
  final lat = pos[1];

  if (lon is! num || lat is! num) {
    throw GeoJsonParseException(
        '$context: Coordinates must be numbers, got [$lon, $lat].');
  }

  // GeoJSON is [lon, lat], LatLng takes (lat, lon)
  return LatLng(lat.toDouble(), lon.toDouble());
}
