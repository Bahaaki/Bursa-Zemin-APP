# Bursa Zemin

**Preliminary geotechnical assessment for Bursa, Turkey — Android-first Flutter app.**

> **Disclaimer:** *Ön değerlendirmedir, zemin etüdünün yerine geçmez.*
> This app is an informational tool only. It does **not** replace a professional geotechnical investigation (zemin etüdü).

---

## What the App Does

Tap any point on the interactive map of Bursa to instantly receive a preliminary ground assessment:

- **Soil type & swelling potential** — from MTA lithological classification
- **Nearest active fault** — name and distance in km, risk-tiered (Düşük / Orta / Yüksek)
- **Overall risk level** — conservative maximum of soil risk, swelling potential, and fault proximity
- **Actionable recommendation** — "Uygun", "Dikkatli", or "Sondaj Gerekli"
- **Live earthquake layer** — recent quakes from AFAD (last 30 days, ≥ M2.0), magnitude-sized markers
- **SPT bearing capacity calculator** — Terzaghi general shear formula (strip, square, circular footings)
- **One-page PDF report** — share or save via the native share sheet

---

## Features

| Feature | File / Function |
|---|---|
| Interactive map (OSM + geology polygons + faults) | [`lib/features/map/map_screen.dart`](lib/features/map/map_screen.dart) |
| Geology polygon rendering (no GeoJsonLayer — parsed manually) | [`lib/features/geology/domain/geojson_parser.dart`](lib/features/geology/domain/geojson_parser.dart) |
| Point-in-polygon (ray-casting, hole support, MultiPolygon) | [`lib/features/geology/domain/point_in_polygon.dart`](lib/features/geology/domain/point_in_polygon.dart) |
| Nearest fault distance (equirectangular projection) | [`lib/features/geology/domain/fault_distance.dart`](lib/features/geology/domain/fault_distance.dart) |
| Spatial index (GeoIndex bbox pre-check) | [`lib/features/geology/domain/geo_index.dart`](lib/features/geology/domain/geo_index.dart) |
| Ground assessment logic & risk aggregation | [`lib/features/geology/domain/assessment.dart`](lib/features/geology/domain/assessment.dart) |
| Risk classification & fault thresholds | [`lib/features/geology/domain/risk_rules.dart`](lib/features/geology/domain/risk_rules.dart) |
| Ground assessment bottom sheet (Turkish labels, disclaimer) | [`lib/features/map/widgets/ground_assessment_sheet.dart`](lib/features/map/widgets/ground_assessment_sheet.dart) |
| Layer toggle sheet (Jeoloji / Fay / Deprem) | [`lib/features/map/widgets/layer_toggle_sheet.dart`](lib/features/map/widgets/layer_toggle_sheet.dart) |
| AFAD earthquake client (10-min cache, typed errors) | [`lib/features/quakes/data/afad_client.dart`](lib/features/quakes/data/afad_client.dart) |
| Quake detail card | [`lib/features/quakes/widgets/quake_detail_card.dart`](lib/features/quakes/widgets/quake_detail_card.dart) |
| SPT bearing capacity calculator (pure Dart) | [`lib/features/calculator/domain/spt_calculator.dart`](lib/features/calculator/domain/spt_calculator.dart) |
| Calculator screen with live recalculation | [`lib/features/calculator/calculator_screen.dart`](lib/features/calculator/calculator_screen.dart) |
| PDF report builder (Noto Sans, map snapshot, Turkish glyphs) | [`lib/features/report/pdf_report.dart`](lib/features/report/pdf_report.dart) |
| Splash screen | [`lib/features/splash/splash_screen.dart`](lib/features/splash/splash_screen.dart) |
| App constants (disclaimer, developer name, bounding box) | [`lib/core/constants.dart`](lib/core/constants.dart) |
| Demo/fallback data loader | [`lib/features/map/providers/map_providers.dart`](lib/features/map/providers/map_providers.dart) |
| Data validator CLI | [`tool/validate_data.dart`](tool/validate_data.dart) |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Dart 3.5.0 / Flutter 3.24.0 |
| State management | `flutter_riverpod 2.6.1` |
| Map | `flutter_map 7.0.2` + OSM tiles |
| Coordinates | `latlong2 0.9.1` |
| Location | `geolocator 12.0.0` |
| HTTP | `http 1.6.0` |
| CSV parsing | `csv 6.0.0` |
| PDF generation | `pdf 3.11.3` |
| PDF share/print | `printing 5.14.3` |
| Fonts | Noto Sans (Regular, Bold, Italic) — SIL OFL |
| Build target | Android (minSdk 21, compileSdk 34) |
| Android build | AGP 8.3.0 / Gradle 8.5 / JDK 21 / Kotlin 1.9.10 |

---

## Data Sources

| Source | What | Status |
|---|---|---|
| **MTA** (Maden Tetkik ve Arama) | Geology polygons (`geology.geojson`) | ⚠️ **SYNTHETIC / DEMO DATA** — real MTA data collection (Gate G1) has not been completed. The app runs entirely on synthetic demo data under `assets/demo/`. A **"DEMO VERİ"** banner is displayed whenever demo data is shown. |
| **AFAD** | Live earthquake events — endpoint `https://deprem.afad.gov.tr/apiv2/event/filter`, last 30 days, ≥ M2.0, Bursa bounding box. No API key required. | ✅ Live |
| **OpenStreetMap** | Base map tiles via `tile.openstreetmap.org` | ✅ Live (see tile policy note below) |

> **OSM Tile Policy:** The app currently uses `tile.openstreetmap.org` directly. For production or scaled use (> personal/portfolio use), you **must** use a proper tile provider (e.g. a self-hosted tile server or a commercial provider) in accordance with the [OpenStreetMap Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

---

## Limitations (honest)

- **Geology data is synthetic.** The demo dataset (`assets/demo/`) contains 5 invented polygons and does not represent actual Bursa geology. Real MTA data must be obtained and placed in `assets/data/` to produce meaningful assessments.
- **Fault distance thresholds** (Yüksek ≤ 1 km, Orta ≤ 5 km) are the **developer's engineering judgment** (Ahmed), not a citation from TBDY 2018 or any official AFAD guideline. They are reasonable preliminary screening values.
- **SPT bearing capacity** uses Terzaghi (1943) general shear failure equations. Water table correction is not included. Results are indicative only.
- **Release signing:** The APK attached to GitHub Releases uses Flutter's default **debug signing key** (acceptable for portfolio side-loading; NOT eligible for Google Play Store submission without a proper keystore).
- The app does NOT predict earthquakes. Earthquake markers are historical records from AFAD, displayed for informational purposes only.

---

## Font & License Credit

**Noto Sans** (Regular, Bold, Italic) is bundled under `assets/fonts/` and is used under the [SIL Open Font License 1.1 (OFL)](https://scripts.sil.org/OFL). Copyright © Google LLC. See `assets/fonts/OFL.txt` for the full license text.

---

## Build & Run

### Prerequisites

- Flutter 3.24.0 (`flutter --version`)
- JDK 21 (Android Studio Hedgehog+ bundled JBR, or OpenJDK 21)
- Android SDK with compileSdk 34

### Run (debug)

```bash
git clone <repo-url>
cd bursa-zemin
flutter pub get
flutter run
```

### Build release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
# Note: uses debug signing (no keystore provided)
```

### Run tests

```bash
flutter test
dart format --output=none --set-exit-if-changed .
flutter analyze
```

### Validate data

```bash
dart run tool/validate_data.dart
```

---

## Download

Pre-built APK → **[GitHub Releases](../../releases/latest)**

> Replace the URL above with your actual repository URL after pushing.

---

## Demo

<!-- Add a screen recording GIF here. Suggested path: docs/demo.gif -->
<!-- Example: ![App Demo](docs/demo.gif) -->

*Demo GIF placeholder — add `docs/demo.gif` (screen recording) and uncomment the line above.*

---

## CI/CD

GitHub Actions workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

| Trigger | Action |
|---|---|
| Push to `main` / Pull Request | `dart format` check · `flutter analyze` · `flutter test` |
| Push tag `v*` | All of the above + `flutter build apk --release` + attach APK to GitHub Release |

JDK 21 is used in CI (required by AGP 8.3.0 / Gradle 8.5).

---

---

## Türkçe Bölüm / Turkish Section

### Bursa Zemin Nedir?

**Bursa Zemin**, Bursa ili için Android üzerinde çalışan, açık kaynaklı bir **ön zemin değerlendirme** uygulamasıdır. Haritada bir noktaya dokunarak:

- MTA litolojik sınıflandırmasına dayalı **zemin türü ve şişme potansiyeli**
- Aktif faya **mesafe ve risk seviyesi** (Düşük / Orta / Yüksek)
- AFAD'dan canlı **deprem bilgileri** (son 30 gün, ≥ M2.0)
- Terzaghi formüllerine dayalı **SPT taşıma gücü hesabı**
- Tek sayfalık, Türkçe karakter destekli **PDF rapor**

bilgilerine anında ulaşabilirsiniz.

> ⚠️ **Bu uygulama bir ön değerlendirme aracıdır; zemin etüdünün yerine geçmez.**

### Veri Kaynakları

| Kaynak | Açıklama |
|---|---|
| MTA | Jeoloji poligonları — **DEMO VERİ** (gerçek MTA verisi henüz entegre edilmedi) |
| AFAD | Canlı deprem verileri — API anahtarı gerektirmez |
| OpenStreetMap | Temel harita döşemeleri |

### Kurulum

```bash
git clone <repo-url>
cd bursa-zemin
flutter pub get
flutter run
```

### Derleme

```bash
flutter build apk --release
```

> Not: Yayınlanan APK, portföy amaçlı hata ayıklama anahtarıyla imzalanmıştır. Google Play Store'a yükleme için gerçek bir yayın anahtarı gereklidir.

---

*Developed by **Ahmed** · Data: MTA (synthetic/demo), AFAD (live), OpenStreetMap · Fonts: Noto Sans (SIL OFL) · License: MIT*
