# AGENTS.md — Bursa Zemin (GeoFlutter)

## Project
Android-first Flutter app. The user taps a point on a map of Bursa and gets a PRELIMINARY ground assessment: soil type, swelling potential, nearest active fault, recent earthquakes, and a recommendation. It also has an SPT-based bearing-capacity calculator and a one-page PDF report.
This is an informational/portfolio app. It is NOT a substitute for a geotechnical investigation.

## Hard rules (violating any of these = task failed)

R1. NO INVENTED DATA. Never invent geological units, soil classes, risk ratings, fault coordinates, SPT values, or engineering constants. If something is missing, STOP and ask. Synthetic data is allowed ONLY under `assets/demo/`, and every such record must carry `"demo": true`. The UI must show a visible "DEMO VERİ" banner whenever demo data is displayed. Never describe demo data as real geology.

R2. NO GUESSED APIs. After adding any package, read the resolved version in `pubspec.lock`, then read that version's README, CHANGELOG and source (in the pub cache) BEFORE using its API. Record the exact constructors/parameters you use in `docs/DECISIONS.md`. If an API you expected does not exist, do not fake it with a wrapper. Known trap: `flutter_map` has NO `GeoJsonLayer`; parse GeoJSON yourself and draw with `PolygonLayer` / `PolylineLayer`.

R3. NO UNVERIFIED CLAIMS. Every task ends by running `dart format .`, `flutter analyze`, `flutter test` and reporting the real result. If a command cannot run (no SDK/device/network), say so explicitly. Never write "should work".

R4. SCOPE LOCK. Do only the current phase. No extra features, no refactors outside the phase, no dependencies outside the whitelist in SPEC §8 without asking.

R5. HUMAN-OWNED FILES are read-only for you: `assets/config/classification.csv`, `assets/config/risk_rules.json`, `assets/config/geotech_constants.json`, `assets/config/spt_samples.json`, and anything real in `assets/data/`. You may read them. If a value is missing or `verified` is false where a phase requires true, STOP and ask.

R6. EXTERNAL SERVICES: verify with a real request (curl or a Dart script), save a sample response under `test/fixtures/`, and write the parser against that fixture, never against remembered response shapes. The app must degrade gracefully (timeout, offline, malformed JSON) with a Turkish message.

R7. NEVER weaken, skip or delete a test to make it pass. If a test is wrong per SPEC, explain why and fix it explicitly. If a test still fails after two genuinely different fix attempts, STOP and report.

R8. ARCHITECTURE: domain code (parsing, geometry, rules, calculator) is pure Dart in `lib/features/*/domain/` and may import only `dart:*` and `latlong2`. UI is thin. State management is Riverpod only.

R9. LANGUAGE: UI strings Turkish. Code, comments, commit messages, docs English. README is English with a Turkish section.

R10. DISCLAIMER "Ön değerlendirmedir, zemin etüdünün yerine geçmez." must appear in: the info bottom sheet, the calculator result, and the PDF.

R11. GIT: one branch per phase (`phase/pN-name`), small conventional commits (`feat(map): ...`), never force-push, never commit secrets, keystores, `data/raw/`, or Er-Zem raw data. Tag `pN-done` at the end of a phase.

R12. DECISIONS: append every assumption, deviation and open question to `docs/DECISIONS.md` (date, phase, decision, reason).

## Stop and ask when
- a human-owned file is missing/empty or `verified` is false where required;
- a package API differs from what SPEC assumes;
- a new dependency seems necessary;
- a command needs network and none is available;
- requirements conflict or are ambiguous in a way that changes behavior.
Ask at most 3 batched questions and propose a default for each.

## End-of-task report (always use this format)
1. Status: DONE / PARTIAL / BLOCKED
2. Files created/changed (list)
3. Commands run + actual results (pass/fail counts, analyzer output)
4. Assumptions & deviations (also logged in DECISIONS.md)
5. Open questions / needed human input
6. Next phase readiness (yes/no + why)

## Global Definition of Done (each phase)
`flutter analyze` = 0 issues · `flutter test` all green · `dart format` clean · no fake data outside `assets/demo/` · no leftover TODO that hides missing work · report delivered.
