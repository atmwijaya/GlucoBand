import 'package:dio/dio.dart';
import '../core/constants/apiConstant.dart';

class PredictionApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    headers: {'Content-Type': 'application/json'},
  ));

  Future<Map<String, dynamic>> predictRisk(Map<String, dynamic> data, String token) async {
    final response = await _dio.post(
      '/predict/risk',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  Future<List<Map<String, dynamic>>> predictTrend(List<double> history, int horizon, String token) async {
    final response = await _dio.post(
      '/predict/trend',
      data: {'glucose_history': history, 'horizon_hours': horizon},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return List<Map<String, dynamic>>.from(response.data);
  }
}