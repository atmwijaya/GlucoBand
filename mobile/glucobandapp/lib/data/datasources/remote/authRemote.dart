import 'package:dio/dio.dart';
import '../../../core/constants/apiConstant.dart';

class AuthRemoteDataSource {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  Future<Response> login(String email, String password) {
    return _dio.post(ApiConstants.login, data: {'email': email, 'password': password});
  }
}