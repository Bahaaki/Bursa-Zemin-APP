# SPEC — Bursa Zemin

## 1. Data files
- `assets/data/geology.geojson` (REAL, human-provided): FeatureCollection of Polygon/MultiPolygon, WGS84 (EPSG:4326), coordinates [lon, lat]. ONE property required: `birim` (MTA unit symbol, string).
- `assets/data/faults.geojson` (REAL, human-provided): LineString/MultiLineString. Optional property `ad` (fault name).
- `assets/config/classification.csv` (human-authored, UTF-8, header required):
  `birim,ad,zemin_turu,sisme_potansiyeli,zemin_riski`
  Allowed: `zemin_turu` ∈ {Kaya, Kil, Alüvyon, Kum, Diğer}; `sisme_potansiyeli` ∈ {Düşük, Orta, Yüksek}; `zemin_riski` ∈ {Düşük, Orta, Yüksek}. Strict, case-sensitive; unknown value = validation error.
- Loading order: try real files in `assets/data/`; if a file is absent fall back to `assets/demo/` equivalents. Register `assets/data/` as a directory asset (keep a `.gitkeep`).
- Risk/soil info is NOT baked into the GeoJSON. It is joined at runtime: `birim` → classification row. (So the geologist can edit the CSV without re-exporting.)

## 2. Domain rules
- `RiskLevel { dusuk, orta, yuksek }` ↔ "Düşük", "Orta", "Yüksek".
- Point lookup: bbox pre-check per polygon, then ray-casting. Polygons have outer ring + holes (a point inside a hole is OUTSIDE). MultiPolygon supported. Boundary points: inclusive (documented + tested). If several features contain the point, choose the one with the highest `zemin_riski` (conservative).
- Nearest fault: minimum distance from point to all segments, using a local equirectangular projection at the point's latitude; return `{name?, distanceKm}`.
- Fault level from `risk_rules.json`: `d <= yuksek_max` → Yüksek; `d <= orta_max` → Orta; else Düşük. If no fault data loaded → level unknown (not Düşük).
- Overall level = max(zemin_riski, sisme_potansiyeli, faultLevel). Unknown fault level is ignored but the sheet shows "Fay verisi yok".
- Recommendation: Düşük → "Uygun (ön değerlendirme)"; Orta → "Dikkatli"; Yüksek → "Sondaj Gerekli". Point outside all polygons → "Veri yok – zemin etüdü gerekli".
- Colors by `zemin_riski`: Düşük green, Orta yellow, Yüksek red (fill alpha ≈ 0.45, thin border).

## 3. Screens (3 + splash)
3.1 Splash: text logo "Bursa Zemin", ~1.5 s, then Map.
3.2 Map: initial center (40.19, 29.06), zoom 10. OSM `TileLayer` with `userAgentPackageName` = the app id. Layers: geology polygons, faults polylines (dark), earthquakes (optional toggle). Layer toggle sheet (Jeoloji / Fay / Deprem). FAB "Konumumu Göster". AppBar action → Calculator. Visible attribution "© OpenStreetMap contributors". "DEMO VERİ" ribbon if any displayed feature has `demo:true`. Tap → marker + bottom sheet.
3.3 Bottom sheet (Turkish labels): Koordinat · Jeolojik birim · Zemin türü · Şişme Potansiyeli · En yakın fay (ad + km) · Genel değerlendirme (renk + öneri) · Kaynak: "MTA, AFAD" · disclaimer (constant `kDisclaimer` = "Ön değerlendirmedir, zemin etüdünün yerine geçmez.") · buttons "Rapor Oluştur", "SPT Hesabı".
3.4 Calculator screen: see §4.

## 4. Calculator (Terzaghi general shear)
Inputs: soil kind (Kohezyonsuz/kum | Kohezyonlu/kil), N (int 1–100), footing shape (Şerit | Kare | Dairesel), B (m, >0), Df (m, ≥0), γ (kN/m³, default from constants), FS (default from constants), optional N correction factor (default 1.0).
Steps:
1. Granular: φ = 27.1 + 0.3·N − 0.00054·N² (degrees; Peck–Hanson–Thornburn as fitted by Wolff), c = 0.
   Cohesive: φ = 0, c = cu = k·N with k from constants.
2. q = γ·Df.
3. Nq = e^{2(3π/4 − φ/2)·tanφ} / (2·cos²(45° + φ/2)); Nc = (Nq − 1)·cotφ for φ>0, Nc = 5.7 and Nq = 1 for φ=0; Nγ = linear interpolation in the table in `geotech_constants.json` (Nγ = 0 at φ=0).
4. q_ult: Şerit = c·Nc + q·Nq + 0.5·γ·B·Nγ · Kare = 1.3·c·Nc + q·Nq + 0.4·γ·B·Nγ · Dairesel = 1.3·c·Nc + q·Nq + 0.3·γ·B·Nγ.
5. q_all = q_ult / FS. Units kPa.
Show intermediate values (φ or cu, Nc, Nq, Nγ, q_ult, q_all). Show warnings: water table not considered; correlation valid for the stated soil kind only; N>50 → "refüsü" warning. Disclaimer (R10). Optional "Örnek SPT verisi" dropdown reads `assets/config/spt_samples.json` (schema: `[{id, depth_m, n_value, soil: "kum"|"kil"}]`, no names, no coordinates); falls back to `assets/demo/spt_samples_demo.json`.
Tests: (a) φ=0 → Nc=5.7, Nq=1; (b) φ=30° → Nc≈37.2 (±0.2), Nq≈22.5 (±0.2); (c) three reference cases supplied by the human in `test/fixtures/bearing_reference.json` (do not invent them); (d) monotonic: q_ult increases with N; (e) input validation errors.

## 5. Earthquakes (AFAD)
Endpoint and parameters MUST be verified against https://deprem.afad.gov.tr/apidocs with a real request (R6). Query: last 30 days, bounding box around Bursa (config constant, adjustable), min magnitude configurable (default 2.0). Display only: markers sized by magnitude, tap shows time/magnitude/depth/place. Timeout 10 s, in-memory cache 10 min, Turkish error banner "Deprem verisi alınamadı". Never present as prediction.

## 6. PDF report (single A4 page)
Content: title, date, coordinates, map snapshot, geology/soil/fault/overall + recommendation, calculator results if any, disclaimer, sources (MTA, AFAD, OpenStreetMap), "Geliştirici: <DEVELOPER_NAME>" from `lib/core/constants.dart`.
Turkish glyphs (ç ğ ı ö ş ü İ) need an embedded TTF (e.g. Noto Sans, OFL) under `assets/fonts/`, loaded with the `pdf` package; the default PDF font breaks Turkish. Map snapshot via `RepaintBoundary` → PNG; if capture fails, omit the image and print "Harita görüntüsü alınamadı". Output through `printing` (share/save).

## 7. Android
- Add `INTERNET` permission to the MAIN `AndroidManifest.xml` (the Flutter template only has it in debug/profile, so release builds would have no tiles).
- Add `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`.
- Follow the resolved `geolocator` version's README for any extra setup (minSdk etc.).
- Runtime permission flow with Turkish messages for denied / permanently denied / service disabled.
- App label "Bursa Zemin"; placeholder launcher icon is fine.

## 8. Dependencies (whitelist)
`flutter_riverpod`, `flutter_map`, `latlong2`, `geolocator`, `http`, `csv`, `pdf`, `printing`; dev: `flutter_lints`. Anything else → ask.

## 9. Folder structure
```
lib/
  main.dart
  app/            app.dart, theme.dart
  core/           constants.dart
  features/
    splash/
    map/          map_screen.dart, providers, widgets/
    geology/domain/   models, geojson_parser, geo_index, point_in_polygon,
                      fault_distance, classification, risk_rules, assessment
    quakes/       domain/, data/afad_client.dart
    calculator/   domain/spt_calculator.dart, calculator_screen.dart
    report/       pdf_report.dart
assets/ data/ demo/ config/ fonts/
tool/validate_data.dart
test/ (mirrors lib/) + test/fixtures/
docs/ SPEC.md DECISIONS.md
```

## 10. Config drafts (create verbatim in P0; humans verify)
`assets/config/risk_rules.json`
```
{
  "verified": false,
  "fault_distance_km": { "yuksek_max": 1.0, "orta_max": 5.0 },
  "note": "DRAFT thresholds. Human must confirm."
}
```
`assets/config/geotech_constants.json`
```
{
  "verified": false,
  "note": "DRAFT. Human must verify every value against a textbook before setting verified=true.",
  "default_gamma_kn_m3": 18.0,
  "default_fs": 3.0,
  "cu_factor_kpa_per_n": 6.0,
  "n_gamma_terzaghi": [
    {"phi": 0, "ng": 0.0}, {"phi": 5, "ng": 0.5}, {"phi": 10, "ng": 1.2},
    {"phi": 15, "ng": 2.5}, {"phi": 20, "ng": 5.0}, {"phi": 25, "ng": 9.7},
    {"phi": 30, "ng": 19.7}, {"phi": 35, "ng": 42.4}, {"phi": 40, "ng": 100.4},
    {"phi": 45, "ng": 297.5}, {"phi": 50, "ng": 1153.2}
  ]
}
```

## 11. Non-goals
No accounts, no backend, no iOS, no offline tiles, no groundwater/liquefaction analysis, no legal/design claims.
