import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/predictionProvider.dart';
import '../providers/authProvider.dart';
import '../../data/models/predictionModel.dart';
import '../widgets/recommendationCard.dart';

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
    final validHistory =
        history?.where((v) => (v is num ? v.toDouble() : 0) > 0).toList() ?? [];
    final hasTrendData = validHistory.length >= 3;

    if (hasTrendData && provider.trendResult == null && !provider.loading) {
      Future.microtask(() => provider.fetchTrend(inputData, 6, auth.token!));
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
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.black87,
                        ),
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
                          child: Column(
                            children: [
                              _buildTrendCard(provider.trendResult!),
                              const SizedBox(height: 16),
                              _buildPredictionGrid(provider.trendResult!),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildWarningCard(
                          provider.riskResult!,
                          provider.trendResult,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
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

    if (predictedGlucose > 200) {
      statusTitle = 'Hiperglikemia';
      statusSubtitle = 'Sangat tinggi!!';
      mainColor = const Color(0xFFFF5252); // Red from mockup
      icon = Icons.warning_amber_rounded;
    } else if (predictedGlucose > 140) {
      statusTitle = 'Gula Darah Meningkat';
      statusSubtitle = 'Di atas rentang optimal';
      mainColor = const Color(0xFFFF9800); // Amber/Orange
      icon = Icons.trending_up;
    } else if (predictedGlucose < 70) {
      statusTitle = 'Hipoglikemia';
      statusSubtitle = 'Terlalu rendah!!';
      mainColor = const Color(0xFFEF4444); // Red
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
        if (trend != null && trend.points.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '(Prediksi pada 6 jam kedepan)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: mainColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrendCard(TrendPrediction trend) {
    final spots = trend.points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.glucose))
        .toList();

    double maxY = 250;
    for (var p in trend.points) {
      if (p.glucose > maxY) maxY = p.glucose + 20;
    }

    // Calculate LSTM confidence (moved to _buildWarningCard or helper if needed, but keeping it here if used elsewhere. Wait, it is not used in this widget.)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
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
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: 1, // Tampilkan tepat setiap spot
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index < 0 || index >= trend.points.length) {
                              return const SizedBox();
                            }

                            try {
                              final dt = DateTime.parse(
                                trend.points[index].timestamp,
                              ).toLocal();
                              final h = dt.hour.toString().padLeft(2, '0');
                              final m = dt.minute.toString().padLeft(2, '0');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '$h.$m',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                              );
                            } catch (e) {
                              return const SizedBox();
                            }
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
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
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
                          color: const Color(
                            0xFF613EEA,
                          ).withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(RiskPrediction risk, TrendPrediction? trend) {
    final isHigh = risk.riskLevel.toLowerCase() == 'tinggi' || risk.probDiabetes >= 60.0;
    final isMedium = risk.riskLevel.toLowerCase() == 'sedang' ||
        (risk.probDiabetes >= 30.0 && risk.probDiabetes < 60.0);

    final Color c = isHigh
        ? const Color(0xFFEF4444) // Merah
        : (isMedium ? const Color(0xFFF59E0B) : const Color(0xFF10B981)); // Oranye : Hijau

    final String statusBadge = isHigh
        ? 'Risiko Tinggi'
        : (isMedium ? 'Risiko Sedang' : 'Risiko Rendah');

    final String statusTitle = isHigh
        ? 'Perlu Perhatian Medis'
        : (isMedium ? 'Waspada Risiko Glukosa' : 'Kondisi Metabolisme Baik');

    final String statusSubtitle = isHigh
        ? 'Terdeteksi indikasi kuat potensi diabetes'
        : (isMedium
            ? 'Terdapat indikasi kenaikan risiko gula darah'
            : 'Profil kesehatan & kadar gula dalam rentang aman');

    final String actionRecommendation = risk.recommendation ??
        (isHigh
            ? 'Disarankan untuk berkonsultasi dengan dokter untuk evaluasi lebih lanjut serta membatasi konsumsi gula berlebih.'
            : (isMedium
                ? 'Disarankan menjaga pola makan seimbang, rutin berolahraga, dan mengurangi konsumsi minuman/makanan manis.'
                : 'Pertahankan gaya hidup sehat, aktif berolahraga, dan lakukan pemantauan gula darah secara berkala.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Kartu Utama Analisis Risiko (Bersih & Fokus pada Pasien)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: c.withValues(alpha: 0.2), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Status & Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isHigh
                          ? Icons.warning_amber_rounded
                          : (isMedium ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded),
                      color: c,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusBadge,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: c,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Indikator Persentase Risiko
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tingkat Risiko Diabetes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '${risk.probDiabetes.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: c,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (risk.probDiabetes / 100.0).clamp(0.05, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(c),
                      ),
                    ),
                  ],
                ),
              ),

              // Faktor yang Perlu Diperhatikan (Bahasa Awam)
              if (risk.riskFactors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Faktor yang Terdeteksi:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  children: risk.riskFactors.map((factor) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.fiber_manual_record, size: 10, color: c),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              factor,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 14),

              // Saran / Rekomendasi Praktis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 18, color: c),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        actionRecommendation,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Saran Kesehatan Tambahan
        RecommendationCard(risk: risk, trend: trend, themeColor: c),
      ],
    );
  }

  Widget _buildPredictionGrid(TrendPrediction trend) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Prediksi (6 Jam Ke Depan)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: trend.points.length,
            itemBuilder: (context, index) {
              final point = trend.points[index];
              String timeLabel = '+${index + 1} Jam';
              try {
                final dt = DateTime.parse(point.timestamp).toLocal();
                final h = dt.hour.toString().padLeft(2, '0');
                final m = dt.minute.toString().padLeft(2, '0');
                timeLabel = '$h.$m';
              } catch (e) {
                // Ignore
              }

              Color numColor = const Color(0xFF10B981);
              if (point.glucose > 140) {
                numColor = const Color(0xFFFF5252);
              } else if (point.glucose < 70) {
                numColor = const Color(0xFFFFB74D);
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      point.glucose.round().toString(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: numColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'mg/dL',
                      style: TextStyle(fontSize: 10, color: Colors.black45),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
