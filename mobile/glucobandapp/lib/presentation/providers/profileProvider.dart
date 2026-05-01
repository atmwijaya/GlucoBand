import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/apiConstant.dart';

class ProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProfile(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    try {
      final response = await dio.get('/profile');
      if (response.statusCode == 200) {
        _profileData = Map<String, dynamic>.from(response.data);
      } else {
        _errorMessage = 'Gagal memuat profil (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Gagal terhubung ke server';
      debugPrint('Error fetching profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(String token, Map<String, dynamic> data) async {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    try {
      final response = await dio.put('/profile', data: data);
      if (response.statusCode == 200) {
        await fetchProfile(token);
        return true;
      }
      _errorMessage = 'Gagal memperbarui profil';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal terhubung ke server';
      notifyListeners();
      return false;
    }
  }
}