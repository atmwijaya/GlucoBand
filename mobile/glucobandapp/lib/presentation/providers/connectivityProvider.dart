import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _showReconnected = false;
  Timer? _timer;

  bool get isOnline => _isOnline;
  bool get showReconnected => _showReconnected;

  ConnectivityProvider() {
    checkConnectivity();
    // Cek koneksi secara berkala setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkConnectivity();
    });
  }

  Future<void> checkConnectivity() async {
    bool hasConnection = false;
    try {
      final lookupResult = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty) {
        hasConnection = true;
      }
    } catch (_) {
      // Fallback cek host server lokal atau internet alternatif jika google diblokir
      try {
        final altResult = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 2));
        if (altResult.isNotEmpty && altResult[0].rawAddress.isNotEmpty) {
          hasConnection = true;
        }
      } catch (_) {
        hasConnection = false;
      }
    }

    if (_isOnline != hasConnection) {
      final bool wasOffline = !_isOnline;
      _isOnline = hasConnection;

      if (hasConnection && wasOffline) {
        // Tampilkan banner hijau "Kembali Online" selama 3.5 detik
        _showReconnected = true;
        Timer(const Duration(milliseconds: 3500), () {
          _showReconnected = false;
          notifyListeners();
        });
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
