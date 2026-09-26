import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import 'domain/spt_calculator.dart';

/// Screen for SPT bearing capacity calculation using Terzaghi general shear theory (SPEC §4).
class CalculatorScreen extends StatefulWidget {
  final LatLng? initialCoordinates;
  final List<SptSample>? initialSamples;

  const CalculatorScreen({
    super.key,
    this.initialCoordinates,
    this.initialSamples,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nController;
  late final TextEditingController _bController;
  late final TextEditingController _dfController;
  late final TextEditingController _gammaController;
  late final TextEditingController _fsController;
  late final TextEditingController _nCorrectionController;

  SoilKind _soilKind = SoilKind.kum;
  FootingShape _footingShape = FootingShape.kare;

  List<SptSample> _samples = [];
  String? _selectedSampleId;
  bool _loadingSamples = true;

  BearingResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _nController = TextEditingController(text: '10');
    _bController = TextEditingController(text: '2.0');
    _dfController = TextEditingController(text: '1.0');
    _gammaController = TextEditingController(text: '18.0');
    _fsController = TextEditingController(text: '3.0');
    _nCorrectionController = TextEditingController(text: '1.0');

    _nController.addListener(_onInputChanged);
    _bController.addListener(_onInputChanged);
    _dfController.addListener(_onInputChanged);
    _gammaController.addListener(_onInputChanged);
    _fsController.addListener(_onInputChanged);
    _nCorrectionController.addListener(_onInputChanged);

    _initSamples();
    _recalculate();
  }

  @override
  void dispose() {
    _nController.dispose();
    _bController.dispose();
    _dfController.dispose();
    _gammaController.dispose();
    _fsController.dispose();
    _nCorrectionController.dispose();
    super.dispose();
  }

  Future<void> _initSamples() async {
    if (widget.initialSamples != null) {
      if (!mounted) return;
      setState(() {
        _samples = widget.initialSamples!;
        _loadingSamples = false;
      });
      return;
    }

    try {
      // 1. Try real config file
      final raw = await rootBundle.loadString('assets/config/spt_samples.json');
      final loaded = SptSample.parseList(raw, isDemoFallback: false);
      if (!mounted) return;
      setState(() {
        _samples = loaded;
        _loadingSamples = false;
      });
    } catch (_) {
      // 2. Fall back to demo file
      try {
        final raw =
            await rootBundle.loadString('assets/demo/spt_samples_demo.json');
        final loaded = SptSample.parseList(raw, isDemoFallback: true);
        if (!mounted) return;
        setState(() {
          _samples = loaded;
          _loadingSamples = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _samples = [];
          _loadingSamples = false;
        });
      }
    }
  }

  void _onInputChanged() {
    _recalculate();
  }

  void _recalculate() {
    final nText = _nController.text.trim();
    final bText = _bController.text.trim().replaceAll(',', '.');
    final dfText = _dfController.text.trim().replaceAll(',', '.');
    final gammaText = _gammaController.text.trim().replaceAll(',', '.');
    final fsText = _fsController.text.trim().replaceAll(',', '.');
    final nCorrText = _nCorrectionController.text.trim().replaceAll(',', '.');

    final nVal = int.tryParse(nText);
    final bVal = double.tryParse(bText);
    final dfVal = double.tryParse(dfText);
    final gammaVal = double.tryParse(gammaText);
    final fsVal = double.tryParse(fsText);
    final nCorrVal = double.tryParse(nCorrText);

    if (nVal == null ||
        bVal == null ||
        dfVal == null ||
        gammaVal == null ||
        fsVal == null ||
        nCorrVal == null) {
      _result = null;
      _errorMessage = 'Lütfen tüm alanlara geçerli sayısal değerler giriniz.';
      if (mounted) setState(() {});
      return;
    }

    try {
      final input = BearingInput(
        soilKind: _soilKind,
        nValue: nVal,
        nCorrection: nCorrVal,
        footingShape: _footingShape,
        b: bVal,
        df: dfVal,
        gamma: gammaVal,
        fs: fsVal,
      );

      final res = SptCalculator.calculate(input);
      _result = res;
      _errorMessage = null;
      if (mounted) setState(() {});
    } on BearingCapacityException catch (e) {
      _result = null;
      _errorMessage = e.message;
      if (mounted) setState(() {});
    } catch (e) {
      _result = null;
      _errorMessage = 'Hesaplama hatası: $e';
      if (mounted) setState(() {});
    }
  }

  void _applySample(SptSample sample) {
    setState(() {
      _selectedSampleId = sample.id;
      _soilKind = sample.soil;
      _nController.text = sample.nValue.toString();
      _dfController.text = sample.depthM.toStringAsFixed(1);
    });
    _recalculate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPT Taşıma Gücü Hesabı'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Prefilled Map Coordinates Info (SPEC §4)
            if (widget.initialCoordinates != null) ...[
              Card(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.secondary.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pin_drop_rounded,
                        color: theme.colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seçilen Konum Koordinatı',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            Text(
                              '${widget.initialCoordinates!.latitude.toStringAsFixed(4)}° K, ${widget.initialCoordinates!.longitude.toStringAsFixed(4)}° D',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Optional "Örnek SPT verisi" Dropdown (SPEC §4)
            if (!_loadingSamples && _samples.isNotEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: DropdownButtonFormField<String>(
                    value: _selectedSampleId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Örnek SPT Verisi (İsteğe Bağlı)',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.science_outlined),
                    ),
                    hint: const Text('Kayıtlı örneklerden seçin...'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Manuel Giriş (Seçim yok)'),
                      ),
                      ..._samples.map((s) {
                        final demoBadge = s.isDemo ? ' [DEMO]' : '';
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(
                            '${s.id}$demoBadge: ${s.soil.label}, N=${s.nValue}, D=${s.depthM} m',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val == null) {
                        setState(() => _selectedSampleId = null);
                      } else {
                        final sample = _samples.firstWhere((s) => s.id == val);
                        _applySample(sample);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Input Fields Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zemin ve Temel Parametreleri',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Soil Kind Segmented Button
                    Text(
                      'Zemin Türü',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<SoilKind>(
                        segments: const [
                          ButtonSegment<SoilKind>(
                            value: SoilKind.kum,
                            label: Text('Kum (Kohezyonsuz)'),
                            icon: Icon(Icons.grain),
                          ),
                          ButtonSegment<SoilKind>(
                            value: SoilKind.kil,
                            label: Text('Kil (Kohezyonlu)'),
                            icon: Icon(Icons.water),
                          ),
                        ],
                        selected: {_soilKind},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _soilKind = newSelection.first;
                          });
                          _recalculate();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Footing Shape Segmented Button
                    Text(
                      'Temel Geometrisi',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<FootingShape>(
                        segments: const [
                          ButtonSegment<FootingShape>(
                            value: FootingShape.serit,
                            label: Text('Şerit'),
                          ),
                          ButtonSegment<FootingShape>(
                            value: FootingShape.kare,
                            label: Text('Kare'),
                          ),
                          ButtonSegment<FootingShape>(
                            value: FootingShape.dairesel,
                            label: Text('Dairesel'),
                          ),
                        ],
                        selected: {_footingShape},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _footingShape = newSelection.first;
                          });
                          _recalculate();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SPT N Value
                    TextFormField(
                      key: const ValueKey('n_input'),
                      controller: _nController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SPT N Değeri (1 - 100)',
                        hintText: 'örn. 15',
                        prefixIcon: Icon(Icons.speed_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // B & Df Fields
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('b_input'),
                            controller: _bController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Temel Genişliği B (m)',
                              hintText: 'örn. 2.0',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey('df_input'),
                            controller: _dfController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Temel Derinliği Df (m)',
                              hintText: 'örn. 1.0',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Advanced Parameters Collapsible
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Gelişmiş Parametreler (Varsayılanlar)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: const ValueKey('gamma_input'),
                                controller: _gammaController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'γ (kN/m³)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                key: const ValueKey('fs_input'),
                                controller: _fsController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Güvenlik Katsayısı (FS)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('n_corr_input'),
                          controller: _nCorrectionController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText:
                                'SPT Düzeltme Katsayısı (varsayılan: 1.0)',
                            hintText: '1.0',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Error Display (if any)
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Calculation Results
            if (_result != null) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Güvenli Taşıma Gücü (q_all)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_result!.qAll.toStringAsFixed(1)} kPa',
                        key: const ValueKey('q_all_result'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Nihai Taşıma Gücü (q_ult):',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${_result!.qUlt.toStringAsFixed(1)} kPa',
                            key: const ValueKey('q_ult_result'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Intermediate Values (Ara Değerler) Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hesaplanan Ara Değerler',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      if (_result!.soilKind == SoilKind.kum)
                        _buildParamRow(
                          'İçsel Sürtünme Açısı (φ)',
                          '${_result!.phiDeg!.toStringAsFixed(2)}° (Wolff)',
                        )
                      else
                        _buildParamRow(
                          'Drenajsız Kayma Dayanımı (cu)',
                          '${_result!.cuKpa!.toStringAsFixed(1)} kPa (Stroud)',
                        ),
                      const Divider(height: 12),
                      _buildParamRow(
                        'Nc Katsayısı',
                        _result!.nc.toStringAsFixed(2),
                      ),
                      const Divider(height: 12),
                      _buildParamRow(
                        'Nq Katsayısı',
                        _result!.nq.toStringAsFixed(2),
                      ),
                      const Divider(height: 12),
                      _buildParamRow(
                        'Nγ Katsayısı',
                        _result!.ng.toStringAsFixed(2),
                      ),
                      const Divider(height: 12),
                      _buildParamRow(
                        'Sürşarj Basıncı (q = γ·Df)',
                        '${_result!.q.toStringAsFixed(1)} kPa',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Warnings Card (SPEC §4)
              if (_result!.warnings.isNotEmpty) ...[
                Card(
                  color: Colors.amber.withOpacity(0.08),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.amber.shade700.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Önemli Uyarılar',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._result!.warnings.map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      w,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.brown.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],

            // Legal Disclaimer (R10)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildParamRow(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
