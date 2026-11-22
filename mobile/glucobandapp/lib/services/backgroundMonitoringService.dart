import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/apiConstant.dart';
import 'espService.dart';
import 'secureStorageService.dart';

class BackgroundMonitoringService {
  static const MethodChannel _channel = MethodChannel('com.glucoband.app/system');
  static Future<bool> startService({
    int? patientId,
    String? token,
    String? backendUrl,
    String? espIp,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final secureStorage = SecureStorageService();
      final actualToken = token ?? await secureStorage.getToken();
      if (actualToken == null || actualToken.isEmpty) {
        debugPrint('[BackgroundMonitoringService] Token tidak ditemukan, service tidak dapat dimulai');
        return false;
      }

      int actualPatientId = patientId ?? 0;
      if (actualPatientId <= 0) {
        final userData = await secureStorage.getUserData();
        actualPatientId = int.tryParse(userData['id'] ?? '1') ?? 1;
      }

      final actualEspIp = espIp ?? await EspService.getDeviceIp();
      final actualBackendUrl = (backendUrl ?? ApiConstants.baseUrl).replaceAll(RegExp(r'/api/?$'), '');

      final res = await _channel.invokeMethod<bool>('startMonitoringService', {
        'patientId': actualPatientId,
        'token': actualToken,
        'backendUrl': actualBackendUrl,
        'espIp': actualEspIp,
      });

      debugPrint('[BackgroundMonitoringService] startService result: $res');
      return res ?? false;
    } catch (e) {
      debugPrint('[BackgroundMonitoringService] startService error: $e');
      return false;
    }
  }

  static Future<bool> stopService() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('stopMonitoringService');
      debugPrint('[BackgroundMonitoringService] stopService result: $res');
      return res ?? false;
    } catch (e) {
      debugPrint('[BackgroundMonitoringService] stopService error: $e');
      return false;
    }
  }

  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isMonitoringServiceRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Memperbarui parameter tanpa merestart service dari awal
  static Future<bool> updateConfig({
    int? patientId,
    String? token,
    String? backendUrl,
    String? espIp,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final Map<String, dynamic> args = {};
      if (patientId != null) args['patientId'] = patientId;
      if (token != null) args['token'] = token;
      if (backendUrl != null) args['backendUrl'] = backendUrl;
      if (espIp != null) args['espIp'] = espIp;

      final res = await _channel.invokeMethod<bool>('updateMonitoringConfig', args);
      return res ?? false;
    } catch (e) {
      debugPrint('[BackgroundMonitoringService] updateConfig error: $e');
      return false;
    }
  }
}
