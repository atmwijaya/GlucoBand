import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../core/constants/apiConstant.dart';
import '../app.dart';
import '../presentation/pages/loginPage.dart';

class ApiService {
  final Dio _dio;

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
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          print('🔑 [REQUEST] ${options.method} ${options.path}');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            print('✅ Token berhasil ditambahkan');
          } else {
            print('⚠️ Token tidak ditemukan!');
          }
        } catch (e) {
          print('Warning: Gagal mengambil token: $e');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ [RESPONSE ${response.statusCode}] ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('❌ [ERROR ${e.response?.statusCode}] ${e.requestOptions.path}');
        if (e.response?.statusCode == 401) {
          print('🚨 TOKEN INVALID / EXPIRED');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

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
