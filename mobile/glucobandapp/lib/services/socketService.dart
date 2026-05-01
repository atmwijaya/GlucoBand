import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/apiConstant.dart';

class SocketService {
  IO.Socket? _socket;
  Function? onNewNotification;

  void connect(String token) {
    _socket = IO.io(
      ApiConstants.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
      _socket!.emit('join', {'token': token});
    });

    _socket!.on('new_recommendation', (data) {
      print('New recommendation received: $data');
      if (onNewNotification != null) {
        onNewNotification!();
      }
    });

    _socket!.on('new_notification', (data) {
      print('New notification received: $data');
      if (onNewNotification != null) {
        onNewNotification!();
      }
    });

    _socket!.onDisconnect((_) => print('Socket disconnected'));
  }

  void disconnect() {
    _socket?.emit('leave');
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }
}