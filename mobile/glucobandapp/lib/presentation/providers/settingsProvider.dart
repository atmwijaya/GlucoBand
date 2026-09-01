import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/apiService.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  String? _emergencyContact;
  bool _isLoading = false;
  String? _errorMessage;

  String? get emergencyContact => _emergencyContact;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchEmergencyContact() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/settings/emergency_contact');

      if (response.statusCode == 200) {
        _emergencyContact = response.data['setting_value'];
      } else {
        _errorMessage = 'Gagal memuat kontak darurat (${response.statusCode})';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
         // Default if not set in DB
         _emergencyContact = '119';
      } else {
        _errorMessage = e.response?.data?['msg'] ?? 'Gagal terhubung ke server';
      }
      debugPrint('Error fetching settings: ${e.message}');
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak diketahui';
      debugPrint('Unexpected error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
