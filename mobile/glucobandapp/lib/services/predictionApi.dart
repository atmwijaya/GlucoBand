import 'package:dio/dio.dart';
import '../core/constants/apiConstant.dart';

class PredictionApi {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    headers: {'Content-Type': 'application/json'},
  ));

  Future<Map<String, dynamic>> predictRisk(Map<String, dynamic> data, String token) async {
    try {
      final response = await _dio.post(
        '/predict/risk',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map
          ? (e.response?.data['error'] ?? e.response?.data['message'] ?? e.response?.data['msg'])
          : null;
      throw Exception(serverMsg ?? 'Server backend mengalami kendala (Error ${e.response?.statusCode ?? 500})');
    }
  }

  Future<List<Map<String, dynamic>>> predictTrend(Map<String, dynamic> data, int horizon, String token) async {
    final Map<String, dynamic> requestData = Map.from(data);
    requestData['horizon_hours'] = horizon;
    try {
      final response = await _dio.post(
        '/predict/trend',
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data.containsKey('error')) {
        throw Exception(response.data['error']);
      }
      return [];
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map ? e.response?.data['error'] ?? e.response?.data['message'] : null;
      throw Exception(serverMsg ?? e.message ?? 'Gagal memproses prediksi tren di server');
    }
  }

  Future<List<Map<String, dynamic>>> getTrendHistory(int patientId, String token) async {
    final response = await _dio.get(
      '/predictions/trend/$patientId/history',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> deleteTrendHistory(int predictionId, String token) async {
    await _dio.delete(
      '/predictions/trend/$predictionId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
