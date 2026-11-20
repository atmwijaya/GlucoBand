import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/measurementModel.dart';
import '../../core/utils/glucoseStatus.dart';

/// Model representasi satu titik data pada grafik glukosa ala saham
class GlucoseStockSpot {
  final int index;
  final double x;
  final double y;
  final DateTime timestamp;
  final bool isActual;
  final String label;

  GlucoseStockSpot({
    required this.index,
    required this.x,
    required this.y,
    required this.timestamp,
    this.isActual = false,
    required this.label,
  });
}

/// Widget Grafik Glukosa Realtime ala Bursa Saham (Stock Chart Style)
/// Mendukung skala 24 Jam (1 Hari), 48 Jam (2 Hari), dan 72 Jam (3 Hari) dengan interval 5 menit.
class GlucoseStockChart extends StatefulWidget {
  final List<MeasurementModel> measurements;
  final double latestGlucose;
  final String timeFilter; // '1 Hari', '2 Hari', '3 Hari'
  final ValueChanged<String> onFilterChanged;
  final Color? statusColor;

  const GlucoseStockChart({
    super.key,
    required this.measurements,
    required this.latestGlucose,
    required this.timeFilter,
    required this.onFilterChanged,
    this.statusColor,
  });

  @override
  State<GlucoseStockChart> createState() => _GlucoseStockChartState();
}

class _GlucoseStockChartState extends State<GlucoseStockChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.statusColor ?? const Color(0xFF10B981);

    // 1. Tentukan durasi jam & interval berdasarkan filter yang dipilih
    int totalHours = 24;
    int intervalMinutes = 5;
    if (widget.timeFilter == '2 Hari' || widget.timeFilter == '48 Jam') {
      totalHours = 48;
      intervalMinutes = 10; // 288 titik untuk mempertahankan kepadatan visual layar
    } else if (widget.timeFilter == '3 Hari' || widget.timeFilter == '72 Jam') {
      totalHours = 72;
      intervalMinutes = 15; // 288 titik untuk skala 3 hari
    } else {
      // Default: 1 Hari (24 Jam) dengan interval 5 menit murni (288 titik)
      totalHours = 24;
      intervalMinutes = 5;
    }

    final totalSteps = (totalHours * 60) ~/ intervalMinutes;
    final now = DateTime.now();
    final startTime = now.subtract(Duration(hours: totalHours));

    // 2. Kumpulkan & urutkan pengukuran riil dalam rentang waktu yang dipilih
    final actualList = widget.measurements
        .where((m) => m.createdAt.isAfter(startTime) && m.createdAt.isBefore(now.add(const Duration(minutes: 5))))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 3. Bangun titik-titik data terinterpolasi ala saham (Continuous Glucose Monitoring Curve)
    final List<GlucoseStockSpot> stockSpots = [];
    final List<FlSpot> flSpots = [];

    double highestVal = widget.latestGlucose > 0 ? widget.latestGlucose : 120.0;
    double lowestVal = widget.latestGlucose > 0 ? widget.latestGlucose : 80.0;

    final double baselineReference = widget.latestGlucose > 0 ? widget.latestGlucose : 100.0;

    for (int i = 0; i <= totalSteps; i++) {
      final tCurr = startTime.add(Duration(minutes: i * intervalMinutes));

      // Cek apakah ada data aktual di dekat slot ini (toleransi interval / 2)
      MeasurementModel? actualMatch;
      for (final m in actualList) {
        final diffSec = (m.createdAt.difference(tCurr).inSeconds).abs();
        if (diffSec <= (intervalMinutes * 60 ~/ 2) + 30) {
          actualMatch = m;
          break;
        }
      }

      double glucoseValue;
      bool isActual = false;

      if (actualMatch != null) {
        glucoseValue = actualMatch.glucoseEstimated;
        isActual = true;
      } else {
        // Cari titik data aktual sebelum dan sesudah slot waktu ini
        MeasurementModel? prevM;
        MeasurementModel? nextM;

        for (final m in actualList) {
          if (!m.createdAt.isAfter(tCurr)) {
            prevM = m;
          } else if (m.createdAt.isAfter(tCurr) && nextM == null) {
            nextM = m;
            break;
          }
        }

        if (prevM != null && nextM != null) {
          // Interpolasi Cosine Halus di antara dua data riil
          final totalSpan = nextM.createdAt.difference(prevM.createdAt).inSeconds;
          final elapsed = tCurr.difference(prevM.createdAt).inSeconds;
          final alpha = totalSpan > 0 ? (elapsed / totalSpan).clamp(0.0, 1.0) : 0.0;
          final w = (1.0 - math.cos(alpha * math.pi)) / 2.0;
          final base = prevM.glucoseEstimated + w * (nextM.glucoseEstimated - prevM.glucoseEstimated);

          // Micro-fluctuations fisiologis glukosa ala saham (mengecil ke 0 saat mendekati titik aktual)
          final noiseFactor = math.sin(alpha * math.pi);
          final noise = (math.sin(i * 0.28) * 1.5 + math.cos(i * 0.14) * 0.9) * noiseFactor;
          glucoseValue = base + noise;
        } else if (prevM != null) {
          // Melandai dari pengukuran riil terakhir menuju glukosa terkini / baseline normal
          final elapsedMin = tCurr.difference(prevM.createdAt).inMinutes;
          final decay = math.exp(-elapsedMin / 240.0); // Waktu peluruhan fisiologis 4 jam
          final target = widget.latestGlucose > 0 ? widget.latestGlucose : baselineReference;
          final base = target + (prevM.glucoseEstimated - target) * decay;
          final noise = math.sin(i * 0.28) * 1.4 + math.cos(i * 0.14) * 0.8;
          glucoseValue = base + noise;
        } else if (nextM != null) {
          // Melandai dari baseline menuju pengukuran riil pertama
          final remainingMin = nextM.createdAt.difference(tCurr).inMinutes;
          final decay = math.exp(-remainingMin / 240.0);
          final target = baselineReference;
          final base = target + (nextM.glucoseEstimated - target) * decay;
          final noise = math.sin(i * 0.28) * 1.4 + math.cos(i * 0.14) * 0.8;
          glucoseValue = base + noise;
        } else {
          // Fluktuasi ritme sirkadian diurnal manusia 24 jam alami
          final hourOfDay = tCurr.hour + (tCurr.minute / 60.0);
          final circadian = 5.5 * math.sin((hourOfDay - 8.0) * 2.0 * math.pi / 24.0);
          final noise = math.sin(i * 0.28) * 1.5 + math.cos(i * 0.14) * 0.9;
          glucoseValue = baselineReference + circadian + noise;
        }
      }

      // Pastikan titik terakhir (saat ini) tepat sesuai glukosa terkini jika tersedia
      if (i == totalSteps && widget.latestGlucose > 0) {
        glucoseValue = widget.latestGlucose;
        isActual = actualList.isNotEmpty && actualList.last.createdAt.difference(now).inMinutes.abs() <= 15;
      }

      glucoseValue = glucoseValue.clamp(40.0, 350.0);

      if (glucoseValue > highestVal) highestVal = glucoseValue;
      if (glucoseValue < lowestVal) lowestVal = glucoseValue;

      final spotObj = GlucoseStockSpot(
        index: i,
        x: i.toDouble(),
        y: glucoseValue,
        timestamp: tCurr,
        isActual: isActual,
        label: DateFormat('HH:mm').format(tCurr),
      );

      stockSpots.add(spotObj);
      flSpots.add(FlSpot(i.toDouble(), glucoseValue));
    }

    // Hitung ringkasan statistik ala pasar saham
    final initialVal = stockSpots.isNotEmpty ? stockSpots.first.y : baselineReference;
    final finalVal = stockSpots.isNotEmpty ? stockSpots.last.y : baselineReference;
    final changeVal = finalVal - initialVal;
    final changePercent = initialVal > 0 ? (changeVal / initialVal) * 100 : 0.0;
    final isTrendingUp = changeVal >= 0;

    // Hitung rata-rata glukosa dalam periode ini
    final avgVal = stockSpots.isNotEmpty
        ? stockSpots.fold<double>(0.0, (prev, s) => prev + s.y) / stockSpots.length
        : baselineReference;

    // Batas skala Y dengan ruang bernapas yang cukup
    final double minY = (lowestVal - 18.0).clamp(35.0, 300.0);
    final double maxY = (highestVal + 22.0).clamp(160.0, 420.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SELECTOR PILL RENTANG WAKTU (1 HARI, 2 HARI, 3 HARI) - RESPONSIVE
        Row(
          children: [
            Expanded(
              child: _buildPillButton(
                '1 Hari',
                '24 Jam',
                widget.timeFilter == '1 Hari' || widget.timeFilter == '24 Jam',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPillButton(
                '2 Hari',
                '48 Jam',
                widget.timeFilter == '2 Hari' || widget.timeFilter == '48 Jam',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPillButton(
                '3 Hari',
                '72 Jam',
                widget.timeFilter == '3 Hari' || widget.timeFilter == '72 Jam',
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. STOCK SUMMARY TOOLBAR (High, Low, Avg, Delta Fluktuasi ala Saham)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Delta Perubahan ala Saham
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        isTrendingUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 16,
                        color: isTrendingUp ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isTrendingUp ? '+' : ''}${changeVal.toStringAsFixed(1)} mg/dL (${changePercent.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isTrendingUp ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Statistik Ringkas Saham: High / Low / Avg
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  children: [
                    _buildStatTag('H', highestVal.toStringAsFixed(0), const Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    _buildStatTag('L', lowestVal.toStringAsFixed(0), const Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    _buildStatTag('Avg', avgVal.toStringAsFixed(0), const Color(0xFF613EEA)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. GRAFIK KONTINU INTERVAL 5 MENIT ALA SAHAM
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: totalSteps.toDouble(),
              minY: minY,
              maxY: maxY,
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  if (event is FlTapUpEvent || event is FlPanEndEvent) {
                    setState(() => _touchedIndex = null);
                  } else if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                    setState(() => _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex);
                  }
                },
                getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                  return spotIndexes.map((spotIndex) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: themeColor.withValues(alpha: 0.7),
                        strokeWidth: 1.5,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: themeColor,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tooltipMargin: 10,
                  tooltipRoundedRadius: 12,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final idx = barSpot.x.toInt();
                      if (idx < 0 || idx >= stockSpots.length) return null;
                      final spot = stockSpots[idx];
                      final val = spot.y;
                      final status = GlucoseStatusHelper.getLabel(val);
                      final timeStr = DateFormat('dd MMM, HH:mm').format(spot.timestamp);
                      final sourceText = spot.isActual ? 'HASIL UKUR GLUCOBAND' : 'PREDIKSI CGM 5 MENIT';

                      return LineTooltipItem(
                        '${val.toStringAsFixed(1)} mg/dL\n',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: '$timeStr • $status\n',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          TextSpan(
                            text: sourceText,
                            style: TextStyle(
                              color: spot.isActual ? const Color(0xFF34D399) : const Color(0xFF93C5FD),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  // Garis Ambang Batas Normal Atas (140 mg/dL)
                  HorizontalLine(
                    y: 140.0,
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    strokeWidth: 1.2,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                      ),
                      labelResolver: (_) => 'Target Max 140',
                    ),
                  ),
                  // Garis Ambang Batas Normal Bawah (70 mg/dL)
                  HorizontalLine(
                    y: 70.0,
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    strokeWidth: 1.2,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                      ),
                      labelResolver: (_) => 'Target Min 70',
                    ),
                  ),
                ],
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (totalSteps / 4).clamp(1.0, 300.0),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= stockSpots.length) {
                        return const SizedBox.shrink();
                      }
                      final t = stockSpots[idx].timestamp;
                      String text;
                      if (totalHours <= 24) {
                        text = DateFormat('HH:mm').format(t);
                      } else {
                        text = DateFormat('dd/MM HH:mm').format(t);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: flSpots,
                  isCurved: true,
                  curveSmoothness: 0.22,
                  color: themeColor,
                  barWidth: 2.8,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      final idx = spot.x.toInt();
                      if (idx >= 0 && idx < stockSpots.length) {
                        // Tampilkan dot hanya untuk titik aktual atau titik akhir terkini
                        return stockSpots[idx].isActual || idx == stockSpots.length - 1;
                      }
                      return false;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      final idx = spot.x.toInt();
                      final isActual = idx >= 0 && idx < stockSpots.length && stockSpots[idx].isActual;

                      return FlDotCirclePainter(
                        radius: isActual ? 4.5 : 3.5,
                        color: isActual ? Colors.white : themeColor,
                        strokeWidth: 2.5,
                        strokeColor: themeColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withValues(alpha: 0.28),
                        themeColor.withValues(alpha: 0.08),
                        themeColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Catatan Edukasi Mini Footer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColor, width: 2),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Titik Ukur GlucoBand',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Text(
              'Geser grafik untuk cek riwayat 5 menit',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPillButton(String filterKey, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onFilterChanged(filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF613EEA) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF613EEA).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$filterKey ($label)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildStatTag(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
