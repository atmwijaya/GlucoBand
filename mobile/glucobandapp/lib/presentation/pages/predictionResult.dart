import 'package:flutter/material.dart';

class PredictionResultPage extends StatelessWidget {
  final Map<String, dynamic> predictionData;

  const PredictionResultPage({Key? key, required this.predictionData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Hasil Prediksi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kartu hasil ringkasan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Risiko Diabetes Rendah',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Skor Risiko: 0.23',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Kartu detail data
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Input',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Berat', '${predictionData['weight']} kg'),
                  _buildInfoRow(
                      'Tinggi', '${predictionData['height']} cm'),
                  _buildInfoRow('BMI',
                      predictionData['bmi'].toStringAsFixed(1)),
                  _buildInfoRow(
                      'Usia', '${predictionData['age']} tahun'),
                  _buildInfoRow('Jenis Kelamin',
                      predictionData['gender'] == 'L' ? 'Laki-laki' : 'Perempuan'),
                  _buildInfoRow('Aktivitas', predictionData['activity']),
                  const SizedBox(height: 12),
                  const Text(
                    'Riwayat Glukosa',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  ...predictionData['glucoseHistory'].map<Widget>((g) => Text(
                        '• $g mg/dL',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF475569)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Kartu rekomendasi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡 Rekomendasi',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF)),
                  ),
                  SizedBox(height: 8),
                  Text('• Jaga pola makan seimbang'),
                  Text('• Rutin berolahraga 30 menit/hari'),
                  Text('• Periksa gula darah secara berkala'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  fontSize: 14)),
        ],
      ),
    );
  }
}