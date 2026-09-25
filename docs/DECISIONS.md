# DECISIONS — Bursa Zemin

| Date | Phase | Decision | Reason |
|---|---|---|---|
| 2026-09-25 | P0 | Flutter 3.24.0 / Dart 3.5.0 / DevTools 2.37.2 | Existing SDK on machine. Plan says do not upgrade. |
| 2026-09-25 | P0 | JDK: OpenJDK 21.0.9 (Android Studio 2025.3.2 bundled) | `flutter doctor -v` reports this version. |
| 2026-09-25 | P0 | APP_ID = com.ahmed.bursazemin | Human choice (Gate G0). Template generated `com.ahmed.bursa_zemin` (with underscore); renamed namespace, package dir, and applicationId to match the chosen ID without underscore. |
| 2026-09-25 | P0 | DEVELOPER_NAME = Ahmed | Human choice (Gate G0). |
| 2026-09-25 | P0 | Gradle 7.6.3 → 8.5 | JDK 21 requires Gradle ≥ 8.5. Gradle 7.6.3 (Flutter 3.24 template default) is incompatible with JDK ≥ 20. See https://docs.gradle.org/current/userguide/compatibility.html#java |
| 2026-09-25 | P0 | AGP 7.3.0 → 8.1.0 | AGP 7.x is incompatible with Gradle 8.5. AGP 8.1 is the minimum that works with Gradle 8.5. |
| 2026-09-25 | P0 | Kotlin 1.7.10 → 1.9.10 | AGP 8.1 requires Kotlin ≥ 1.8.20. Chose 1.9.10 as the latest 1.9.x stable at time of Flutter 3.24. |
| 2026-09-25 | P0 | Java source/target 1.8 → 17 | AGP 8.x with JDK 21 requires Java target ≥ 11. Used 17 as the recommended baseline for AGP 8.x. |
| 2026-09-25 | P0 | minSdk = 21 | Matches Flutter 3.24 default (`flutter.minSdkVersion`). Supports 98%+ of active Android devices. Pinned explicitly to prevent drift if Flutter default changes. |
| 2026-09-25 | P0 | AGP 8.1.0 → 8.3.0 (second fix) | AGP 8.1 max recommended compileSdk=33; Flutter 3.24 pulls in androidx.core:1.13.1 which requires compileSdk≥34. Lowering to SDK 33 broke the dependency. Lowering was also not the right fix: the real root cause was AGP 8.1.x jlink failure with JDK 21 + SDK 34. AGP 8.3.0 (released Feb 2024) fixes the jlink/JDK-21 transform and officially supports compileSdk 34. compileSdk reverted to flutter.compileSdkVersion (34). |
| 2026-09-25 | P0 | INTERNET permission in main AndroidManifest.xml | Flutter template only includes INTERNET in debug/profile manifests. Release builds would fail to load OSM tiles without it. SPEC §7 requires this. |
| 2026-09-25 | P0 | risk_rules.json fault thresholds (1 km / 5 km) remain `verified: false` | See DECISIONS note below on source. Human must confirm before G2. |
| 2026-09-25 | P0 | geotech_constants.json remains `verified: false` | All values are drafts per SPEC §10. Human must verify against textbook before G3. |

## Notes

### Fault distance thresholds — source investigation

The plan's review research attributed the 1 km / 5 km thresholds to "TBDY 2018" (Türkiye Bina Deprem Yönetmeliği) and AFAD guidelines. However, **TBDY 2018 does not define explicit distance-to-fault risk classification tiers of 1 km and 5 km**. What TBDY 2018 does say:

- **Section 2.3 (Yakın Fay Etkisi):** Buildings within ~15 km of an active fault with M ≥ 7 potential must apply near-fault coefficients to the design spectrum. No discrete 1/5 km risk categories are defined.
- **AFAD fault maps** (Diri Fay Haritası) classify faults by activity (Holocene, Pleistocene) but do not prescribe a 1/5 km warning radius.

The 1 km and 5 km values are **reasonable engineering judgment** thresholds commonly used in Turkish geotechnical practice for preliminary screening, but they are **not directly cited from a specific article/section of TBDY 2018 or any AFAD regulation**. They remain `verified: false` and the human must decide whether to adopt, adjust, or cite a specific local authority reference.
