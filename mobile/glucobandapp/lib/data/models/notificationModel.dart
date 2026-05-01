import 'package:intl/intl.dart';

class NotificationItem {
  final int id;
  final String type;      
  final String? subtype;  
  final String message;
  final String? createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    this.subtype,
    required this.message,
    this.createdAt,
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'alert',
      subtype: json['subtype'],
      message: json['message'] ?? '',
      createdAt: json['created_at'],
      isRead: json['is_read'] == 1 || json['is_read'] == true,
    );
  }

  String? get formattedCreatedAt {
    if (createdAt == null) return null;
    final dt = DateTime.tryParse(createdAt!);
    if (dt == null) return createdAt;
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }
}