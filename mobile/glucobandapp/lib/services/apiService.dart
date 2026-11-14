import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/constants/apiConstant.dart';
import '../app.dart';
import '../presentation/pages/loginPage.dart';
import 'secureStorageService.dart';

class ApiService {
  final Dio _dio;
  final SecureStorageService _secureStorage = SecureStorageService();
  bool _isRefreshing = false;

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
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
            final isAuthEndpoint =
                e.requestOptions.path.contains(ApiConstants.login) ||
                e.requestOptions.path.contains(ApiConstants.refresh);

            // Jika error 401 terjadi bukan pada endpoint login/refresh, coba perbarui token dengan Refresh Token (30 hari)
            if (!isAuthEndpoint && !_isRefreshing) {
              _isRefreshing = true;
              try {
                final newAccessToken = await refreshAccessToken();
                if (newAccessToken != null && newAccessToken.isNotEmpty) {
                  _isRefreshing = false;
                  // Ulangi kembali request asli dengan token baru
                  e.requestOptions.headers['Authorization'] =
                      'Bearer $newAccessToken';
                  final cloneReq = await _dio.fetch(e.requestOptions);
                  return handler.resolve(cloneReq);
                }
              } catch (refreshErr) {
                debugPrint(
                  '[ApiService] Gagal auto-refresh token: $refreshErr',
                );
              } finally {
                _isRefreshing = false;
              }
            }

            // Jika refresh token juga gagal atau sudah kedaluwarsa 30 hari, barulah bersihkan sesi & ke LoginPage
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
      ),
    );
  }

  /// Memperbarui Access Token menggunakan Refresh Token yang berlaku 30 hari
  Future<String?> refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }

      // Gunakan instance Dio terpisah agar tidak memicu interceptor rekursif
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $refreshToken',
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await refreshDio.post(ApiConstants.refresh);
      if (response.statusCode == 200 && response.data != null) {
        final newAccessToken =
            response.data['access_token'] ?? response.data['token'];
        if (newAccessToken != null) {
          await _secureStorage.saveToken(newAccessToken.toString());
          return newAccessToken.toString();
        }
      }
    } catch (e) {
      debugPrint('[ApiService] refreshAccessToken error: $e');
    }
    return null;
  }

  // ==================== AUTH METHODS ====================
  Future<Response> login(String email, String password) {
    return _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
  }

  Future<Response> register(Map<String, dynamic> data) {
    return _dio.post(ApiConstants.register, data: data);
  }

  // ==================== GENERAL METHODS ====================
  Future<Response> get(String path) => _dio.get(path);
  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);
  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);
}
