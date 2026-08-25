import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';

/// Auth state
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? role;
  final String? email;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.role,
    this.email,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? role,
    String? email,
    String? error,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        email: email ?? this.email,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();


  AuthNotifier() : super(const AuthState());

  WebSocketService get ws => _ws;

  /// Try to restore session from stored token or refresh token
  Future<String?> tryAutoLogin() async {
    final token = await _api.getToken();
    final refreshToken = await _api.getRefreshToken();
    if (token == null && refreshToken == null) return null;

    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.getMe();
      final data = res.data;
      final role = data['role'] as String?;
      state = AuthState(
        isAuthenticated: true,
        userId: data['id'],
        role: role,
        email: data['email'],
      );
      _ws.connect(data['id'], token: token);
      NotificationService().syncSavedDeviceToken();
      return role;
    } catch (_) {
      // If access token failed, attempt refresh token
      if (refreshToken != null) {
        try {
          final refreshRes = await _api.refreshToken(refreshToken);
          final rData = refreshRes.data;
          await _api.setTokens(
            accessToken: rData['access_token'],
            refreshToken: rData['refresh_token'],
            sessionId: rData['session_id'],
          );

          final meRes = await _api.getMe();
          final meData = meRes.data;
          final role = meData['role'] as String?;
          state = AuthState(
            isAuthenticated: true,
            userId: meData['id'],
            role: role,
            email: meData['email'],
          );
          _ws.connect(meData['id'], token: rData['access_token']);
          NotificationService().syncSavedDeviceToken();
          return role;
        } catch (_) {}
      }

      await _api.clearTokens();
      state = const AuthState(isLoading: false);
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.login(email, password);
      final data = res.data;
      await _api.setTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        sessionId: data['session_id'],
      );
      state = AuthState(
        isAuthenticated: true,
        userId: data['user_id'],
        role: data['role'],
        email: email,
      );
      _ws.connect(data['user_id'], token: data['access_token']);
      NotificationService().syncSavedDeviceToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<bool> registerUser(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.registerUser(data);
      final body = res.data;
      await _api.setTokens(
        accessToken: body['access_token'],
        refreshToken: body['refresh_token'],
        sessionId: body['session_id'],
      );
      state = AuthState(
        isAuthenticated: true,
        userId: body['user_id'],
        role: body['role'],
        email: data['email'],
      );
      _ws.connect(body['user_id'], token: body['access_token']);
      NotificationService().syncSavedDeviceToken();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> registerOrganization(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.registerOrganization(data);
      final body = res.data;
      await _api.setTokens(
        accessToken: body['access_token'],
        refreshToken: body['refresh_token'],
        sessionId: body['session_id'],
      );
      state = AuthState(
        isAuthenticated: true,
        userId: body['user_id'],
        role: body['role'],
        email: data['email'],
      );
      _ws.connect(body['user_id'], token: body['access_token']);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    _ws.disconnect();
    await _api.clearTokens();
    state = const AuthState();
  }

  Future<void> logoutAllDevices() async {
    try {
      await _api.logoutAll();
    } catch (_) {}
    _ws.disconnect();
    await _api.clearTokens();
    state = const AuthState();
  }

  String _extractError(dynamic e) {
    try {
      // Try to extract server error detail
      final dioErr = e as dynamic;
      if (dioErr.response != null) {
        final data = dioErr.response?.data;
        if (data is Map && data.containsKey('detail')) {
          return data['detail'].toString();
        }
        return 'Server error: ${dioErr.response?.statusCode}';
      }
      // Connection error (no response from server)
      return dioErr.message?.toString() ?? e.toString();
    } catch (_) {
      return e.toString();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
