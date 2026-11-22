import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/apiService.dart';
import '../../services/secureStorageService.dart';
import '../../services/backgroundMonitoringService.dart';
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

  int _lockoutSeconds = 0;
  Timer? _countdownTimer;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get lockoutSeconds => _lockoutSeconds;
  bool get isLockedOut => _lockoutSeconds > 0;

  /// Memeriksa apakah ada lockout aktif dari sesi sebelumnya (tersimpan di SharedPreferences)
  Future<void> checkExistingLockout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutUntilMs = prefs.getInt('login_lockout_until') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (lockoutUntilMs > nowMs) {
        final remainingSec = ((lockoutUntilMs - nowMs) / 1000).ceil();
        startLockoutCountdown(remainingSec);
      } else if (lockoutUntilMs > 0) {
        await prefs.remove('login_lockout_until');
      }
    } catch (e) {
      debugPrint('[AuthProvider] checkExistingLockout error: $e');
    }
  }

  /// Memulai timer hitungan mundur lockout
  void startLockoutCountdown(int seconds) {
    _countdownTimer?.cancel();
    _lockoutSeconds = seconds;
    _errorMessage = null;
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      final lockoutUntilMs = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
      prefs.setInt('login_lockout_until', lockoutUntilMs);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds > 1) {
        _lockoutSeconds--;
        notifyListeners();
      } else {
        _lockoutSeconds = 0;
        _errorMessage = null; // Bersihkan pesan error agar tidak tertinggal setelah hitungan selesai
        timer.cancel();
        _countdownTimer = null;
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('login_lockout_until');
        });
        notifyListeners();
      }
    });
  }

  Future<bool> login(String email, String password) async {
    // Jika sedang terkunci, batalkan pemanggilan ke server
    if (isLockedOut) {
      return false;
    }

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

      // Jalankan foreground monitoring service agar pengukuran tetap berjalan di background
      BackgroundMonitoringService.startService(
        patientId: _user!.id,
        token: _token,
      );

      // Reset lockout jika login berhasil
      _countdownTimer?.cancel();
      _lockoutSeconds = 0;
      SharedPreferences.getInstance().then((prefs) => prefs.remove('login_lockout_until'));

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login exception: $e');
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (statusCode == 429) {
          int retryAfter = 60;
          if (data is Map && data['retry_after_seconds'] != null) {
            retryAfter = int.tryParse(data['retry_after_seconds'].toString()) ?? 60;
          }
          final serverMsg = (data is Map) ? (data['msg'] ?? data['message']) : null;
          _errorMessage = serverMsg?.toString() ?? 'Batas percobaan login tercapai. Akun diblokir sementara.';
          startLockoutCountdown(retryAfter);
        } else if (data is Map && (data['msg'] != null || data['message'] != null)) {
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
    await BackgroundMonitoringService.stopService();
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

        // Pastikan background monitoring service aktif jika pengguna sudah login
        BackgroundMonitoringService.startService(
          patientId: _user!.id,
          token: _token,
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

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
