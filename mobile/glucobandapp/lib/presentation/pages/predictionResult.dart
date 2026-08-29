import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/predictionProvider.dart';
import '../providers/authProvider.dart';
import '../../data/models/predictionModel.dart';

class PredictionResultPage extends StatelessWidget {
  final Map<String, dynamic> inputData;
  const PredictionResultPage({super.key, required this.inputData});

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: provider.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    if (provider.riskResult != null) ...[
                      const SizedBox(height: 16),
                      _buildHeader(provider.trendResult, provider.riskResult!),
                      const SizedBox(height: 32),
                      if (hasTrendData && provider.trendResult != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildTrendCard(provider.trendResult!),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildWarningCard(provider.riskResult!),
                      ),
                      const SizedBox(height: 40),
                    ]
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(TrendPrediction? trend, RiskPrediction risk) {
    // We use the predicted glucose if available, else from input
    final predictedGlucose = (trend != null && trend.points.isNotEmpty)
        ? trend.points.last.glucose
        : (inputData['blood_glucose_level'] as num).toDouble();

    String statusTitle = 'Normal';
    String statusSubtitle = 'Kadar gula aman';
    Color mainColor = const Color(0xFF10B981); // Green
    IconData icon = Icons.check;

    if (predictedGlucose > 140) {
      statusTitle = 'Hiperglikemia';
      statusSubtitle = 'Sangat tinggi!!';
      mainColor = const Color(0xFFFF5252); // Red from mockup
      icon = Icons.warning_amber_rounded;
    } else if (predictedGlucose < 70) {
      statusTitle = 'Hipoglikemia';
      statusSubtitle = 'Terlalu rendah!!';
      mainColor = const Color(0xFFFFB74D); // Orange
      icon = Icons.error_outline;
    }

    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 24),
        Text(
          predictedGlucose.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: mainColor,
            height: 1,
            letterSpacing: -1.5,
          ),
        ),
        Text(
          'mg/dL',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: mainColor,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          statusTitle,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: mainColor,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          statusSubtitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: mainColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard(TrendPrediction trend) {
    final spots = trend.points.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.glucose)).toList();

    double maxY = 250;
    for (var p in trend.points) {
      if (p.glucose > maxY) maxY = p.glucose + 20;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik Tren Gula Darah',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '0${(value * 4).toInt() % 24}.00',
                            style: const TextStyle(fontSize: 9, color: Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF613EEA),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF613EEA).withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(RiskPrediction risk) {
    final isHigh = risk.riskLevel == 'Tinggi';
    final c = isHigh ? const Color(0xFFFF5252) : (risk.riskLevel == 'Sedang' ? const Color(0xFFFFB74D) : const Color(0xFF10B981));
    final msg = isHigh ? 'Anda Berisiko Tinggi Diabetes' : (risk.riskLevel == 'Sedang' ? 'Anda Berisiko Sedang' : 'Risiko Diabetes Rendah');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHigh ? Icons.warning_amber_rounded : (risk.riskLevel == 'Sedang' ? Icons.info_outline : Icons.check),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Berdasarkan profil dan data pengukuran Anda. Silakan konsultasi lebih lanjut dengan dokter.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
