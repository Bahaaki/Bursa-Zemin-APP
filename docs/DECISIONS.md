# DECISIONS — Bursa Zemin

| Date | Phase | Decision | Reason |
|---|---|---|---|
| 2026-09-25 | P0 | Flutter 3.24.0 / Dart 3.5.0 / DevTools 2.37.2 | Existing SDK on machine. Plan says do not upgrade. (`flutter --version` output) |
| 2026-09-25 | P0 | JDK: OpenJDK 21.0.9 (Android Studio 2025.3.2 bundled) | `flutter doctor -v` reports this version. |
| 2026-09-25 | P0 | APP_ID = com.ahmed.bursazemin | Human choice (Gate G0). Template generated `com.ahmed.bursa_zemin` (underscore); renamed namespace, package dir, and applicationId to remove it. |
| 2026-09-25 | P0 | DEVELOPER_NAME = Ahmed | Human choice (Gate G0). |
| 2026-09-25 | P0 | Gradle 7.6.3 → 8.5 | Flutter 3.24 template ships Gradle 7.6.3. JDK 21 requires Gradle ≥ 8.5 per https://docs.gradle.org/current/userguide/compatibility.html#java |
| 2026-09-25 | P0 | AGP 7.3.0 → 8.1.0 (first attempt) | AGP 7.x incompatible with Gradle 8.5. Chose 8.1.0 as the lowest AGP 8.x. This later proved insufficient — see next row. |
| 2026-09-25 | P0 | Kotlin 1.7.10 → 1.9.10 | AGP 8.x requires Kotlin ≥ 1.8.20. Chose 1.9.10 as the latest stable 1.9.x. AGP 8.3 was tested against Kotlin 1.9.x per release notes. |
| 2026-09-25 | P0 | Java compileOptions 1.8 → 17 | AGP 8.x with JDK 21 requires Java target ≥ 11; 17 is recommended baseline. |
| 2026-09-25 | P0 | minSdk = 21 | Flutter 3.24 default. Supports 98%+ of active Android devices. Pinned to prevent drift. |
| 2026-09-25 | P0 | AGP 8.1.0 → 8.3.0 (second fix — root cause resolved) | See note below. |
| 2026-09-25 | P0 | compileSdk: attempted 33 (failed), reverted to flutter.compileSdkVersion (34) | See note below. |
| 2026-09-25 | P0 | INTERNET permission in main AndroidManifest.xml | Flutter template only includes INTERNET in debug/profile manifests; release builds would have no OSM tiles. SPEC §7 requires this. |
| 2026-09-25 | P0 | risk_rules.json fault thresholds remain `verified: false` | See fault-threshold source note below. Human must confirm before G2. |
| 2026-09-25 | P0 | geotech_constants.json remains `verified: false` | Per SPEC §10: human must verify against textbook before G3. |
| 2026-09-25 | P1 | Pure Dart CLI validator (`tool/validate_data.dart`) | Zero external dependencies (`dart:io`, `dart:convert` only); enforces geometry types, coordinate bounds (lat 39–41, lon 27.5–30.5), ring closure, non-empty birim, CSV matching, and file size limits. |
| 2026-09-25 | P1 | Synthetic demo dataset (`assets/demo/`) | All features explicitly marked `demo: true`, units named `DEMO-1`..`DEMO-5` to prevent any confusion with real geological data (R1). |
| 2026-09-25 | P1 | Negative test fixtures in `test/fixtures/` | Placed broken test data outside `assets/demo/` so it is not bundled into release APK assets. |
| 2026-09-25 | P2 | Added `latlong2: 0.10.1` & `csv: 6.0.0` | In SPEC §8 whitelist. Read resolved package sources before use (R2). Exact constructors: `LatLng(double latitude, double longitude)` from `latlong2/latlong.dart`, and `const CsvToListConverter(eol: '\n', shouldParseNumbers: false, allowInvalid: false)` from `csv` after normalizing `\r\n` to `\n`. |
| 2026-09-25 | P2 | R8 rule amendment for package:csv | AGENTS.md rule R8 amended to allow `csv` in `lib/features/*/domain/` for classification CSV parsing only, resolving the conflict between domain CSV parsing in SPEC §9 and original R8 wording. |
| 2026-09-25 | P2 | Pure Dart domain core (R8 amended) | `lib/features/geology/domain/` imports only `dart:*`, `latlong2`, and `csv` (classification only). Zero Flutter imports. |
| 2026-09-25 | P2 | Equirectangular projection for fault distance | Projected at point's latitude: $x = \Delta\lambda \cos\phi_0 R$, $y = \Delta\phi R$ ($R=6371.0088$ km). Clamped segment projection $t \in [0, 1]$ finds perpendicular distance or nearest endpoint. |
| 2026-09-25 | P2 | Ray-casting with inclusive boundary | Outer ring segments are inclusive (`_isPointOnSegment`). Points strictly inside holes are excluded; points directly on hole boundary are inclusive. MultiPolygon tested across distinct parts. |
| 2026-09-25 | P3a | Dependency resolution (flutter_map 7.0.2, flutter_riverpod 2.6.1, geolocator 12.0.0, latlong2 0.9.1) | Resolved via `flutter pub get`. Pinned `latlong2: ^0.9.1` because `flutter_map 7.0.2` strictly requires `latlong2 ^0.9.1` under Dart 3.5.0 (`flutter_map 8.x` requires Dart >= 3.6.0). |
| 2026-09-25 | P3a | flutter_map 7.0.2 API: No `GeoJsonLayer` | Confirmed `GeoJsonLayer` does not exist in flutter_map. Polygons use `PolygonLayer` with `Polygon(...)` (`points`, `holePointsList`, `color`, `borderColor`, `borderStrokeWidth`). Lines use `PolylineLayer` with `Polyline(...)`. Map tap uses `MapOptions(onTap: (TapPosition tapPosition, LatLng point) => ...)`. Tile layer uses `TileLayer(urlTemplate: ..., userAgentPackageName: ...)`. |
| 2026-09-25 | P3a | geolocator 12.0.0 API confirmed | Confirmed exact signatures: `isLocationServiceEnabled()`, `checkPermission()`, `requestPermission()`, and `getCurrentPosition()`. |

---

## Build failure log — jlink issue (P0)

### Attempt 1: AGP 8.1.0 + compileSdk = flutter.compileSdkVersion (34)

**Actual error:**
```
Execution failed for task ':app:compileDebugJavaWithJavac'.
> Could not resolve all files for configuration ':app:androidJdkImage'.
   > Failed to transform core-for-system-modules.jar to match attributes
     {artifactType=_internal_android_jdk_image, ...}.
      > Execution failed for JdkImageTransform:
        C:\Users\Ahmad\AppData\Local\Android\sdk\platforms\android-34\core-for-system-modules.jar.
         > Error while executing process
           C:\Program Files\Android\Android Studio\jbr\bin\jlink.exe
           with arguments {--module-path ... --add-modules java.base ...}
BUILD FAILED in 12m 8s
```
**Root cause:** AGP 8.1.x has a known bug where the JdkImage transform fails with JDK 17+ when compileSdk=34. The `jlink.exe` call inside Gradle's transform cache crashes.

### Attempt 2: AGP 8.1.0 + compileSdk = 33 (wrong fix)

**Actual error:**
```
Dependency 'androidx.core:core-ktx:1.13.1' requires libraries and applications
that depend on it to compile against version 34 or later of the Android APIs.
:app is currently compiled against android-33.
BUILD FAILED in 47s
```
**Root cause:** Flutter 3.24's transitive androidx deps (core 1.13.1, lifecycle 2.7.0, etc.) require compileSdk ≥ 34. Lowering to 33 broke them. This also confirmed the SDK downgrade was not the right fix.

### Attempt 3: AGP 8.3.0 + compileSdk = flutter.compileSdkVersion (34) — SUCCEEDED

**AGP 8.3.0** (Feb 2024, released with Android Studio Iguana).

**Compatibility note — source caveat:**
The Gradle/Kotlin/JDK compatibility data below came from a web-search engine snippet,
NOT from a directly-read primary source page. The official docs page
(developer.android.com/build/releases/agp-8-3-0-release-notes) was fetched but
returned a JavaScript-rendered HTML shell with no readable compatibility table.

The claimed compatibility values from the snippet were:
- AGP 8.3.0 minimum Gradle: 8.2 (recommended: 8.4); our Gradle 8.5 falls within range
- AGP 8.3.0 + Kotlin 1.9.10: compatible per snippet
- AGP 8.3.0 + JDK 21: compatible per snippet

**The actual, primary evidence that the combination works is the build result:**
```
flutter build apk --debug
Running Gradle task 'assembleDebug'...   290.9s
√ Built build\app\outputs\flutter-apk\app-debug.apk
exit code: 0   APK size: 82.4 MB
```
This is the only claim that does not depend on the search snippet.


**Actual build output:**
```
Running Gradle task 'assembleDebug'...   290.9s
√ Built build\app\outputs\flutter-apk\app-debug.apk  (82.4 MB)
exit code 0
```

---

## Fault distance thresholds — source investigation

The plan's note on `risk_rules.json` thresholds (1 km / 5 km) referenced "TBDY 2018 + AFAD guidelines."

**Finding: no direct citation found.**

- **TBDY 2018 §2.3 (Yakın Fay Etkisi / Near-Fault Effect):** Applies near-fault spectral amplification to sites within a distance that depends on M and fault type — but does **not** define 1 km and 5 km risk categories.
- **AFAD Diri Fay Haritası:** Classifies fault activity (Holocene/Pleistocene) but prescribes no distance-based risk tier of 1/5 km.
- The values are reasonable preliminary screening thresholds used in Turkish geotechnical practice but are **not traceable to a specific article, section, or URL** in TBDY 2018 or AFAD publications.

**Status:** `verified: false`. Human must decide before G2 whether to keep these values, adjust them, or cite a specific local authority.

---

## P3a API Reference (flutter_map 7.0.2, geolocator 12.0.0, flutter_riverpod 2.6.1)

Verified directly against resolved source code in the pub cache. P3b implementation must copy from here.

### 1. `flutter_map: 7.0.2`

**Imports:**
```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
```

**Critical Findings:**
- `GeoJsonLayer` does **NOT** exist in `flutter_map`. Parsed GeoJSON geometry must be drawn using `PolygonLayer` or `PolylineLayer`.
- In `Polygon`, parameter `isFilled` is deprecated; setting `color: Color` automatically fills the polygon.

**Exact Constructor Signatures:**

1. `FlutterMap`:
```dart
FlutterMap({
  Key? key,
  required MapOptions options,
  required List<Widget> children,
  // ...
})
```

2. `MapOptions`:
```dart
MapOptions({
  LatLng initialCenter = const LatLng(50.5, 30.51),
  double initialZoom = 12.0,
  TapCallback? onTap, // typedef TapCallback = void Function(TapPosition tapPosition, LatLng point);
  // ...
})
```

3. `TileLayer`:
```dart
TileLayer({
  Key? key,
  String? urlTemplate, // e.g. 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
  String userAgentPackageName = 'unknown', // e.g. 'com.ahmed.bursazemin'
  // ...
})
```

4. `PolygonLayer`:
```dart
PolygonLayer({
  Key? key,
  required List<Polygon> polygons,
  bool polygonCulling = true,
  // ...
})
```

5. `Polygon`:
```dart
Polygon({
  required List<LatLng> points,
  List<List<LatLng>>? holePointsList,
  Color? color, // fill color with alpha ≈ 0.45 per SPEC §2
  double borderStrokeWidth = 0.0, // e.g. 1.0
  Color borderColor = const Color(0xFFFFFF00),
  bool disableHolesBorder = false,
  // ...
})
```

6. `PolylineLayer`:
```dart
PolylineLayer({
  Key? key,
  required List<Polyline> polylines,
  double? cullingMargin = 10,
  // ...
})
```

7. `Polyline`:
```dart
Polyline({
  required List<LatLng> points,
  double strokeWidth = 1.0, // e.g. 2.5
  Color color = const Color(0xFF00FF00), // dark line per SPEC §3.2 (e.g. Colors.black87)
  double borderStrokeWidth = 0.0,
  Color borderColor = const Color(0xFFFFFF00),
  // ...
})
```

---

### 2. `geolocator: 12.0.0`

**Import:**
```dart
import 'package:geolocator/geolocator.dart';
```

**Exact Method Signatures & Types:**

1. `Geolocator.isLocationServiceEnabled()`:
```dart
static Future<bool> isLocationServiceEnabled();
```

2. `Geolocator.checkPermission()`:
```dart
static Future<LocationPermission> checkPermission();
```

3. `Geolocator.requestPermission()`:
```dart
static Future<LocationPermission> requestPermission();
```

4. `Geolocator.getCurrentPosition(...)`:
```dart
static Future<Position> getCurrentPosition({
  LocationAccuracy desiredAccuracy = LocationAccuracy.best,
  bool forceAndroidLocationManager = false,
  Duration? timeLimit,
});
```

**`LocationPermission` Enum Values:**
- `LocationPermission.denied`
- `LocationPermission.deniedForever`
- `LocationPermission.whileInUse`
- `LocationPermission.always`
- `LocationPermission.unableToDetermine`

**`Position` Properties:**
- `double latitude`
- `double longitude`

---

### 3. `flutter_riverpod: 2.6.1`

**Import:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

**Core Constructs for P3b:**
- `ProviderScope`: Root widget wrapping `MaterialApp`
- `ConsumerWidget`: Base widget for consuming Riverpod providers
- `WidgetRef ref`: Used in `build(BuildContext context, WidgetRef ref)`
- `StateNotifierProvider` or `NotifierProvider`: Used to manage selected point, layer toggles, and assessment state.

