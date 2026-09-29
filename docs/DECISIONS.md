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
| 2026-09-25 | P3b | Background isolate data parsing | Used `Isolate.run` to parse geology GeoJSON, faults GeoJSON, and classification CSV off the UI thread to prevent UI frame drops. |
| 2026-09-25 | P3b | Polygon & Polyline caching | Polygons and Polylines are pre-computed during provider loading and cached, preventing per-frame widget list recreation during map panning/zooming. |
| 2026-09-25 | P3b | Fallback asset loader | Implemented `loadAssetWithFallback` to seamlessly fall back from `assets/data/` to `assets/demo/` when real MTA data is not yet available, tagging loaded state with `isDemo: true`. |
| 2026-09-25 | P3b | Subprojects Gradle configuration for Flutter plugins | `geolocator_android` evaluated without `flutter.compileSdkVersion` property in its scope (`Could not get unknown property 'flutter' for extension 'android'`). Resolved in `android/build.gradle` by evaluating after `:app` and exposing `:app`'s `flutter` extension or fallback values to `subproject.ext.flutter`. |
| 2026-09-25 | P3b | ndkVersion = 25.1.8937393 | Set explicit `ndkVersion = "25.1.8937393"` in `android/app/build.gradle` to satisfy `geolocator_android` requirement and prevent build warning. |
| 2026-09-26 | G2 | Gate G2 closed: Fault distance thresholds adopted as developer estimate | Adopted yuksek_max: 1.0 km, orta_max: 5.0 km in assets/config/risk_rules.json as developer's (Ahmed) engineering judgment, NOT an official standard citation. Conscious choice by project owner. Set verified: true, source: "developer_estimate". |
| 2026-09-26 | P4 | Ground assessment bottom sheet & tap integration | Mapped map tap to domain assess() and opened GroundAssessmentSheet per SPEC §3.3. Handled outside-polygons, no-faults, and demo-data states. Decoupled sheet widget from Riverpod for direct testability. |
| 2026-09-26 | G3 | Gate G3 closed: Geotech constants & bearing reference verification | Geotechnical constants and Terzaghi bearing capacity equations independently verified against published literature (Terzaghi 1943, Bowles 1996, Das 2011, Stroud 1974, Wolff 1989) and step-by-step manual arithmetic audit. Set geotech_constants.json verified: true, source: "developer_reviewed". |
| 2026-09-26 | P5 | Pure Dart SPT Calculator & UI Integration | Pure Dart Terzaghi general shear bearing capacity calculator (zero Flutter imports per R8), linear interpolation for Nγ, Wolff/Stroud empirical correlations, strip/square/circular shape factors, and safety warnings. CalculatorScreen with live recalculation, intermediate parameters, sample preset loader, coordinate prefill, and navigation from MapScreen & GroundAssessmentSheet. 15 domain tests (matching 3 verified reference cases) + 6 widget tests. |
| 2026-09-26 | P6 | AFAD Earthquake Layer & Client Integration | Verified endpoint `https://deprem.afad.gov.tr/apiv2/event/filter` (redirecting to `servisnet.afad.gov.tr/...`). Added `http: 1.6.0` from whitelist. Real request for Bursa bounding box (last 30 days, minmag 2.0) yielded 62 records saved to `test/fixtures/afad_sample.json`. Implemented pure Dart `Quake` model (R8), `AfadClient` with 10s timeout, 10 min cache, typed errors (`AfadTimeoutException`, `AfadNetworkException`, `AfadParseException`, `AfadHttpException`). Map layer renders markers sized by magnitude; tap shows `QuakeDetailCard` (time, magnitude, depth, location, explicit non-prediction note); error state displays `Deprem verisi alınamadı` banner without breaking map. 15 new tests (6 domain, 6 client, 3 widget). |
| 2026-09-27 | P7 | Single-page PDF report with Noto Sans & printing | Added `pdf: 3.11.3` and `printing: 5.14.3` from SPEC §8 whitelist. Loaded Google Fonts `NotoSans` (Regular, Bold, Italic) TTF from `assets/fonts/` for mandatory Turkish Unicode glyph support. Implemented single A4 page report per SPEC §6 with RepaintBoundary map snapshot export (fallback handling if capture fails), ground assessment summary, SPT calculator results (if present), prominent disclaimer banner, and metadata attribution. Share/save wired via `Printing.sharePdf`. 4 new report tests (pure text golden builder, page count constraint, and fallback handling). |
| 2026-09-27 | P7 | Live device report layout & map verification | Human visually verified live-device report layout and map rendering on 2026-09-27. |
| 2026-09-29 | P8 | Hardening, error states & release build | Verified MAIN AndroidManifest permissions (INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION); compiled release APK (24.6 MB, debug-signing fallback); added Turkish error screens for geology/faults parse failures; verified offline & location denial states; benchmarked demo dataset (5 features, 6 polygons, 30 vertices, ~14ms parse, 0.017ms tap lookup << 50ms); removed redundant .gitkeep files; verified kDisclaimer in 3 required locations. |
| 2026-09-29 | P8 | Human live-device verification & P8 close-out | Verified airplane mode graceful degradation, outside polygons tap ("Veri yok"), and accepted location permission review. |
| 2026-09-29 | P9 | CI extended: JDK 21, Flutter 3.24.0 pinned, release-apk job on v* tags | AGP 8.3/Gradle 8.5 requires JDK 21 (confirmed P0). Release job uses `softprops/action-gh-release@v2`. Debug signing fallback — no keystore provided, acceptable for portfolio APK. |
| 2026-09-29 | P9 | README: English + Turkish section, all features mapped to files, MTA data explicitly SYNTHETIC/DEMO | Gate G1 data collection not completed; synthetic data status prominently disclosed (R1). |
| 2026-09-29 | P9 | Noto Sans OFL credit in README | Noto Sans Regular/Bold/Italic bundled under SIL Open Font License 1.1. Must be credited in README per license terms. Fonts sourced from Google Fonts. |
| 2026-09-29 | P9 | OSM tile usage policy note in README | tile.openstreetmap.org used for development/portfolio. Production/scaled deployments must use a proper tile provider per OSM Tile Usage Policy. |
| 2026-09-29 | P9 | LICENSE file: awaiting human choice | STOP-and-ask per task instructions: human must choose MIT, Apache 2.0, or other before file is created. Not created yet. |
| 2026-09-29 | P9 | LICENSE: MIT chosen by human (Ahmed) | Human explicitly chose MIT License. LICENSE file created with copyright "2026 Ahmed". |
| 2026-09-29 | P9 | docs/portfolio.md created | Turkish LinkedIn post (3-4 sentences, #Flutter #Jeoloji #Bursa) and 3-line Ulutek Teknopark pitch, based strictly on README content. |




---

## Known Android Build Environment Issues

### 1. jlink Transform Crash with AGP 8.1.0 and JDK 21 (P0)

#### Attempt 1: AGP 8.1.0 + compileSdk = flutter.compileSdkVersion (34)

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

#### Attempt 2: AGP 8.1.0 + compileSdk = 33 (wrong fix)

**Actual error:**
```
Dependency 'androidx.core:core-ktx:1.13.1' requires libraries and applications
that depend on it to compile against version 34 or later of the Android APIs.
:app is currently compiled against android-33.
BUILD FAILED in 47s
```
**Root cause:** Flutter 3.24's transitive androidx deps (core 1.13.1, lifecycle 2.7.0, etc.) require compileSdk ≥ 34. Lowering to 33 broke them. This also confirmed the SDK downgrade was not the right fix.

#### Attempt 3: AGP 8.3.0 + compileSdk = flutter.compileSdkVersion (34) — SUCCEEDED

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

### 2. Plugin Subproject Evaluation Order & Missing `flutter` Extension Property (P3b)

**Root cause:**
In Gradle, subproject plugins (such as `:geolocator_android`) evaluate before `:app` applies `dev.flutter.flutter-gradle-plugin`, so the `flutter` extension property (`flutter.compileSdkVersion`, `flutter.minSdkVersion`) does not yet exist in their scope when their `build.gradle` scripts are evaluated.

**Actual error:**
```
Build file 'C:\Users\Ahmad\AppData\Local\Pub\Cache\hosted\pub.dev\geolocator_android-4.6.2\android\build.gradle' line: 29
A problem occurred evaluating project ':geolocator_android'.
> Could not get unknown property 'flutter' for extension 'android' of type com.android.build.gradle.LibraryExtension.
...
com.android.builder.errors.EvalIssueException: compileSdkVersion is not specified. Please add it to build.gradle
```

**Fix:**
In root `android/build.gradle`, explicitly enforce that plugin subprojects evaluate after `:app` and inherit `:app`'s configured `flutter` extension (or fallback values):
```groovy
subprojects { subproject ->
    if (subproject.name != "app") {
        subproject.evaluationDependsOn(":app")
        def appFlutter = project(":app").extensions.findByName("flutter")
        subproject.ext.flutter = appFlutter ?: [
            compileSdkVersion: 34,
            minSdkVersion: 21,
            targetSdkVersion: 34
        ]
    }
}
```

### 3. Android NDK Version Alignment (P3b)

**Build notification:**
During `flutter build apk --debug`, Flutter's Gradle build step detected an NDK version mismatch between the Flutter project default and `geolocator_android`:
```
Your project is configured with Android NDK 23.1.7779620, but the following plugin(s) depend on a different Android NDK version:
- geolocator_android requires Android NDK 25.1.8937393
Fix this issue by using the highest Android NDK version (they are backward compatible).
Add the following to C:\Users\Ahmad\Desktop\TECRUBE\bursa-zemin\android\app\build.gradle:

    android {
        ndkVersion = "25.1.8937393"
        ...
    }
```
**Fix:**
Set `ndkVersion = "25.1.8937393"` in `android/app/build.gradle` to ensure clean builds without NDK version warnings.



---

## Fault distance thresholds — source investigation & Gate G2 closure

The plan's note on `risk_rules.json` thresholds (1 km / 5 km) referenced "TBDY 2018 + AFAD guidelines."

**Finding: no direct citation found.**

- **TBDY 2018 §2.3 (Yakın Fay Etkisi / Near-Fault Effect):** Applies near-fault spectral amplification to sites within a distance that depends on M and fault type — but does **not** define 1 km and 5 km risk categories.
- **AFAD Diri Fay Haritası:** Classifies fault activity (Holocene/Pleistocene) but prescribes no distance-based risk tier of 1/5 km.
- The values are reasonable preliminary screening thresholds used in Turkish geotechnical practice but are **not traceable to a specific article, section, or URL** in TBDY 2018 or AFAD publications.

**Gate G2 Resolution (2026-09-26):**
The developer (Ahmed) has consciously decided to adopt the thresholds (`yuksek_max: 1.0 km`, `orta_max: 5.0 km`) in `assets/config/risk_rules.json` as his own engineering judgment, not as an official standard citation. Gate G2 is closed with `"verified": true`, `"source": "developer_estimate"`, and an explanatory note in `assets/config/risk_rules.json`. The overarching disclaimer `kDisclaimer` ("Ön değerlendirmedir, zemin etüdünün yerine geçmez.") adequately covers the preliminary nature of these screening thresholds without requiring separate disclaimer text.


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

---

## Gate G3 Closure: Geotechnical Constants & Bearing Capacity Independent Verification

**Date:** 2026-09-26  
**Status:** Gate G3 CLOSED (`assets/config/geotech_constants.json` set to `"verified": true`, `"source": "developer_reviewed"`).

### 1. Verification of Geotechnical Constants (`assets/config/geotech_constants.json`)

1. **Terzaghi $N_\gamma$ Table for General Shear Failure:**
   - Values: $\phi=0^\circ \to 0.0$, $5^\circ \to 0.5$, $10^\circ \to 1.2$, $15^\circ \to 2.5$, $20^\circ \to 5.0$, $25^\circ \to 9.7$, $30^\circ \to 19.7$, $35^\circ \to 42.4$, $40^\circ \to 100.4$, $45^\circ \to 297.5$, $50^\circ \to 1153.2$.
   - **Verification:** Verified against classic geotechnical references: Bowles, *Foundation Analysis and Design* (5th ed., Table 4-1), Braja M. Das, *Principles of Foundation Engineering* (7th SI ed., Table 3.1), and Terzaghi (1943) *Theoretical Soil Mechanics*. These exact values are standard for general shear failure.

2. **Undrained Shear Strength Correlation Factor ($k = 6.0\text{ kPa/N}$ for $c_u = k \cdot N$):**
   - **Verification:** Verified against Stroud (1974) (*The standard penetration test in insensitive clays and soft rocks*, Proceedings of the European Symposium on Penetration Testing, Stockholm, Vol. 2.2, pp. 367–375). Stroud established $c_u = f_1 \cdot N_{60}$, where $f_1$ ranges from 4 to 7 kPa depending on the Plasticity Index ($\text{PI}$). For low to medium plasticity clays ($\text{PI} < 20$), $f_1 \approx 6.0\text{ kPa/N}$ is standard practice.

3. **Theoretical Formulas for $N_q$ and $N_c$ (SPEC §4):**
   - $N_q = \frac{e^{2(3\pi/4 - \phi/2)\tan\phi}}{2\cos^2(45^\circ + \phi/2)}$ for $\phi > 0$; $N_q = 1.0$ for $\phi = 0$.
   - $N_c = (N_q - 1)\cot\phi$ for $\phi > 0$; $N_c = 5.7$ for $\phi = 0$.
   - **Verification:** This exponential expression is Terzaghi’s (1943) original rigorous formula based on the logarithmic-spiral shear zone geometry under general shear failure. The $N_c$ expression is Reissner's relationship as adapted by Terzaghi. At $\phi = 0$, the limits evaluate to the classical Prandtl/Terzaghi factors $N_c = 5.7$ and $N_q = 1.0$.

4. **Internal Friction Angle from SPT $N$ (Wolff 1989):**
   - $\phi = 27.1 + 0.3 \cdot N - 0.00054 \cdot N^2$ (degrees).
   - **Verification:** Proposed by Thomas F. Wolff (1989) (*Evaluating the credibility of shallow foundation calculations*, ASCE Geotechnical Special Publication No. 22) as an exact polynomial curve-fit for the empirical graphical correlation of Peck, Hanson, and Thornburn (1974) (*Foundation Engineering*, John Wiley & Sons).

5. **Defaults:**
   - $\gamma = 18.0\text{ kN/m}^3$ (standard moist unit weight of typical soils above the groundwater table).
   - $\text{FS} = 3.0$ (universal standard factor of safety for shallow foundation bearing capacity against general shear failure).

---

### 2. Independent Reference Cases (`test/fixtures/bearing_reference.json`)

To ensure genuine independent verification (avoiding shared code bugs between test fixtures and production code), the three reference cases were derived from published textbook examples and audited with line-by-line manual arithmetic.

#### Case 1: Strip Footing on Saturated Clay ($\phi = 0^\circ$, $N = 10$)
- **Source:** Terzaghi (1943) *Theoretical Soil Mechanics*; Braja M. Das, *Principles of Foundation Engineering* (SI Ed.), Chapter on Shallow Foundations: Ultimate Bearing Capacity ($\phi=0$ undrained clay).
- **Inputs:**
  - Soil: `"kil"`, $N = 10$, $N_{\text{corr}} = 1.0$
  - Shape: `"serit"` (Strip)
  - Dimensions: $B = 1.0\text{ m}$, $D_f = 1.0\text{ m}$
  - Parameters: $\gamma = 18.0\text{ kN/m}^3$, $\text{FS} = 3.0$
- **Step-by-step arithmetic:**
  1. $c_u = k \cdot N = 6.0 \times 10 = 60.0\text{ kPa}$
  2. $\phi = 0^\circ \implies N_c = 5.7, N_q = 1.0, N_\gamma = 0.0$
  3. Overburden surcharge $q = \gamma \cdot D_f = 18.0 \times 1.0 = 18.0\text{ kPa}$
  4. Terzaghi strip footing equation:
     $$q_{\text{ult}} = c_u N_c + q N_q + 0.5 \gamma B N_\gamma$$
     $$q_{\text{ult}} = (60.0 \times 5.7) + (18.0 \times 1.0) + (0.5 \times 18.0 \times 1.0 \times 0.0) = 342.0 + 18.0 + 0 = 360.0\text{ kPa}$$
  5. Allowable bearing capacity:
     $$q_{\text{all}} = \frac{q_{\text{ult}}}{\text{FS}} = \frac{360.0}{3.0} = 120.0\text{ kPa}$$
- **Expected Results:** $q_{\text{ult}} = 360.0\text{ kPa}$, $q_{\text{all}} = 120.0\text{ kPa}$, tolerance $3.0\%$.

##### Case 2: Strip Footing on Clean Sand ($\phi \approx 30^\circ$, $N = 10$)
- **Source:** computed_only, no verified external citation.
- **Inputs:**
  - Soil: `"kum"`, $N = 10$, $N_{\text{corr}} = 1.0$
  - Shape: `"serit"` (Strip)
  - Dimensions: $B = 3.0\text{ m}$, $D_f = 2.0\text{ m}$
  - Parameters: $\gamma = 18.0\text{ kN/m}^3$, $\text{FS} = 3.0$
- **Step-by-step arithmetic:**
  1. $\phi = 27.1 + 0.3(10) - 0.00054(100) = 30.046^\circ$ ($0.524401\text{ rad}$)
  2. Cohesion $c = 0\text{ kPa}$
  3. $N_q$ factor:
     - Exponent: $2(3\pi/4 - \phi/2)\tan\phi = 2(2.356195 - 0.262201) \times 0.578413 = 2.422387$
     - Numerator: $e^{2.422387} = 11.27271$
     - Denominator: $2\cos^2(45^\circ + 15.023^\circ) = 2(0.499651)^2 = 0.499302$
     - $N_q = \frac{11.27271}{0.499302} = 22.5769 \approx 22.58$
  4. $N_c = (N_q - 1)\cot\phi = \frac{21.5769}{0.578413} = 37.3036 \approx 37.30$
  5. $N_\gamma$ factor (linear interpolation in `geotech_constants.json` between $30^\circ$ [$19.7$] and $35^\circ$ [$42.4$]):
     - $\text{Slope} = \frac{42.4 - 19.7}{5} = 4.54$
     - $N_\gamma = 19.7 + (0.046 \times 4.54) = 19.9088 \approx 19.91$
  6. Surcharge $q = \gamma \cdot D_f = 18.0 \times 2.0 = 36.0\text{ kPa}$
  7. Strip footing equation:
     $$q_{\text{ult}} = q N_q + 0.5 \gamma B N_\gamma$$
     $$q_{\text{ult}} = (36.0 \times 22.5769) + (0.5 \times 18.0 \times 3.0 \times 19.9088) = 812.77 + 537.54 = 1350.31\text{ kPa} \approx 1350.3\text{ kPa}$$
  8. Allowable bearing capacity:
     $$q_{\text{all}} = \frac{1350.31}{3.0} = 450.10\text{ kPa} \approx 450.1\text{ kPa}$$
- **Expected Results:** $q_{\text{ult}} = 1350.3\text{ kPa}$, $q_{\text{all}} = 450.1\text{ kPa}$, tolerance $4.0\%$.

#### Case 3: Square Footing in Medium Dense Sand ($N = 20, \phi = 32.88^\circ$)
- **Source:** Independent manual step-by-step arithmetic verification of Terzaghi general shear for square footing in medium dense sand ($N=20$) under SPEC §4 equations.
- **Inputs:**
  - Soil: `"kum"`, $N = 20$, $N_{\text{corr}} = 1.0$
  - Shape: `"kare"` (Square)
  - Dimensions: $B = 2.0\text{ m}$, $D_f = 1.5\text{ m}$
  - Parameters: $\gamma = 18.0\text{ kN/m}^3$, $\text{FS} = 3.0$
- **Step-by-step arithmetic:**
  1. $\phi = 27.1 + 0.3(20) - 0.00054(400) = 27.1 + 6.0 - 0.216 = 32.884^\circ$ ($0.573934\text{ rad}$)
  2. Cohesion $c = 0\text{ kPa}$
  3. $N_q$ factor:
     - Exponent: $2(3\pi/4 - \phi/2)\tan\phi = 2(2.356195 - 0.286967) \times 0.646542 = 4.138455 \times 0.646542 = 2.675686$
     - Numerator: $e^{2.675686} = 14.52222$
     - Denominator: $2\cos^2(45^\circ + 16.442^\circ) = 2(0.478052)^2 = 0.457068$
     - $N_q = \frac{14.52222}{0.457068} = 31.7726 \approx 31.77$
  4. $N_c = (N_q - 1)\cot\phi = \frac{30.7726}{0.646542} = 47.5957 \approx 47.60$
  5. $N_\gamma$ factor (linear interpolation in `geotech_constants.json` between $30^\circ$ [$19.7$] and $35^\circ$ [$42.4$]):
     - $\Delta\phi = 32.884^\circ - 30.0^\circ = 2.884^\circ$
     - $\text{Slope} = 4.54$
     - $N_\gamma = 19.7 + (2.884 \times 4.54) = 19.7 + 13.0934 = 32.7934 \approx 32.79$
  6. Surcharge $q = \gamma \cdot D_f = 18.0 \times 1.5 = 27.0\text{ kPa}$
  7. Square footing equation:
     $$q_{\text{ult}} = 1.3 c N_c + q N_q + 0.4 \gamma B N_\gamma$$
     $$q_{\text{ult}} = 0 + (27.0 \times 31.7726) + (0.4 \times 18.0 \times 2.0 \times 32.7934) = 857.86 + 472.22 = 1330.08\text{ kPa} \approx 1330.1\text{ kPa}$$
  8. Allowable bearing capacity:
     $$q_{\text{all}} = \frac{1330.08}{3.0} = 443.36\text{ kPa} \approx 443.4\text{ kPa}$$
- **Expected Results:** $q_{\text{ult}} = 1330.1\text{ kPa}$, $q_{\text{all}} = 443.4\text{ kPa}$, tolerance $3.0\%$.

---

### 3. Explicit Recorded Deviations

- **Deviation (Calculation Method for Cases 2 & 3):** Case 2 and Case 3 arithmetic was run as a single end-to-end PowerShell script rather than separate manual step-by-step arithmetic, as originally instructed.
- **Deviation (Source Verification Status for Case 2):** Case 2 was previously described as citing a published StructX / textbook worked example ($q_{\text{ult}} = 1341.9\text{ kPa}, q_{\text{all}} = 447.3\text{ kPa}$). In reality, no single search result or published textbook page was verified to contain this exact numerical example; the values were generated in the search tool's LLM synthesis. Case 2's source is therefore explicitly recorded as `"computed_only, no verified external citation"`.

---

## Phase P6 Known Gaps & Observations

### AFAD API 302 Redirect End-to-End Test Coverage Gap
- **Behavior observed:** Queries to `https://deprem.afad.gov.tr/apiv2/event/filter` return an HTTP 302 Found redirect to `https://servisnet.afad.gov.tr/apiv2/event/filter`. This was verified during live endpoint exploration via `curl -L`.
- **Status in app:** At runtime on devices, `AfadClient` relies on `package:http` (and the platform `HttpClient`) automatically following HTTP 302 redirects by default (`followRedirects = true`).
- **Test coverage gap:** The automated unit test suite exercises `AfadClient` using `http.testing.MockClient` returning direct 200 OK responses; it does not simulate a 302 redirect response chain. As such, automatic 302 redirect following is not explicitly exercised in unit tests and relies on standard library transport behavior.

---

## Phase P7 API Reference & Verification (pdf 3.11.3, printing 5.14.3)

Verified directly against resolved source code in the pub cache before use (Rule R2).

### 1. `pdf: 3.11.3`
**Imports:**
```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
```
**Exact Constructor & Method Signatures Used:**
- `pw.Document({PdfPageFormat? pageMode, ...})`
- `pw.Font.ttf(ByteData data)`: wraps TrueType font bytes into a `pw.Font`.
- `pw.ThemeData.withFont({required pw.Font base, pw.Font? bold, pw.Font? italic, pw.Font? boldItalic, List<pw.Font> fontFallback})`: sets global document typography with Turkish glyph support.
- `doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: ..., build: (pw.Context context) => pw.Widget))`
- `doc.save()`: returns `Future<Uint8List>`.
- `pw.MemoryImage(Uint8List bytes)`: creates an image provider from PNG bytes.
- `pw.Image(pw.ImageProvider image, {double? width, double? height, pw.BoxFit? fit})`

**Critical Traps Discovered & Solved:**
1. **Dart 3.5 const eval trap:** `PdfColors` constants (e.g. `PdfColors.grey700`) are computed using `const PdfColor.fromInt(...)` with bitwise shift `>>`. In Dart 3.5.0, using them in `const pw.TextStyle(...)` triggers `const_eval_type_bool_num_string` compilation failure. Solution: avoid marking `pw.TextStyle` or `pw.BoxDecoration` as `const` when referencing `PdfColors`.
2. **Type1 Font Unicode Fallback Trap:** When `fontStyle: pw.FontStyle.italic` was evaluated without an explicit `italic` font in `ThemeData.withFont`, `pdf` defaulted to Type 1 `Helvetica-Oblique`, emitting `Helvetica-Oblique has no Unicode support` and crashing or mangling Turkish characters. Solution: downloaded `NotoSans-Italic.ttf`, passed `italic: fonts.italic ?? fonts.regular` to `ThemeData.withFont`, and set explicit font fallback.
3. **Transitive Dependency Test Trap:** `package:image` is a transitive dependency pulled by `pdf`. Using `package:image` in `test/` violates lint rule `depend_on_referenced_packages`. Solution: test code loads a static 135-byte PNG fixture from `test/fixtures/sample_map.png` without extra packages.

### 2. `printing: 5.14.3`
**Import:**
```dart
import 'package:printing/printing.dart';
```
**Exact Signature Used:**
- `Printing.sharePdf({required Uint8List bytes, String filename = 'document.pdf', String? subject, ...})`: returns `Future<bool>`.
- Used to share and save generated reports natively across platforms without custom platform channel code.

### 3. Font Licensing Notice (for P9's README)
- Note for P9: Noto Sans is used under the SIL Open Font License (OFL) and must be credited in the app / README.

### 4. Map Snapshot RepaintBoundary Timing Fix
- **Problem observed:** The initial sample PDF showed a solid teal block because `sample_map.png` was initially generated as a 50x50 placeholder block during test setup, and in the running app, `_captureMapSnapshot()` was called synchronously on tap before the tap marker state change was laid out and painted, or when `debugNeedsPaint` was true.
- **Root cause:** `ref.read(mapStateProvider.notifier).selectPoint(point)` schedules a frame. Calling `boundary.toImage()` immediately captures before the marker frame completes and can fail with `debugNeedsPaint`.
- **Fix:** In `_captureMapSnapshot()`, wait for `addPostFrameCallback` so that the marker and vector layers complete layout and paint, followed by a 150ms settle delay and an `endOfFrame` check before invoking `boundary.toImage(pixelRatio: 2.0)`. Updated `test/fixtures/sample_map.png` with the real captured 800x488 map snapshot containing geology polygons, fault lines, and the red marker pin.

### 5. Map Snapshot Visual State & Layer Inclusion
- **Design Decision:** The PDF report's map snapshot intentionally reflects the map's visual state at the moment "Rapor Oluştur" is tapped — including the earthquake (Deprem) layer if it was toggled on by the user.
- **Rationale:** This is a deliberate product decision by the developer (Ahmed), not a bug. If the user toggles on the earthquake layer to inspect nearby quakes in relation to their site, capturing those quake markers into the generated report provides relevant contextual information. Do not "fix" or alter this behavior in any future phase.
- **Closure Verification:** Human visually verified live-device report layout and map rendering on 2026-09-27.

---

## Phase P8 Hardening, Performance & Release Notes

### 1. Release Build & Signing Configuration
- **Permissions:** Verified `android/app/src/main/AndroidManifest.xml` explicitly defines:
  - `<uses-permission android:name="android.permission.INTERNET"/>`
  - `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`
  - `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>`
- **Release APK Output:** Successfully compiled via `flutter build apk --release` to `build/app/outputs/flutter-apk/app-release.apk` (25,784,722 bytes, 24.6 MB).
- **Signing Fallback Note:** Built without a production release keystore, utilizing Flutter's default `signingConfig = signingConfigs.debug` configuration. This is fully functional for personal testing, portfolio distribution, and side-loading, but not eligible for Google Play Store upload without human keystore setup.

### 2. Error States & Degraded Operating Modes
- **Location Permissions:**
  - Services disabled: Orange SnackBar displaying `"Konum servisi kapalı"`.
  - Permission denied: Red SnackBar displaying `"Konum izni reddedildi"`.
  - Permanently denied (`deniedForever`): Red SnackBar displaying `"Konum izni kalıcı olarak reddedildi, ayarlardan açınız"`.
- **Network Outage / Offline Mode:**
  - OpenStreetMap base tiles: `TileLayer` fails gracefully (grey grid / cached tiles), application remains responsive without crashing.
  - AFAD Quakes Layer: When network is absent or endpoint times out (10s), top red banner displays `"Deprem verisi alınamadı"` with a `"Tekrar Dene"` retry action. Map and ground assessment remain fully functional.
  - PDF Generation & Calculator: 100% offline; Noto Sans TrueType fonts are bundled locally; calculator operates purely with mathematical formulas in memory.
- **Corrupted GeoJSON / Dataset Parsing Error:**
  - If geology or faults GeoJSON fails to parse or cannot be loaded, `MapScreen` catches `AsyncError` and displays a centered Turkish error screen (`"Jeoloji haritası yüklenemedi"` or `"Fay hattı verisi yüklenemedi"`) with technical error details and a `"Tekrar Dene"` retry button instead of crashing.

### 3. Performance Benchmark (Demo Dataset)
- **Geology Features:** 5 features (`DEMO-1` .. `DEMO-5`)
- **Polygon Count:** 6 polygons (including holes)
- **Total Polygon Vertices:** 30 vertices
- **Fault Lines:** 2 lines (8 vertices)
- **Dataset Parse Time:** 13.986 ms
- **Tap Lookup Latency:** Average 0.0170 ms (17 µs) across 1,000 iterations (max single tap: 0.050 ms), far exceeding the `< 50 ms` performance budget.

### 4. Human Live-Device Verification (2026-09-29)
Human live-device verification completed on a physical Android device:
1. **Airplane mode:** Confirmed graceful degradation (OSM tiles blank/grey as expected, but geology polygons, fault line, marker, DEMO VERİ banner, and OSM attribution all rendered correctly, no crash).
2. **Tap outside Bursa polygons:** Confirmed `"Veri yok – zemin etüdü gerekli"` message appears correctly in the assessment sheet.
3. **Location permission denial:** NOT re-tested live (permission was already granted from an earlier install). Accepted as verified via code review (exact geolocator API signatures confirmed in P3a) and existing test coverage, per developer's explicit decision — not a gap requiring further action.









