import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class McpClient {
  final String _url;
  WebSocketChannel? _channel;
  int _idCounter = 0;
  final Map<int, Completer<dynamic>> _pending = {};

  McpClient._(this._url);

  static Future<McpClient> connect() async {
    final url = dotenv.env['MCP_WS_URL'] ?? 'ws://127.0.0.1:5002';
    final client = McpClient._(url);
    await client._open();
    return client;
  }

  Future<void> _open() async {
    _channel = WebSocketChannel.connect(Uri.parse(_url));
    _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);
  }

  Future<dynamic> call(String method, [Map<String, dynamic>? params]) {
    if (_channel == null) {
      throw StateError('MCP channel is not connected');
    }
    final id = ++_idCounter;
    final payload = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params ?? {},
    };
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _channel!.sink.add(jsonEncode(payload));
    return completer.future;
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      if (data.containsKey('id')) {
        final id = data['id'];
        final completer = _pending.remove(id);
        if (completer != null) {
          if (data.containsKey('error') && data['error'] != null) {
            completer.completeError(data['error']);
          } else {
            completer.complete(data['result']);
          }
        }
      }
    } catch (_) {
      // Ignore malformed messages
    }
  }

  void _onError(Object error) {
    for (final entry in _pending.entries) {
      entry.value.completeError(error);
    }
    _pending.clear();
  }

  void _onDone() {
    for (final entry in _pending.entries) {
      entry.value.completeError(StateError('MCP connection closed'));
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
