import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/apiService.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  String? _emergencyContact;
  String? _doctorName;
  String? _doctorSpecialization;
  bool _isDoctorAssigned = false;
  bool _isLoading = false;
  String? _errorMessage;

  String? get emergencyContact => _emergencyContact;
  String? get doctorName => _doctorName;
  String? get doctorSpecialization => _doctorSpecialization;
  bool get isDoctorAssigned => _isDoctorAssigned;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchEmergencyContact() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Endpoint /settings/emergency_contact secara otomatis mengidentifikasi
      // token pasien yang tersimpan di Keystore dan mengembalikan nomor kontak
      // tenaga medis yang ditugaskan kepada pasien tersebut oleh website.
      final response = await _apiService.get('/settings/emergency_contact');

      if (response.statusCode == 200) {
        final data = response.data;
        _emergencyContact = data['setting_value'] ?? data['emergency_contact'] ?? '119';
        _doctorName = data['tenaga_medis_name'] ?? data['doctor_name'];
        _doctorSpecialization = data['specialization'];
        _isDoctorAssigned = data['assigned'] == true;
      } else {
        _errorMessage = 'Gagal memuat kontak darurat (${response.statusCode})';
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback jika belum diatur di database
        _emergencyContact = '119';
        _doctorName = 'Layanan Darurat Medis';
        _doctorSpecialization = 'Pusat Bantuan 119';
        _isDoctorAssigned = false;
      } else {
        _errorMessage = e.response?.data?['msg'] ?? 'Gagal terhubung ke server';
      }
      debugPrint('Error fetching emergency contact settings: ${e.message}');
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan yang tidak diketahui';
      debugPrint('Unexpected error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
