import 'package:flutter/material.dart';

class MeasurementResultPage extends StatelessWidget {
  final double glucose;
  final int heartRate;
  final int spo2;
  final double temperature;

  const MeasurementResultPage({
    Key? key,
    required this.glucose,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = glucose > 200
        ? 'Hiperglikemia'
        : glucose < 70
            ? 'Hipoglikemia'
            : 'Normal';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Hasil Pengukuran'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kartu hasil utama
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    glucose > 200
                        ? const Color(0xFFEF4444)
                        : glucose < 70
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                    (glucose > 200
                            ? const Color(0xFFEF4444)
                            : glucose < 70
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                        .withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (glucose > 200
                            ? const Color(0xFFEF4444)
                            : glucose < 70
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                        .withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.monitor_heart, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    '${glucose.toInt()} mg/dL',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Kartu data tambahan
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    Icons.favorite,
                    const Color(0xFFEF4444),
                    '$heartRate',
                    'BPM',
                    'Detak Jantung',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    Icons.air,
                    const Color(0xFF3B82F6),
                    '$spo2%',
                    'SpO2',
                    'Oksigen',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    Icons.thermostat,
                    const Color(0xFFF59E0B),
                    '${temperature.toStringAsFixed(1)}°C',
                    'Suhu',
                    'Kulit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Kartu detail sensor & model
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail Pengukuran',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.wifi, 'Sensor NIR', 'AS7263 (610–860 nm)'),
                  const Divider(height: 16),
                  _buildDetailRow(Icons.favorite, 'Sensor PPG', 'MAX30105 (Red/IR/Green)'),
                  const Divider(height: 16),
                  _buildDetailRow(Icons.thermostat, 'Sensor Suhu', 'MLX90614 (Inframerah)'),
                  const Divider(height: 16),
                  _buildDetailRow(Icons.psychology, 'Model AI', 'XGBoost Regressor v1.0'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tombol kembali
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Ukur Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, Color color, String value, String unit, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        Text(unit, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String detail) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }
}