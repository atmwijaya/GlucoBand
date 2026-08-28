import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'measurementResult.dart';

class MeasurementPage extends StatefulWidget {
  const MeasurementPage({super.key});

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  double _gaugeValue = 0;
  bool _isMeasuring = false;
  String _statusText = 'GlucoBand Siap';

  // Simulasi inisialisasi sensor
  bool _nirReady = false;
  bool _ppgReady = false;
  bool _tempReady = false;
  bool _modelReady = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
    _nirReady = _ppgReady = _tempReady = _modelReady = false;
    _progress = 0;
    _gaugeValue = 0;
  });

  // Simulasi proses inisialisasi
  await _simulateStep('Sensor NIR (AS7263)', () {
    setState(() {
      _nirReady = true;
      _progress = 0.25;
      _statusText = 'Sensor NIR aktif';
    });
  });

  await _simulateStep('Sensor PPG (MAX30105)', () {
    setState(() {
      _ppgReady = true;
      _progress = 0.5;
      _statusText = 'Sensor PPG aktif';
    });
  });

  await _simulateStep('Sensor Suhu (MLX90614)', () {
    setState(() {
      _tempReady = true;
      _progress = 0.75;
      _statusText = 'Sensor Suhu aktif';
    });
  });

  await _simulateStep('Model AI', () {
    setState(() {
      _modelReady = true;
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
    _statusText = 'Pengukuran selesai';
  });

  // Navigasi ke hasil
  if (!mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MeasurementResultPage(
        glucose: fakeGlucose,
        heartRate: 68 + Random().nextInt(12),
        spo2: 96 + Random().nextInt(4),
        temperature: 36.2 + Random().nextDouble() * 0.8,
      ),
    ),
  );
}

  Future<void> _simulateStep(String label, VoidCallback onDone) async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF613EEA), // Solid purple background
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
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white, size: 28),
                    onPressed: () {
                      // Action for history if needed
                    },
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 1),

            // Center Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _isMeasuring ? _statusText : 'Pastikan sensor menempel\ndengan baik pada kulit.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Big Circle Button
            GestureDetector(
              onTap: _isMeasuring ? null : _startMeasurement,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isMeasuring ? Colors.white.withOpacity(0.2) : Colors.transparent,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
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
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Mulai',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
