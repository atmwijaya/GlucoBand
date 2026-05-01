import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/apiService.dart';
import '../../data/models/userModel.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Login – password plain text dikirim ke backend
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      _token = response.data['token'];
      _user = UserModel.fromJson(response.data['user']);

      // Simpan token & user secara lokal
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user_name', _user!.name);
      await prefs.setString('user_email', _user!.email);
      await prefs.setString('user_role', _user!.role);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Login gagal. Periksa email & password Anda.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register pasien baru
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
      await _apiService.register(
        name: name,
        email: email,
        password: password,
        gender: gender,
        age: age,
        weight: weight,
        height: height,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('409')) {
        _errorMessage = 'Email sudah terdaftar.';
      } else {
        _errorMessage = 'Pendaftaran gagal. Silakan coba lagi.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout – hapus data lokal & token
  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  /// Cek apakah user sudah login sebelumnya (dari penyimpanan lokal)
  Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      _user = UserModel(
        id: 0,
        name: prefs.getString('user_name') ?? '',
        email: prefs.getString('user_email') ?? '',
        role: prefs.getString('user_role') ?? 'pasien',
      );
      notifyListeners();
      return true;
    }
    return false;
  }
}