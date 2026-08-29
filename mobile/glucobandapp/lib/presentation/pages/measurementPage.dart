import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'measurementResult.dart';

class MeasurementPage extends StatefulWidget {
  final bool autoStart;
  const MeasurementPage({super.key, this.autoStart = false});

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  double _gaugeValue = 0;
  bool _isMeasuring = false;
  String _statusText = 'Status Perangkat:\nSiap Digunakan';

  // Simulasi inisialisasi sensor
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMeasurement();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startMeasurement() async {
    if (_isMeasuring) return;

    setState(() {
      _isMeasuring = true;
      _statusText = 'Inisialisasi sensor...';
      _progress = 0;
    });

    // Simulasi proses inisialisasi
    await _simulateStep('Sensor NIR (AS7263)', () {
      setState(() {
        _progress = 0.25;
        _statusText = 'Sensor NIR aktif';
      });
    });

    await _simulateStep('Sensor PPG (MAX30105)', () {
      setState(() {
        _progress = 0.5;
        _statusText = 'Sensor PPG aktif';
      });
    });

    await _simulateStep('Sensor Suhu (MLX90614)', () {
      setState(() {
        _progress = 0.75;
        _statusText = 'Sensor Suhu aktif';
      });
    });

    await _simulateStep('Model AI', () {
      setState(() {
        _progress = 1.0;
        _statusText = 'Mengukur glukosa...';
      });
    });

    // Proses pengukuran
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final fakeGlucose = 85.0 + Random().nextDouble() * 45;

    setState(() {
      _gaugeValue = fakeGlucose;
      _isMeasuring = false;
      _statusText = 'Status Perangkat:\nPengukuran Selesai';
    });

    // Navigasi ke hasil
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementResultPage(
          glucose: fakeGlucose,
          heartRate: 68 + Random().nextInt(12),
          temperature: 36.2 + Random().nextDouble() * 0.8,
        ),
      ),
    );
  }

  Future<void> _simulateStep(String label, VoidCallback onDone) async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) onDone();
  }

  Widget _buildRippleEffect() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (!_isMeasuring)
              Container(
                width: 220 + (_pulseController.value * 80),
                height: 220 + (_pulseController.value * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: (1.0 - _pulseController.value) * 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
            if (!_isMeasuring)
              Container(
                width: 220 + (((_pulseController.value + 0.5) % 1.0) * 80),
                height: 220 + (((_pulseController.value + 0.5) % 1.0) * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha:
                          (1.0 - ((_pulseController.value + 0.5) % 1.0)) * 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: _buildMainButton(),
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: _isMeasuring ? null : _startMeasurement,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isMeasuring
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: _isMeasuring
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'Mulai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // Glassmorphism effect
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF5A3FE0,
      ), // A rich purple background matching the image
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'GlucoBand',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.history,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      // Action for history if needed
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Center Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _isMeasuring
                    ? _statusText
                    : 'Status Perangkat:\nSiap Digunakan',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Big Circle Button with ripple
            _buildRippleEffect(),

            const Spacer(flex: 2),

            // Bottom Info Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'MACHINE LEARNING MODEL',
                          'XGBoost 1.0',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'STATUS',
                          'Connected',
                          valueColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard('BPM JANTUNG', '72 BPM')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInfoCard('SUHU TUBUH', '36.5°C')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
    );
  }
}
