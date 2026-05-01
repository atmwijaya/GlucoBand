import 'package:dio/dio.dart';
import '../../../core/constants/apiConstant.dart';

class FaqRemoteDataSource {
  final Dio _dio;

  FaqRemoteDataSource(this._dio);

  Future<List<Map<String, dynamic>>> getFaqs() async {
    final response = await _dio.get(ApiConstants.faq);
    return List<Map<String, dynamic>>.from(response.data);
  }
}