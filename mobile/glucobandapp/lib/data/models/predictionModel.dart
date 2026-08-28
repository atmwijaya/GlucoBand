class RiskPrediction {
  final String riskLevel;
  final double riskScore;
  final int prediction;
  final String modelVersion;

  RiskPrediction({
    required this.riskLevel,
    required this.riskScore,
    required this.prediction,
    required this.modelVersion,
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    return RiskPrediction(
      riskLevel: json['risk_level'] ?? 'Tidak diketahui',
      riskScore: (json['risk_score'] ?? 0).toDouble(),
      prediction: json['prediction'] ?? 0,
      modelVersion: json['model_version'] ?? 'rf_v1',
    );
  }
}

class TrendPoint {
  final String timestamp;
  final double glucose;

  TrendPoint({required this.timestamp, required this.glucose});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      timestamp: json['timestamp'] ?? '',
      glucose: (json['glucose'] ?? 0).toDouble(),
    );
  }
}

class TrendPrediction {
  final List<TrendPoint> points;
  final int horizonHours;
  final String modelVersion;

  TrendPrediction({
    required this.points,
    required this.horizonHours,
    required this.modelVersion,
  });

  factory TrendPrediction.fromJson(Map<String, dynamic> json) {
    return TrendPrediction(
      horizonHours: 6,
      modelVersion: json['model_version'] ?? 'lstm_v1',
      points: (json['predictions'] as List<dynamic>?)
              ?.map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
