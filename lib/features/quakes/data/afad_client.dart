import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../domain/quake.dart';

/// Base typed exception for AFAD client errors.
abstract class AfadClientException implements Exception {
  final String message;
  const AfadClientException(this.message);

  @override
  String toString() => message;
}

/// Thrown when AFAD API request exceeds timeout (10 seconds).
class AfadTimeoutException extends AfadClientException {
  const AfadTimeoutException([
    super.message = 'AFAD servisi yanıt vermedi (zaman aşımı).',
  ]);
}

/// Thrown on network/socket/connection errors.
class AfadNetworkException extends AfadClientException {
  const AfadNetworkException([
    super.message =
        'AFAD servisine bağlanılamadı. İnternet bağlantınızı kontrol ediniz.',
  ]);
}

/// Thrown when AFAD response format or JSON parsing fails.
class AfadParseException extends AfadClientException {
  const AfadParseException([
    super.message = 'AFAD deprem verisi ayrıştırılamadı.',
  ]);
}

/// Thrown when AFAD server returns non-200 HTTP status code.
class AfadHttpException extends AfadClientException {
  final int statusCode;

  const AfadHttpException(
    this.statusCode, [
    super.message = 'AFAD servisi sunucu hatası bildirdi',
  ]);

  @override
  String toString() => '$message (HTTP $statusCode)';
}

/// HTTP client for AFAD earthquake event service (SPEC §5).
///
/// Features:
/// - 10-second request timeout
/// - 10-minute in-memory caching
/// - Typed exceptions (timeout, network, parse, http)
/// - Configurable bounding box and minimum magnitude (default 2.0)
class AfadClient {
  static const String defaultEndpoint =
      'https://deprem.afad.gov.tr/apiv2/event/filter';

  final http.Client _httpClient;
  final Duration timeout;
  final Duration cacheDuration;
  final String endpoint;

  List<Quake>? _cache;
  DateTime? _cacheTimestamp;

  AfadClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.cacheDuration = const Duration(minutes: 10),
    this.endpoint = defaultEndpoint,
  }) : _httpClient = httpClient ?? http.Client();

  /// Returns cached earthquakes if available and fresh.
  List<Quake>? get cachedQuakes {
    if (_cache != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < cacheDuration) {
        return _cache;
      }
    }
    return null;
  }

  /// Clears in-memory cache.
  void clearCache() {
    _cache = null;
    _cacheTimestamp = null;
  }

  /// Formats DateTime to AFAD expected string: `YYYY-MM-DD HH:mm:ss`.
  static String formatAfadDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  /// Builds the AFAD query URI for the given parameters (SPEC §5).
  static Uri buildUri({
    String endpoint = defaultEndpoint,
    required DateTime start,
    required DateTime end,
    GeoBoundingBox boundingBox = kBursaBoundingBox,
    double minMag = 2.0,
  }) {
    return Uri.parse(endpoint).replace(queryParameters: {
      'start': formatAfadDate(start),
      'end': formatAfadDate(end),
      'minlat': boundingBox.minLat.toString(),
      'maxlat': boundingBox.maxLat.toString(),
      'minlon': boundingBox.minLon.toString(),
      'maxlon': boundingBox.maxLon.toString(),
      'minmag': minMag.toString(),
    });
  }

  /// Fetches earthquakes within Bursa bounding box for the last 30 days.
  ///
  /// Uses in-memory cache (10 min) unless [forceRefresh] is true.
  Future<List<Quake>> fetchEarthquakes({
    DateTime? start,
    DateTime? end,
    GeoBoundingBox boundingBox = kBursaBoundingBox,
    double minMag = 2.0,
    bool forceRefresh = false,
  }) async {
    // 1. Check in-memory cache
    if (!forceRefresh) {
      final cached = cachedQuakes;
      if (cached != null) {
        return cached;
      }
    }

    // 2. Compute date range (default: last 30 days)
    final now = end ?? DateTime.now();
    final startDate = start ?? now.subtract(const Duration(days: 30));

    final uri = buildUri(
      endpoint: endpoint,
      start: startDate,
      end: now,
      boundingBox: boundingBox,
      minMag: minMag,
    );

    try {
      final response = await _httpClient.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode != 200) {
        throw AfadHttpException(response.statusCode);
      }

      final quakes = Quake.parseList(response.body);

      // Cache fresh result
      _cache = quakes;
      _cacheTimestamp = DateTime.now();

      return quakes;
    } on TimeoutException {
      throw const AfadTimeoutException();
    } on SocketException catch (e) {
      throw AfadNetworkException('Ağ hatası: ${e.message}');
    } on http.ClientException catch (e) {
      throw AfadNetworkException('Bağlantı hatası: ${e.message}');
    } on QuakeParseException catch (e) {
      throw AfadParseException('Ayrıştırma hatası: ${e.message}');
    } catch (e) {
      if (e is AfadClientException) rethrow;
      throw AfadNetworkException('Beklenmeyen hata: $e');
    }
  }

  /// Close client resources.
  void close() {
    _httpClient.close();
  }
}
