import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/apiConstant.dart';
import '../../data/models/notificationModel.dart';
import '../../services/socketService.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  final SocketService _socketService = SocketService();

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void connectSocket(String token) {
    _socketService.onNewNotification = () {
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
      _notifications = data.map((json) => NotificationItem.fromJson(json)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      if (markAsRead) {
        for (final notif in _notifications) {
          if (notif.type == 'recommendation' && !notif.isRead) {
            notif.isRead = true;
            _markAsRead(notif.id, token);
          }
        }
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _markAsRead(int id, String token) async {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));
    try {
      await dio.put('/patient/recommendations/$id/read');
    } catch (e) {
      debugPrint('Error marking $id as read: $e');
    }
  }
}