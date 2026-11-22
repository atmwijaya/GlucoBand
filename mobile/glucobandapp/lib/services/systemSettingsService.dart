import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'apiService.dart';

class SystemSettingsService {
  static const MethodChannel _channel = MethodChannel('com.glucoband.app/system');
  static final ApiService _apiService = ApiService();

  /// Memeriksa apakah notifikasi aplikasi diizinkan oleh sistem operasi Android
  static Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Membuka halaman pengaturan Notifikasi aplikasi langsung pada pengaturan sistem HP
  static Future<bool> openNotificationSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openNotificationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa apakah optimasi baterai untuk aplikasi ini sudah diabaikan (Unrestricted / Bebas Latar Belakang)
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Meminta sistem HP untuk mengecualikan aplikasi dari penghemat daya baterai (agar background service tetap berjalan lancar)
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Membuka halaman Informasi Aplikasi (App Info) di Pengaturan Android
  static Future<bool> openAppDetailsSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openAppDetailsSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Membuka panel pengaturan WiFi Android
  static Future<bool> openWifiSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('openWifiSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mengubah kata sandi pengguna melalui API backend
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        '/auth/change-password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['msg'] ?? 'Kata sandi berhasil diperbarui.'};
      }
      return {'success': false, 'message': response.data['msg'] ?? 'Gagal memperbarui kata sandi.'};
    } on DioException catch (e) {
      final msg = e.response?.data?['msg'] ?? 'Terjadi kesalahan jaringan atau kata sandi lama salah.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem: $e'};
    }
  }
}
