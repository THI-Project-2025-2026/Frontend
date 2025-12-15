import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectWebSocket(Uri uri) async {
  return IOWebSocketChannel.connect(uri);
}
