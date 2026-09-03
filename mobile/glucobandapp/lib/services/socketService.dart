import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/apiConstant.dart';

class SocketService {
  IO.Socket? _socket;
  Function? onNewNotification;

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;
    String url = ApiConstants.baseUrl;
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }
    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join', {'token': token});
    });

    _socket!.on('new_recommendation', (data) {
      if (onNewNotification != null) {
        onNewNotification!();
      }
    });

    _socket!.on('new_notification', (data) {
      if (onNewNotification != null) {
        onNewNotification!();
      }
    });

    _socket!.onDisconnect((_) => print('Socket disconnected'));

    _socket!.connect();
  }

  void disconnect() {
    _socket?.emit('leave');
    _socket?.disconnect();
    _socket?.destroy();
    _socket = null;
  }
}
