import 'package:flutter/foundation.dart';
import '../../services/predictionApi.dart';
import '../../data/models/predictionModel.dart';

class PredictionProvider extends ChangeNotifier {
  final PredictionApi _api = PredictionApi();

  RiskPrediction? _riskResult;
  TrendPrediction? _trendResult;
  String? _error;
  bool _loading = false;

  RiskPrediction? get riskResult => _riskResult;
  TrendPrediction? get trendResult => _trendResult;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> fetchRisk(Map<String, dynamic> data, String token) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _api.predictRisk(data, token);
      if (raw is Map<String, dynamic>) {
        if (raw.containsKey('error')) {
          _error = raw['error'];
        } else {
          _riskResult = RiskPrediction.fromJson(raw);
        }
      }
    } catch (e) {
      _error = 'Gagal menghubungi server';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchTrend(List<double> history, int horizon, String token) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _api.predictTrend(history, horizon, token);
      if (raw is List) {
        if (raw.isEmpty) {
          _trendResult = null;
        } else if (raw.first is Map && (raw.first as Map).containsKey('error')) {
          _error = raw.first['error'];
        } else {
          // List of trend points
          final points = raw.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>)).toList();
          _trendResult = TrendPrediction(
            points: points,
            horizonHours: horizon,
            modelVersion: 'lstm_v1',
          );
        }
      }
    } catch (e) {
      _error = 'Gagal memuat tren';
    }
    _loading = false;
    notifyListeners();
}
}