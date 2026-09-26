/// Application-wide constants.
const String kAppName = 'Bursa Zemin';
const String kDeveloperName = 'Ahmed';
const String kAppId = 'com.ahmed.bursazemin';

/// Disclaimer shown in the info sheet, calculator, and PDF.
const String kDisclaimer = 'Ön değerlendirmedir, zemin etüdünün yerine geçmez.';

/// Data source attribution.
const String kSources = 'MTA, AFAD, OpenStreetMap';

/// Default map center (Bursa).
const double kDefaultLat = 40.19;
const double kDefaultLon = 29.06;
const int kDefaultZoom = 10;

/// Geographic bounding box defining [minLat, maxLat, minLon, maxLon].
class GeoBoundingBox {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const GeoBoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });
}

/// Bounding box covering Bursa and its active seismic vicinity (SPEC §5).
const GeoBoundingBox kBursaBoundingBox = GeoBoundingBox(
  minLat: 39.0,
  maxLat: 41.0,
  minLon: 27.5,
  maxLon: 30.5,
);
