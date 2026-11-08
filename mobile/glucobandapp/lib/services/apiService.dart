import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/constants/apiConstant.dart';
import '../app.dart';
import '../presentation/pages/loginPage.dart';
import 'secureStorageService.dart';

class ApiService {
  final Dio _dio;
  final SecureStorageService _secureStorage = SecureStorageService();

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          // Ambil token secara aman dari Android Keystore / iOS Keychain
          final token = await _secureStorage.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Jika token ditolak / kedaluwarsa, bersihkan sesi dari Keystore
          await _secureStorage.clearAll();

          if (navigatorKey.currentContext != null) {
            Navigator.pushAndRemoveUntil(
              navigatorKey.currentContext!,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          }
        }
        return handler.next(e);
      },
    ));
  }

  // ==================== AUTH METHODS ====================
  Future<Response> login(String email, String password) {
    return _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> register(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.register, data: data);
  }

  // ==================== GENERAL METHODS ====================
  Future<Response> get(String path) => _dio.get(path);
  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
}
