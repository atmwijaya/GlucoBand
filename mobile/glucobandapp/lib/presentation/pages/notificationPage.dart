import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notificationProvider.dart';
import '../providers/authProvider.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({Key? key}) : super(key: key);
  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        notifProvider.fetchNotifications(token, markAsRead: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.notifications.isEmpty) {
            return const Center(child: Text('Tidak ada notifikasi.'));
          }
          return ListView.builder(
            itemCount: provider.notifications.length,
            itemBuilder: (context, index) {
              final notif = provider.notifications[index];
              return ListTile(
                leading: Icon(
                  notif.type == 'alert'
                      ? Icons.warning_amber_rounded
                      : Icons.message_outlined,
                  color: notif.type == 'alert' ? Colors.orange : Colors.blue,
                ),
                title: Text(notif.message),
                subtitle: Text(notif.formattedCreatedAt ?? ''),
                trailing: notif.isRead
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}