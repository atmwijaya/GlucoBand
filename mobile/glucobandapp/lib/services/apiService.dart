import 'package:dio/dio.dart';
import '../core/constants/apiConstant.dart';

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ));

  Future<Response> login(String email, String password) {
    return _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> register({
    required String name,
    required String email,
    required String password,
    String? gender,
    int? age,
    double? weight,
    double? height,
  }) {
    return _dio.post(ApiConstants.register, data: {
      'name': name,
      'email': email,
      'password': password,
      'gender': gender,
      'age': age,
      'weight_kg': weight,
      'height_cm': height,
    });
  }
}