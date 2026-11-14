class RiskPrediction {
  final String riskLevel;
  final double riskScore;
  final int prediction;
  final String modelVersion;
  final double probDiabetes;
  final double probNonDiabetes;
  final String className;
  final String? badge;
  final String? recommendation;
  final List<String> riskFactors;

  RiskPrediction({
    required this.riskLevel,
    required this.riskScore,
    required this.prediction,
    required this.modelVersion,
    this.probDiabetes = 0.0,
    this.probNonDiabetes = 0.0,
    this.className = '',
    this.badge,
    this.recommendation,
    this.riskFactors = const [],
  });

  factory RiskPrediction.fromJson(Map<String, dynamic> json) {
    final score = (json['risk_score'] ?? 0).toDouble();
    final pDia = json['prob_diabetes'] != null
        ? (json['prob_diabetes'] as num).toDouble()
        : (score * 100);
    final pNon = json['prob_non_diabetes'] != null
        ? (json['prob_non_diabetes'] as num).toDouble()
        : (100.0 - pDia).clamp(0.0, 100.0);

    return RiskPrediction(
      riskLevel: json['risk_level'] ?? 'Tidak diketahui',
      riskScore: score,
      prediction: json['prediction'] ?? (pDia >= 50.0 ? 1 : 0),
      modelVersion: json['model_version'] ?? json['model version'] ?? 'Random Forest Biner v2.0',
      probDiabetes: pDia,
      probNonDiabetes: pNon,
      className: json['class_name'] ?? (json['prediction'] == 1 ? 'Diabetes' : 'Non-diabetes (Normal)'),
      badge: json['badge'],
      recommendation: json['recommendation'],
      riskFactors: (json['risk_factors'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
