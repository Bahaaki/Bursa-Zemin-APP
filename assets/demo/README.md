# Demo Data — assets/demo/

**⚠️ SYNTHETIC DATA — NOT REAL GEOLOGY ⚠️**

All files in this directory contain **fabricated** data created solely for
development and UI testing. They do **not** represent any real geological
conditions, fault locations, SPT measurements, or soil properties in Bursa
or anywhere else.

Every record carries `"demo": true`. The app displays a prominent
**"DEMO VERİ"** banner whenever these files are loaded.

## Files

| File | Description |
|---|---|
| `geology_demo.geojson` | 5 synthetic rectangular polygons (DEMO-1..DEMO-5) near Bursa centre (40.19, 29.06). Geometry is made-up rectangles chosen to cover the default map view. |
| `faults_demo.geojson` | 2 synthetic straight fault lines (LineString + MultiLineString). Positions are arbitrary. |
| `classification_demo.csv` | Classification rows for DEMO-1..DEMO-5 with varied risk levels. Values chosen to exercise all code paths (Düşük/Orta/Yüksek, all zemin_turu types). |
| `spt_samples_demo.json` | 5 synthetic SPT samples. N-values are arbitrary integers. No location, no borehole name. |

## Usage

The app loads these files when no real files are present in `assets/data/`.
Replace with real MTA-sourced data before any public or professional use.

## Licence

These files contain no intellectual property. They may be freely discarded
once real data is available.
