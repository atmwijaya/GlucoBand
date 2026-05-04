import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'measurementResult.dart';

class MeasurementPage extends StatefulWidget {
  const MeasurementPage({Key? key}) : super(key: key);
  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  double _gaugeValue = 0;
  bool _isMeasuring = false;
  String _statusText = 'GlucoBand Siap';

  // Simulasi inisialisasi
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
      duration: const Duration(milliseconds: 1500),
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
      _nirReady = false;
      _ppgReady = false;
      _tempReady = false;
      _modelReady = false;
      _progress = 0;
      _gaugeValue = 0;
    });

    // Simulasi urutan inisialisasi
    await _simulateStep('Sensor NIR (AS7263)', () {
      setState(() {
        _nirReady = true;
        _statusText = 'Sensor NIR aktif';
        _progress = 0.25;
      });
    });

    await _simulateStep('Sensor PPG (MAX30105)', () {
      setState(() {
        _ppgReady = true;
        _statusText = 'Sensor PPG aktif';
        _progress = 0.5;
      });
    });

    await _simulateStep('Sensor Suhu (MLX90614)', () {
      setState(() {
        _tempReady = true;
        _statusText = 'Sensor Suhu aktif';
        _progress = 0.75;
      });
    });

    await _simulateStep('Model AI (XGBoost)', () {
      setState(() {
        _modelReady = true;
        _statusText = 'Model AI siap';
        _progress = 1.0;
      });
    });

    // Ukur
    setState(() {
      _statusText = 'Mengukur...';
    });
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    final fakeGlucose = 95.0 + Random().nextDouble() * 30;
    setState(() {
      _gaugeValue = fakeGlucose;
      _isMeasuring = false;
      _statusText = 'Pengukuran selesai';
    });

    // Pindah ke halaman hasil
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementResultPage(
          glucose: fakeGlucose,
          heartRate: 68 + Random().nextInt(10),
          spo2: 97 + Random().nextInt(3),
          temperature: 36.0 + Random().nextDouble() * 1.0,
        ),
      ),
    );
  }

  Future<void> _simulateStep(String label, VoidCallback onDone) async {
    await Future.delayed(const Duration(milliseconds: 500));
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pengukuran'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Gauge
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(260, 260),
                    painter: _GaugePainter(
                      value: _gaugeValue,
                      maxValue: 400,
                      pulseValue: _pulseController.value,
                    ),
                  );
                },
              ),
            ),
          ),
          // Status teks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _statusText,
              style: const TextStyle(fontSize: 16, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar inisialisasi
          if (_isMeasuring)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInitItem('NIR', Icons.wifi, _nirReady),
                      _buildInitItem('PPG', Icons.favorite, _ppgReady),
                      _buildInitItem('Suhu', Icons.thermostat, _tempReady),
                      _buildInitItem('XGBoost', Icons.psychology, _modelReady),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Tombol mulai ukur
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: GestureDetector(
              onTap: _isMeasuring ? null : _startMeasurement,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isMeasuring
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Center(
                  child: _isMeasuring
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Mulai Pengukuran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitItem(String label, IconData icon, bool isReady) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReady ? const Color(0xFF10B981).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isReady ? const Color(0xFF10B981) : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isReady ? const Color(0xFF10B981) : Colors.grey,
            fontWeight: isReady ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// CustomPainter sederhana untuk gauge
class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final double pulseValue;

  _GaugePainter({required this.value, required this.maxValue, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;

    // Background circle
    canvas.drawCircle(center, radius + 20,
        Paint()..color = Colors.white);
    canvas.drawCircle(center, radius + 20,
        Paint()
          ..color = Colors.black.withOpacity(0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));

    // Inner circle
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      pi * 0.75,
      pi * 1.5,
      false,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );

    // Value arc
    if (value > 0) {
      final sweep = (value / maxValue) * pi * 1.5;
      Color c;
      if (value < 70) c = const Color(0xFFF59E0B);
      else if (value > 200) c = const Color(0xFFEF4444);
      else c = const Color(0xFF10B981);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 10),
        pi * 0.75,
        sweep,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
    }

    // Teks di tengah
    _drawCenteredText(canvas, value > 0 ? value.toInt().toString() : '--',
        center.dx, center.dy - 10, 40,
        color: value > 200 ? const Color(0xFFEF4444) : value < 70 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    _drawCenteredText(canvas, 'mg/dL', center.dx, center.dy + 30, 14,
        color: const Color(0xFF64748B));
  }

  void _drawCenteredText(Canvas canvas, String text, double cx, double cy, double fontSize, {Color color = Colors.black}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => true;
}