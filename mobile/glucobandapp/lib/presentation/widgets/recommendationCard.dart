import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/models/predictionModel.dart';

class RecommendationCard extends StatefulWidget {
  final RiskPrediction risk;
  final TrendPrediction? trend;
  final Color themeColor;

  const RecommendationCard({
    super.key,
    required this.risk,
    required this.trend,
    required this.themeColor,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  String _aiAdvice = '';
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchAIAdvice();
  }

  Future<void> _fetchAIAdvice() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _aiAdvice = _getFallbackAdvice();
          _errorMessage =
              'API Key belum dikonfigurasi, menampilkan saran default.';
        });
      }
      return;
    }

    try {
      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);

      final riskLevel = widget.risk.riskLevel;
      double rfConfidence = widget.risk.riskScore >= 0.5
          ? (widget.risk.riskScore * 100)
          : ((1.0 - widget.risk.riskScore) * 100);

      String trendData = 'Data tren tidak tersedia.';
      if (widget.trend != null && widget.trend!.points.isNotEmpty) {
        trendData = widget.trend!.points
            .take(6)
            .map((e) => '${e.glucose.toStringAsFixed(0)} mg/dL')
            .join(', ');
      }

      final prompt =
          '''
Kamu adalah asisten kesehatan AI profesional dan empatik di aplikasi Glucoband.
Pengguna saat ini memiliki tingkat risiko diabetes "$riskLevel" dengan skor keyakinan model sebesar ${rfConfidence.toStringAsFixed(1)}%.
Berikut adalah prediksi glukosa darahnya untuk beberapa jam ke depan (setiap 1 jam): [$trendData].

Tugasmu:
Berikan saran kesehatan yang dipersonalisasi, ringkas, ramah, dan solutif dalam maksimal 3 kalimat berbahasa Indonesia.
Fokus pada tindakan preventif atau langkah yang bisa mereka ambil segera berdasarkan tren prediksi tersebut. Jangan menakut-nakuti, tapi berikan saran yang menenangkan dan berguna.
''';

      final response = await model.generateContent([Content.text(prompt)]);

      if (mounted) {
        setState(() {
          _aiAdvice = response.text ?? _getFallbackAdvice();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error Gemini API: \$e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengambil saran AI: \$e';
          _aiAdvice = _getFallbackAdvice();
          _isLoading = false;
        });
      }
    }
  }

  String _getFallbackAdvice() {
    final isHigh = widget.risk.riskLevel == 'Tinggi';
    final isMedium = widget.risk.riskLevel == 'Sedang';
    if (isHigh) {
      return 'Segera konsultasikan dengan dokter. Sangat disarankan untuk membatasi konsumsi gula berlebih, mengelola pola makan dengan ketat, dan memantau glukosa setiap hari.';
    } else if (isMedium) {
      return 'Mulai kurangi asupan karbohidrat dan tingkatkan aktivitas fisik Anda. Dianjurkan untuk berkonsultasi dengan dokter untuk pencegahan lebih awal.';
    } else {
      return 'Gaya hidup Anda sudah cukup sehat! Lanjutkan olahraga rutin 30 menit sehari, jaga pola makan gizi seimbang, dan pastikan istirahat cukup.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.themeColor.withValues(alpha: 0.1),
            widget.themeColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: widget.themeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Saran AI Kesehatan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: widget.themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.themeColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI sedang menyusun saran untukmu...',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            )
          else
            Text(
              _aiAdvice,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
