class MeasurementModel {
  final int? id;
  final int? patientId;
  final String? patientName;
  final double glucoseEstimated;
  final String status;
  final int ppgHeartRate;
  final int ppgSpo2;
  final double skinTempCelsius;
  final DateTime createdAt;

  MeasurementModel({
    this.id,
    this.patientId,
    this.patientName,
    required this.glucoseEstimated,
    required this.status,
    required this.ppgHeartRate,
    required this.ppgSpo2,
    required this.skinTempCelsius,
    required this.createdAt,
  });

  factory MeasurementModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at'].toString()).toLocal();
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return MeasurementModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      patientId: json['patient_id'] != null ? int.tryParse(json['patient_id'].toString()) : null,
      patientName: json['patient_name']?.toString(),
      glucoseEstimated: double.tryParse(json['glucose_estimated']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'normal',
      ppgHeartRate: int.tryParse(json['ppg_heart_rate']?.toString() ?? '0') ?? 0,
      ppgSpo2: int.tryParse(json['ppg_spo2']?.toString() ?? '98') ?? 98,
      skinTempCelsius: double.tryParse(json['skin_temp_celsius']?.toString() ?? '0') ?? 0.0,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'patient_name': patientName,
      'glucose_estimated': glucoseEstimated,
      'status': status,
      'ppg_heart_rate': ppgHeartRate,
      'ppg_spo2': ppgSpo2,
      'skin_temp_celsius': skinTempCelsius,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

