import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket/websocket_connector_stub.dart'
    if (dart.library.io) 'websocket/websocket_connector_io.dart'
    if (dart.library.html) 'websocket/websocket_connector_web.dart';

typedef WebSocketConnector = Future<WebSocketChannel> Function(Uri uri);

class GatewayConnectionRepository {
  GatewayConnectionRepository({WebSocketConnector? connector})
    : _connector = connector ?? connectWebSocket;

  final WebSocketConnector _connector;
  WebSocketChannel? _channel;

  WebSocketChannel? get channel => _channel;

  Future<WebSocketChannel> connect(Uri uri) async {
    await close();
    final channel = await _connector(uri);
    _channel = channel;
    return channel;
  }

  Future<void> close() async {
    final current = _channel;
    _channel = null;
    if (current != null) {
      await current.sink.close();
    }
  }
}
