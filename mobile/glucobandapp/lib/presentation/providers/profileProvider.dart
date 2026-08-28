import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/apiService.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/profile');

      if (response.statusCode == 200) {
        _profileData = Map<String, dynamic>.from(response.data);
        print('✅ Profile berhasil di-load');
      } else {
        _errorMessage = 'Gagal memuat profil (${response.statusCode})';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _errorMessage = 'Sesi login telah berakhir. Silakan login kembali.';
      } else {
        _errorMessage = e.response?.data?['message'] ?? 'Gagal terhubung ke server';
      }
      debugPrint('Error fetching profile: ${e.message}');
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak diketahui';
      debugPrint('Unexpected error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.put('/profile', data: data);

      if (response.statusCode == 200) {
        await fetchProfile(); // Refresh data setelah update
        return true;
      } else {
        _errorMessage = 'Gagal memperbarui profil';
        return false;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _errorMessage = 'Sesi login telah berakhir. Silakan login kembali.';
      } else {
        _errorMessage = e.response?.data?['message'] ?? 'Gagal memperbarui profil';
      }
      return false;
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan saat memperbarui profil';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearProfile() {
    _profileData = null;
    _errorMessage = null;
    notifyListeners();
  }
}
