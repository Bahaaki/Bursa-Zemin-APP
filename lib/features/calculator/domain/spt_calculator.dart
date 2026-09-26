import 'dart:convert';
import 'dart:math' as math;

/// Sample SPT record from config or demo.
class SptSample {
  final String id;
  final double depthM;
  final int nValue;
  final SoilKind soil;
  final bool isDemo;

  const SptSample({
    required this.id,
    required this.depthM,
    required this.nValue,
    required this.soil,
    this.isDemo = false,
  });

  factory SptSample.fromJson(Map<String, dynamic> json) {
    return SptSample(
      id: json['id'] as String? ?? 'bilinmiyor',
      depthM: (json['depth_m'] as num?)?.toDouble() ?? 1.5,
      nValue: (json['n_value'] as num?)?.toInt() ?? 10,
      soil: SoilKind.fromString(json['soil'] as String? ?? 'kum'),
      isDemo: json['demo'] == true,
    );
  }

  static List<SptSample> parseList(
    String rawJson, {
    bool isDemoFallback = false,
  }) {
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return decoded.map((item) {
      final map = item as Map<String, dynamic>;
      final sample = SptSample.fromJson(map);
      if (isDemoFallback) {
        return SptSample(
          id: sample.id,
          depthM: sample.depthM,
          nValue: sample.nValue,
          soil: sample.soil,
          isDemo: true,
        );
      }
      return sample;
    }).toList();
  }
}

/// Soil type for bearing capacity calculation.
enum SoilKind {
  kum('kum', 'Kum (Kohezyonsuz)'),
  kil('kil', 'Kil (Kohezyonlu)');

  final String code;
  final String label;

  const SoilKind(this.code, this.label);

  static SoilKind fromString(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'kum' || normalized == 'kohezyonsuz') return SoilKind.kum;
    if (normalized == 'kil' || normalized == 'kohezyonlu') return SoilKind.kil;
    throw BearingCapacityException(
      'Geçersiz zemin türü: "$value". Yalnızca "kum" veya "kil" kabul edilir.',
    );
  }
}

/// Footing shape per Terzaghi bearing capacity theory.
enum FootingShape {
  serit('serit', 'Şerit'),
  kare('kare', 'Kare'),
  dairesel('dairesel', 'Dairesel');

  final String code;
  final String label;

  const FootingShape(this.code, this.label);

  static FootingShape fromString(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'serit' ||
        normalized == 'şerit' ||
        normalized == 'strip') {
      return FootingShape.serit;
    }
    if (normalized == 'kare' || normalized == 'square') {
      return FootingShape.kare;
    }
    if (normalized == 'dairesel' || normalized == 'circular') {
      return FootingShape.dairesel;
    }
    throw BearingCapacityException(
      'Geçersiz temel geometrisi: "$value". "serit", "kare" veya "dairesel" olmalıdır.',
    );
  }
}

/// Typed exception thrown on invalid bearing capacity input parameters.
class BearingCapacityException implements Exception {
  final String message;

  const BearingCapacityException(this.message);

  @override
  String toString() => 'BearingCapacityException: $message';
}

/// Point on the Terzaghi N-gamma empirical correlation curve.
class NGammaPoint {
  final double phi;
  final double ng;

  const NGammaPoint(this.phi, this.ng);
}

/// Inputs for Terzaghi general shear bearing capacity calculation.
class BearingInput {
  final SoilKind soilKind;
  final int nValue;
  final double nCorrection;
  final FootingShape footingShape;
  final double b;
  final double df;
  final double gamma;
  final double fs;
  final double cuFactor;

  const BearingInput({
    required this.soilKind,
    required this.nValue,
    this.nCorrection = 1.0,
    required this.footingShape,
    required this.b,
    required this.df,
    this.gamma = 18.0,
    this.fs = 3.0,
    this.cuFactor = 6.0,
  });
}

/// Results of Terzaghi general shear bearing capacity calculation.
class BearingResult {
  final SoilKind soilKind;
  final int nValue;
  final double effectiveN;
  final double? phiDeg;
  final double? cuKpa;
  final double nc;
  final double nq;
  final double ng;
  final double q;
  final double qUlt;
  final double qAll;
  final FootingShape footingShape;
  final double b;
  final double df;
  final double gamma;
  final double fs;
  final List<String> warnings;

  const BearingResult({
    required this.soilKind,
    required this.nValue,
    required this.effectiveN,
    this.phiDeg,
    this.cuKpa,
    required this.nc,
    required this.nq,
    required this.ng,
    required this.q,
    required this.qUlt,
    required this.qAll,
    required this.footingShape,
    required this.b,
    required this.df,
    required this.gamma,
    required this.fs,
    required this.warnings,
  });
}

/// Pure Dart SPT bearing capacity calculator implementing Terzaghi general shear (SPEC §4).
class SptCalculator {
  /// Default Terzaghi N_gamma values from assets/config/geotech_constants.json.
  static const List<NGammaPoint> defaultNGammaTable = [
    NGammaPoint(0.0, 0.0),
    NGammaPoint(5.0, 0.5),
    NGammaPoint(10.0, 1.2),
    NGammaPoint(15.0, 2.5),
    NGammaPoint(20.0, 5.0),
    NGammaPoint(25.0, 9.7),
    NGammaPoint(30.0, 19.7),
    NGammaPoint(35.0, 42.4),
    NGammaPoint(40.0, 100.4),
    NGammaPoint(45.0, 297.5),
    NGammaPoint(50.0, 1153.2),
  ];

  /// Calculate N_q using Terzaghi's (1943) formula:
  /// Nq = e^{2(3pi/4 - phi/2)*tan(phi)} / (2*cos^2(45° + phi/2))
  /// For phi = 0, Nq = 1.0.
  static double calculateNq(double phiDeg) {
    if (phiDeg <= 0.0) return 1.0;
    final phiRad = phiDeg * math.pi / 180.0;
    final exponent =
        2.0 * (3.0 * math.pi / 4.0 - phiRad / 2.0) * math.tan(phiRad);
    final cosTerm = math.cos(math.pi / 4.0 + phiRad / 2.0);
    final denominator = 2.0 * cosTerm * cosTerm;
    return math.exp(exponent) / denominator;
  }

  /// Calculate N_c using:
  /// Nc = (Nq - 1) * cot(phi) for phi > 0, Nc = 5.7 for phi = 0.
  static double calculateNc(double phiDeg, double nq) {
    if (phiDeg <= 0.0) return 5.7;
    final phiRad = phiDeg * math.pi / 180.0;
    return (nq - 1.0) / math.tan(phiRad);
  }

  /// Interpolate N_gamma linearly from table in geotech_constants.json.
  /// N_gamma = 0 at phi = 0.
  static double interpolateNgamma(
    double phiDeg, [
    List<NGammaPoint>? table,
  ]) {
    final pts = table ?? defaultNGammaTable;
    if (phiDeg <= pts.first.phi) return pts.first.ng;
    if (phiDeg >= pts.last.phi) return pts.last.ng;

    for (int i = 0; i < pts.length - 1; i++) {
      final p1 = pts[i];
      final p2 = pts[i + 1];
      if (phiDeg >= p1.phi && phiDeg <= p2.phi) {
        final t = (phiDeg - p1.phi) / (p2.phi - p1.phi);
        return p1.ng + t * (p2.ng - p1.ng);
      }
    }
    return pts.last.ng;
  }

  /// Main calculation method according to SPEC §4.
  static BearingResult calculate(
    BearingInput input, {
    List<NGammaPoint>? nGammaTable,
  }) {
    // 1. Validation
    if (input.nValue < 1 || input.nValue > 100) {
      throw BearingCapacityException(
        'N değeri 1 ile 100 arasında olmalıdır. Girilen: ${input.nValue}',
      );
    }
    if (input.b <= 0) {
      throw BearingCapacityException(
        'Temel genişliği (B) 0\'dan büyük olmalıdır. Girilen: ${input.b}',
      );
    }
    if (input.df < 0) {
      throw BearingCapacityException(
        'Temel derinliği (Df) negatif olamaz. Girilen: ${input.df}',
      );
    }
    if (input.gamma <= 0) {
      throw BearingCapacityException(
        'Birim hacim ağırlık (γ) 0\'dan büyük olmalıdır. Girilen: ${input.gamma}',
      );
    }
    if (input.fs <= 0) {
      throw BearingCapacityException(
        'Güvenlik katsayısı (FS) 0\'dan büyük olmalıdır. Girilen: ${input.fs}',
      );
    }
    if (input.nCorrection <= 0) {
      throw BearingCapacityException(
        'SPT düzeltme katsayısı 0\'dan büyük olmalıdır. Girilen: ${input.nCorrection}',
      );
    }
    if (input.cuFactor <= 0) {
      throw BearingCapacityException(
        'cu katsayısı 0\'dan büyük olmalıdır. Girilen: ${input.cuFactor}',
      );
    }

    final effectiveN = input.nValue * input.nCorrection;

    // 2. Soil parameters
    final double phiDeg;
    final double cKpa;
    final double? cuKpa;
    final double? displayPhi;

    if (input.soilKind == SoilKind.kum) {
      // Granular: phi = 27.1 + 0.3*N - 0.00054*N^2 (Wolff 1989), c = 0
      phiDeg = 27.1 + 0.3 * effectiveN - 0.00054 * effectiveN * effectiveN;
      cKpa = 0.0;
      cuKpa = null;
      displayPhi = phiDeg;
    } else {
      // Cohesive: phi = 0, c = cu = k*N with k from constants (default 6.0 kPa/N)
      phiDeg = 0.0;
      cKpa = input.cuFactor * effectiveN;
      cuKpa = cKpa;
      displayPhi = 0.0;
    }

    // 3. Surcharge
    final q = input.gamma * input.df;

    // 4. Terzaghi factors
    final nq = calculateNq(phiDeg);
    final nc = calculateNc(phiDeg, nq);
    final ng = interpolateNgamma(phiDeg, nGammaTable);

    // 5. Ultimate bearing capacity (q_ult)
    // Şerit: q_ult = c*Nc + q*Nq + 0.5*gamma*B*Ng
    // Kare:  q_ult = 1.3*c*Nc + q*Nq + 0.4*gamma*B*Ng
    // Dairesel: q_ult = 1.3*c*Nc + q*Nq + 0.3*gamma*B*Ng
    final double cohesionShapeFactor;
    final double gammaShapeFactor;

    switch (input.footingShape) {
      case FootingShape.serit:
        cohesionShapeFactor = 1.0;
        gammaShapeFactor = 0.5;
        break;
      case FootingShape.kare:
        cohesionShapeFactor = 1.3;
        gammaShapeFactor = 0.4;
        break;
      case FootingShape.dairesel:
        cohesionShapeFactor = 1.3;
        gammaShapeFactor = 0.3;
        break;
    }

    final qUlt = (cohesionShapeFactor * cKpa * nc) +
        (q * nq) +
        (gammaShapeFactor * input.gamma * input.b * ng);

    // 6. Allowable bearing capacity (q_all)
    final qAll = qUlt / input.fs;

    // 7. Warnings per SPEC §4
    final warnings = <String>[
      'Yeraltı su seviyesi dikkate alınmamıştır.',
      'Korelasyon yalnızca belirtilen zemin türü için geçerlidir.',
    ];

    if (effectiveN > 50) {
      warnings.add(
        'N > 50: SPT refüsü durumu. Taşıma gücü formülleri yüksek N değerlerinde aşırı muhafazakar veya güvenilmez sonuçlar verebilir.',
      );
    }

    return BearingResult(
      soilKind: input.soilKind,
      nValue: input.nValue,
      effectiveN: effectiveN,
      phiDeg: displayPhi,
      cuKpa: cuKpa,
      nc: nc,
      nq: nq,
      ng: ng,
      q: q,
      qUlt: qUlt,
      qAll: qAll,
      footingShape: input.footingShape,
      b: input.b,
      df: input.df,
      gamma: input.gamma,
      fs: input.fs,
      warnings: warnings,
    );
  }
}
