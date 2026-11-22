import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/apiConstant.dart';
import '../../data/models/notificationModel.dart';
import '../../services/socketService.dart';
import '../../services/localNotificationService.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  final SocketService _socketService = SocketService();
  final Set<String> _localReadKeys = {};
  bool _hasLoadedLocalKeys = false;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  SocketService get socketService => _socketService;

  NotificationProvider() {
    _loadLocalReadKeys();
  }

  Future<void> _loadLocalReadKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList('glucoband_read_notif_keys') ?? [];
      _localReadKeys.addAll(keys);
      _hasLoadedLocalKeys = true;
    } catch (e) {
      debugPrint('Error loading local read keys: $e');
    }
  }

  Future<void> _saveLocalReadKey(String key) async {
    _localReadKeys.add(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('glucoband_read_notif_keys', _localReadKeys.toList());
    } catch (e) {
      debugPrint('Error saving local read key: $e');
    }
  }

  Future<void> _saveAllLocalReadKeys(Iterable<String> keys) async {
    _localReadKeys.addAll(keys);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('glucoband_read_notif_keys', _localReadKeys.toList());
    } catch (e) {
      debugPrint('Error saving all local read keys: $e');
    }
  }

  void connectSocket(String token, {int? currentUserId}) {
    _socketService.onNewNotification = () {
      fetchNotifications(token);
    };

    _socketService.onGlucoseAlert = (data) {
      final targetPatientId = data['patient_id'];
      if (currentUserId == null || targetPatientId == null || targetPatientId == currentUserId) {
        final rawGlucose = data['glucose_value'] ?? data['glucose'];
        final double? glucose = rawGlucose is num ? rawGlucose.toDouble() : double.tryParse(rawGlucose?.toString() ?? '');
        final String status = data['status']?.toString() ?? data['type']?.toString() ?? 'Peringatan';
        final String? msg = data['message']?.toString();

        if (glucose != null) {
          LocalNotificationService.showGlucoseNotification(
            glucose: glucose,
            status: status,
            message: msg,
          );
        }
      }
      fetchNotifications(token);
    };

    _socketService.connect(token);
  }

  void disconnectSocket() {
    _socketService.disconnect();
  }

  Future<void> fetchNotifications(String token, {bool markAsRead = false}) async {
    _isLoading = true;
    notifyListeners();

    if (!_hasLoadedLocalKeys) {
      await _loadLocalReadKeys();
    }

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    try {
      final response = await dio.get('/patient/notifications');
      final List data = response.data;
      final newNotifications = data.map((json) => NotificationItem.fromJson(json)).toList();
      
      // Sinkronisasi status baca dari preferensi lokal & server
      for (var item in newNotifications) {
        final keyTyped = '${item.type}_${item.id}';
        final keyId = '${item.id}';

        if (_localReadKeys.contains(keyTyped) || _localReadKeys.contains(keyId) || item.isRead) {
          item.isRead = true;
          _localReadKeys.add(keyTyped);
        } else {
          // Periksa apakah sebelumnya di memori sudah dibaca
          final prevItem = _notifications.cast<NotificationItem?>().firstWhere(
            (old) => old != null && old.id == item.id && old.type == item.type,
            orElse: () => null,
          );
          if (prevItem != null && prevItem.isRead) {
            item.isRead = true;
            _localReadKeys.add(keyTyped);
          }
        }

        // Tandai animasi jika benar-benar baru
        if (_notifications.isNotEmpty && !_notifications.any((old) => old.id == item.id && old.type == item.type)) {
          item.isNew = true;
        }
      }
      
      _notifications = newNotifications;
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      if (markAsRead) {
        await markAllAsRead(token);
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Menandai satu notifikasi telah dibaca secara instan (saat diklik/di-inspect)
  Future<void> markAsRead(NotificationItem notif, String token) async {
    if (notif.isRead) return;

    // 1. Update status lokal secara instan (UI langsung responsif)
    notif.isRead = true;
    notif.isNew = false;
    final keyTyped = '${notif.type}_${notif.id}';
    final keyId = '${notif.id}';
    _saveLocalReadKey(keyTyped);
    _saveLocalReadKey(keyId);

    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();

    // 2. Sinkronisasi ke backend di latar belakang
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    try {
      if (notif.type == 'recommendation') {
        await dio.put('/patient/recommendations/${notif.id}/read');
      } else {
        await dio.put('/patient/notifications/${notif.id}/read');
      }
    } catch (e) {
      debugPrint('Gagal mengirim status read notif ${notif.id} ke server: $e');
    }
  }

  /// Menandai seluruh notifikasi telah dibaca
  Future<void> markAllAsRead(String token) async {
    final keys = <String>[];
    for (final notif in _notifications) {
      notif.isRead = true;
      notif.isNew = false;
      keys.add('${notif.type}_${notif.id}');
      keys.add('${notif.id}');
    }
    await _saveAllLocalReadKeys(keys);

    _unreadCount = 0;
    notifyListeners();

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    try {
      await dio.put('/patient/notifications/read-all');
    } catch (e) {
      debugPrint('Gagal menandai semua notifikasi dibaca di server: $e');
    }
  }
}
