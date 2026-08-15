import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _channel != null;

  String? _currentUserId;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;

  void connect(String userId) {
    if (_isDisposed) return;
    _currentUserId = userId;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    disconnect();

    try {
      final uri = Uri.parse('${AppConstants.wsBaseUrl}/$userId');
      _channel = WebSocketChannel.connect(uri);
      _reconnectAttempts = 0;

      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            _eventController.add(decoded);
          } catch (_) {}
        },
        onError: (error) {
          _handleDisconnection();
        },
        onDone: () {
          _handleDisconnection();
        },
      );
    } catch (_) {
      _handleDisconnection();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected) {
        send({'event': 'PING', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _handleDisconnection() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _channel = null;

    if (_isDisposed || _currentUserId == null) return;

    _reconnectTimer?.cancel();
    // Exponential backoff: 1s, 2s, 4s, 8s, up to max 16s
    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 16);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _currentUserId != null) {
        connect(_currentUserId!);
      }
    });
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventController.close();
  }
}
