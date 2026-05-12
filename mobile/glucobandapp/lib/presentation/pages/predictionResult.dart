import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/predictionProvider.dart';
import '../providers/authProvider.dart';
import '../../data/models/predictionModel.dart';

class PredictionResultPage extends StatelessWidget {
  final Map<String, dynamic> inputData;
  const PredictionResultPage({Key? key, required this.inputData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PredictionProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    // Auto fetch jika belum ada data
    if (provider.riskResult == null && !provider.loading) {
      Future.microtask(() => provider.fetchRisk(inputData, auth.token!));
    }

    final history = inputData['glucose_history'] as List?;
    final validHistory = history
        ?.where((v) => (v is num ? v.toDouble() : 0) > 0)
        .toList() ?? [];
    final hasTrendData = validHistory.length >= 3;

    if (hasTrendData && provider.trendResult == null && !provider.loading) {
      Future.microtask(() => provider.fetchTrend(
            validHistory.map((e) => (e as num).toDouble()).toList(),
            6,
            auth.token!,
          ));
    }

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
            if (provider.riskResult != null) _buildRiskCard(provider.riskResult!),
            if (provider.riskResult != null) const SizedBox(height: 24),

            if (hasTrendData && provider.trendResult != null)
              _buildTrendCard(provider.trendResult!),
            
            if (provider.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(RiskPrediction risk) {
    final level = risk.riskLevel;
    final score = risk.riskScore;
    final model = risk.modelVersion;
    Color c = level == 'Tinggi' ? Colors.red : (level == 'Sedang' ? Colors.orange : Colors.green);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withOpacity(0.9), c.withOpacity(0.6)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Icon(Icons.health_and_safety, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text('Risiko Diabetes', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(level, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Skor: ${score.toStringAsFixed(3)}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Model: $model', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTrendCard(TrendPrediction trend) {
    final spots = trend.points.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.glucose)).toList();

    // Ambil prediksi terakhir (t+6 jam)
    final lastPoint = trend.points.isNotEmpty ? trend.points.last : null;
    final predictedGlucose = lastPoint?.glucose ?? 0;
    final lastGlucoseFormatted = predictedGlucose.toStringAsFixed(1);

    // Klasifikasi sederhana
    String status = 'Normal';
    Color statusColor = Colors.green;
    
    if (predictedGlucose > 140) {
      status = 'Hiperglikemia';
      statusColor = Colors.red;
    } else if (predictedGlucose < 70) {
      status = 'Hipoglikemia';
      statusColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              const Text(
                'Prediksi Tren Glukosa',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trend.modelVersion,
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Prediksi Utama
          Center(
            child: Column(
              children: [
                Text(
                  lastGlucoseFormatted,
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  'mg/dL (6 jam ke depan)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(show: true),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3B82F6).withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Grafik di atas menunjukkan prediksi glukosa darah 6 jam ke depan',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}