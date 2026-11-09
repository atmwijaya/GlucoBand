import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WifiConfigResult {
  final bool success;
  final bool wifiConnected;
  final String? newIp;
  final String? ssid;
  final String message;

  WifiConfigResult({
    required this.success,
    required this.wifiConnected,
    this.newIp,
    this.ssid,
    required this.message,
  });
}

class EspService {
  static const String _defaultIp = '192.168.4.1';
  static const String _prefKeyIp = 'esp_device_ip';
  static const MethodChannel _systemChannel = MethodChannel('com.glucoband.app/system');

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 2500),
      receiveTimeout: const Duration(milliseconds: 2500),
      sendTimeout: const Duration(milliseconds: 2500),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  /// Membuka halaman pengaturan WiFi smartphone secara instan
  static Future<bool> openSystemWifiSettings() async {
    try {
      final res = await _systemChannel.invokeMethod('openWifiSettings');
      if (res == true) return true;
    } catch (_) {}

    // Fallback URL Launcher untuk iOS / Android fallback
    try {
      final Uri uri = Platform.isIOS
          ? Uri.parse('App-Prefs:root=WIFI')
          : Uri.parse('package:android.settings.WIFI_SETTINGS');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Mendapatkan Alamat IP ESP32 dari penyimpanan lokal (Default: 192.168.4.1)
  static Future<String> getDeviceIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_prefKeyIp);
    if (ip == null || ip.trim().isEmpty) {
      return _defaultIp;
    }
    return ip.trim();
  }

  /// Menyimpan Alamat IP ESP32 ke penyimpanan lokal
  static Future<void> saveDeviceIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    String cleanIp = ip.trim().replaceAll('http://', '').replaceAll('https://', '');
    if (cleanIp.endsWith('/')) {
      cleanIp = cleanIp.substring(0, cleanIp.length - 1);
    }
    if (cleanIp.isNotEmpty) {
      await prefs.setString(_prefKeyIp, cleanIp);
    }
  }

  /// Mendeteksi Subnet Prefix IPv4 lokal HP (misal '192.168.1')
  static Future<String?> getLocalSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          // Abaikan localhost atau IP virtual
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Auto-discovery otomatis mencari IP ESP32 di jaringan WiFi yang sama
  static Future<String?> discoverDeviceIp({
    Duration probeTimeout = const Duration(milliseconds: 350),
    void Function(String message)? onProgress,
  }) async {
    // 1. Cek dulu IP yang tersimpan saat ini
    final currentIp = await getDeviceIp();
    onProgress?.call('Memverifikasi IP tersimpan ($currentIp)...');
    try {
      final res = await _dio.get(
        'http://$currentIp/api/status',
        options: Options(receiveTimeout: const Duration(milliseconds: 700)),
      );
      if (res.statusCode == 200 && res.data is Map) {
        return currentIp;
      }
    } catch (_) {}

    // 2. Cek Hotspot AP default 192.168.4.1
    if (currentIp != _defaultIp) {
      onProgress?.call('Mengecek Hotspot GlucoBand ($_defaultIp)...');
      try {
        final res = await _dio.get(
          'http://$_defaultIp/api/status',
          options: Options(receiveTimeout: const Duration(milliseconds: 700)),
        );
        if (res.statusCode == 200 && res.data is Map) {
          await saveDeviceIp(_defaultIp);
          return _defaultIp;
        }
      } catch (_) {}
    }

    // 3. Cek domain mDNS lokal (glucoband.local)
    onProgress?.call('Mengecek glucoband.local...');
    try {
      final res = await _dio.get(
        'http://glucoband.local/api/status',
        options: Options(receiveTimeout: const Duration(milliseconds: 900)),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final discoveredIp = res.data['ip']?.toString() ?? 'glucoband.local';
        await saveDeviceIp(discoveredIp);
        return discoveredIp;
      }
    } catch (_) {}

    // 4. Deteksi subnet smartphone dan scan seluruh host 1..254 secara paralel
    final prefix = await getLocalSubnetPrefix();
    if (prefix == null) {
      return null;
    }

    if (prefix == '192.168.4') {
      await saveDeviceIp(_defaultIp);
      return _defaultIp;
    }

    onProgress?.call('Memindai jaringan WiFi ($prefix.x) untuk GlucoBand...');

    // Buat daftar target IP 1..254
    final allIps = List.generate(254, (i) => '$prefix.${i + 1}');
    const batchSize = 35; // Batch 35 socket koneksi paralel

    for (int i = 0; i < allIps.length; i += batchSize) {
      final end = (i + batchSize < allIps.length) ? i + batchSize : allIps.length;
      final batch = allIps.sublist(i, end);

      final openHosts = await Future.wait(batch.map((targetIp) async {
        try {
          final socket = await Socket.connect(targetIp, 80, timeout: probeTimeout);
          socket.destroy();
          return targetIp;
        } catch (_) {
          return null;
        }
      }));

      final activeIps = openHosts.whereType<String>().toList();
      for (final activeIp in activeIps) {
        try {
          final res = await _dio.get(
            'http://$activeIp/api/status',
            options: Options(
              receiveTimeout: const Duration(milliseconds: 800),
              sendTimeout: const Duration(milliseconds: 800),
            ),
          );
          if (res.statusCode == 200 && res.data is Map) {
            final data = Map<String, dynamic>.from(res.data);
            if (data['ap_ssid'] != null || data['wifi_connected'] != null || data['sensors'] != null) {
              await saveDeviceIp(activeIp);
              return activeIp;
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Cek status koneksi WiFi dan informasi ESP32 dengan auto-fallback
  static Future<Map<String, dynamic>> checkStatus({
    Duration timeout = const Duration(milliseconds: 1800),
    bool autoFallback = true,
  }) async {
    final ip = await getDeviceIp();

    // 1. Coba pada IP aktif
    try {
      final response = await _dio.get(
        'http://$ip/api/status',
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (_) {}

    // 2. Auto-fallback ke 192.168.4.1 jika IP aktif saat ini bukan 192.168.4.1
    if (autoFallback && ip != _defaultIp) {
      try {
        final response = await _dio.get(
          'http://$_defaultIp/api/status',
          options: Options(receiveTimeout: timeout, sendTimeout: timeout),
        );
        if (response.statusCode == 200 && response.data is Map) {
          await saveDeviceIp(_defaultIp);
          return Map<String, dynamic>.from(response.data);
        }
      } catch (_) {}
    }

    throw Exception('Respons status ESP32 tidak valid.');
  }

  /// Inisiasi dan pengujian kesiapan sensor perangkat
  static Future<Map<String, dynamic>> initDevice() async {
    final ip = await getDeviceIp();
    final response = await _dio.get('http://$ip/api/init');
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    throw Exception('Gagal melakukan inisiasi sensor.');
  }

  /// Membaca data sensor secara real-time dari ESP32
  static Future<Map<String, dynamic>> getLiveSensors() async {
    final ip = await getDeviceIp();
    final response = await _dio.get('http://$ip/api/sensors');
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    throw Exception('Gagal membaca data sensor dari ESP32.');
  }

  /// Mengirim kredensial WiFi baru ke ESP32 dan mendapatkan respon status koneksi & IP baru
  static Future<WifiConfigResult> configureWifi(String ssid, String password) async {
    final currentIp = await getDeviceIp();
    final ipsToTry = [currentIp];
    if (currentIp != _defaultIp) ipsToTry.add(_defaultIp);

    for (final targetIp in ipsToTry) {
      try {
        final response = await _dio.post(
          'http://$targetIp/api/wifi',
          data: {
            'ssid': ssid.trim(),
            'password': password.trim(),
          },
          options: Options(
            // Berikan waktu hingga 12 detik karena ESP32 mencoba bernegosiasi dengan router langsung
            receiveTimeout: const Duration(milliseconds: 14000),
            sendTimeout: const Duration(milliseconds: 5000),
          ),
        );

        if (response.statusCode == 200 && response.data is Map) {
          final data = Map<String, dynamic>.from(response.data);
          final bool isSuccess = data['success'] == true || data['status'] == 'success' || data['wifi_connected'] == true;
          final bool isConnected = data['wifi_connected'] == true;
          final String? newIp = data['ip']?.toString().trim();
          final String msg = data['message']?.toString() ??
              (isConnected ? 'Berhasil terhubung ke WiFi!' : 'Kredensial disimpan.');

          if (isConnected && newIp != null && newIp.isNotEmpty && newIp != _defaultIp && newIp != '0.0.0.0') {
            await saveDeviceIp(newIp);
          }

          return WifiConfigResult(
            success: isSuccess,
            wifiConnected: isConnected,
            newIp: newIp,
            ssid: ssid,
            message: msg,
          );
        } else if (response.statusCode == 200) {
          return WifiConfigResult(
            success: true,
            wifiConnected: false,
            ssid: ssid,
            message: 'Kredensial tersimpan di ESP32.',
          );
        }
      } catch (_) {}
    }

    return WifiConfigResult(
      success: false,
      wifiConnected: false,
      message: 'Gagal mengirim konfigurasi WiFi ke ESP32.',
    );
  }

  /// Memindai jaringan WiFi di sekitar ESP32 secara langsung
  static Future<List<Map<String, dynamic>>> scanWifiNetworks({
    int maxAttempts = 15,
  }) async {
    final ip = await getDeviceIp();
    final ipsToTry = [ip];
    if (ip != _defaultIp) ipsToTry.add(_defaultIp);

    for (final targetIp in ipsToTry) {
      for (int i = 0; i < maxAttempts; i++) {
        try {
          final response = await _dio.get(
            'http://$targetIp/api/scan',
            options: Options(
              receiveTimeout: const Duration(milliseconds: 2500),
              sendTimeout: const Duration(milliseconds: 2500),
            ),
          );

          if (response.statusCode == 200 && response.data is List) {
            final rawList = List<Map<String, dynamic>>.from(
              (response.data as List).where((e) =>
                  e is Map &&
                  e['ssid'] != null &&
                  e['ssid'].toString().trim().isNotEmpty),
            );

            // Bersihkan duplikasi SSID, simpan yang memiliki sinyal RSSI terkuat
            final Map<String, Map<String, dynamic>> unique = {};
            for (final item in rawList) {
              final ssid = item['ssid'].toString().trim();
              final rssi = (item['rssi'] is num) ? (item['rssi'] as num).toInt() : -100;
              final enc = (item['encryption'] is num) ? (item['encryption'] as num).toInt() : 0;
              final isSecure = enc != 0;

              if (!unique.containsKey(ssid) || rssi > (unique[ssid]!['rssi'] as int)) {
                unique[ssid] = {
                  'ssid': ssid,
                  'rssi': rssi,
                  'encryption': enc,
                  'is_secure': isSecure,
                };
              }
            }

            final result = unique.values.toList();
            result.sort((a, b) => (b['rssi'] as int).compareTo(a['rssi'] as int));
            return result;
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    return [];
  }

  /// Menunggu ESP32 terhubung dan mendapatkan IP baru secara otomatis
  static Future<String?> waitForConnectionAndGetNewIp({
    Duration timeout = const Duration(seconds: 20),
    String? expectedSsid,
  }) async {
    final startTime = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 1500));

    while (DateTime.now().difference(startTime) < timeout) {
      // 1. Cek via 192.168.4.1 (ESP32 AP_STA mode)
      try {
        final response = await _dio.get(
          'http://$_defaultIp/api/status',
          options: Options(
            receiveTimeout: const Duration(milliseconds: 1200),
            sendTimeout: const Duration(milliseconds: 1200),
          ),
        );

        if (response.statusCode == 200 && response.data is Map) {
          final data = Map<String, dynamic>.from(response.data);
          final bool wifiConnected = data['wifi_connected'] == true;
          final String? ip = data['ip']?.toString().trim();

          if (wifiConnected && ip != null && ip.isNotEmpty && ip != '0.0.0.0' && ip != _defaultIp) {
            await saveDeviceIp(ip);
            return ip;
          }
        }
      } catch (_) {}

      // 2. Cek apakah HP sudah beralih ke jaringan yang sama dan dapat menjangkau via subnet
      final discovered = await discoverDeviceIp(
        probeTimeout: const Duration(milliseconds: 250),
      );
      if (discovered != null && discovered != _defaultIp) {
        return discovered;
      }

      await Future.delayed(const Duration(milliseconds: 1200));
    }

    return null;
  }

  /// Menghapus kredensial WiFi pada ESP32 (kembali ke AP mode murni)
  static Future<bool> resetWifi() async {
    final ip = await getDeviceIp();
    final ipsToTry = [ip];
    if (ip != _defaultIp) ipsToTry.add(_defaultIp);

    for (final targetIp in ipsToTry) {
      try {
        final response = await _dio.post(
          'http://$targetIp/api/reset',
          options: Options(receiveTimeout: const Duration(milliseconds: 2500)),
        );
        if (response.statusCode == 200) {
          await saveDeviceIp(_defaultIp);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
