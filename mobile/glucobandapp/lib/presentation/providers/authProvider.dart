import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/apiService.dart';
import '../../services/secureStorageService.dart';
import '../../data/models/userModel.dart';
import '../../core/utils/jwtHelper.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      
      _token = response.data['access_token'] ?? response.data['token'];
      final refreshToken = response.data['refresh_token'];
      _user = UserModel.fromJson(response.data['user']);

      await _secureStorage.saveToken(_token!);
      if (refreshToken != null) {
        await _secureStorage.saveRefreshToken(refreshToken);
      }
      await _secureStorage.saveUserData(
        id: _user!.id,
        name: _user!.name,
        email: _user!.email,
        role: _user!.role,
      );

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login exception: $e');
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && (data['msg'] != null || data['message'] != null)) {
          _errorMessage = data['msg'] ?? data['message'];
        } else {
          _errorMessage = 'Login gagal. Periksa email & password Anda.';
        }
      } else {
        _errorMessage = 'Login gagal. Periksa koneksi internet Anda.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? gender,
    int? age,
    double? weight,
    double? height,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {
        'name': name,
        'email': email,
        'password': password,
        'gender': gender,
        'age': age,
        'weight_kg': weight,
        'height_cm': height,
      };

      await _apiService.register(data);

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login exception: $e');
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && (data['msg'] != null || data['message'] != null)) {
          _errorMessage = data['msg'] ?? data['message'];
        } else if (e.response?.statusCode == 409) {
          _errorMessage = 'Email sudah terdaftar.';
        } else {
          _errorMessage = 'Pendaftaran gagal. Silakan coba lagi.';
        }
      } else if (e.toString().contains('409') || e.toString().contains('already')) {
        _errorMessage = 'Email sudah terdaftar.';
      } else {
        _errorMessage = 'Pendaftaran gagal. Silakan coba lagi.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    await _secureStorage.clearAll();
    _isInitialized = true;
    notifyListeners();
  }

  /// Cek status login saat aplikasi dibuka (membaca dari Keystore)
  Future<bool> checkLoginStatus() async {
    try {
      _token = await _secureStorage.getToken();
      final refreshToken = await _secureStorage.getRefreshToken();
      final userData = await _secureStorage.getUserData();

      // Jika ada token atau refresh token tersimpan
      if ((_token != null && _token!.isNotEmpty) || (refreshToken != null && refreshToken.isNotEmpty)) {
        // Cek apakah access token sudah kedaluwarsa tapi refresh token masih ada
        if (_token != null && JwtHelper.isExpired(_token!) && refreshToken != null && refreshToken.isNotEmpty) {
          // Jika refresh token juga sudah kedaluwarsa (30 hari habis), logout bersih
          if (JwtHelper.isExpired(refreshToken)) {
            await logout();
            _isInitialized = true;
            notifyListeners();
            return false;
          }

          // Access token kedaluwarsa, otomatis perbarui via refresh token
          final newToken = await _apiService.refreshAccessToken();
          if (newToken != null && newToken.isNotEmpty) {
            _token = newToken;
          }
        }

        final idVal = int.tryParse(userData['id'] ?? '0') ?? 0;
        _user = UserModel(
          id: idVal,
          name: userData['name'] ?? '',
          email: userData['email'] ?? '',
          role: userData['role'] ?? 'pasien',
        );

        _isInitialized = true;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthProvider] checkLoginStatus error: $e');
    }

    _isInitialized = true;
    notifyListeners();
    return false;
  }
}
