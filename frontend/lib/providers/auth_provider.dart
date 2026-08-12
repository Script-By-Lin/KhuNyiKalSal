import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../services/api_service.dart';
import '../services/websocket_service.dart';

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

  /// Try to restore session from stored token
  Future<String?> tryAutoLogin() async {
    final token = await _api.getToken();
    if (token == null) return null;

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
      _ws.connect(data['id']);
      return role;
    } catch (_) {
      await _api.clearToken();
      state = const AuthState(isLoading: false);
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.login(email, password);
      final data = res.data;
      await _api.setToken(data['access_token']);
      state = AuthState(
        isAuthenticated: true,
        userId: data['user_id'],
        role: data['role'],
        email: email,
      );
      _ws.connect(data['user_id']);
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
      await _api.setToken(body['access_token']);
      state = AuthState(
        isAuthenticated: true,
        userId: body['user_id'],
        role: body['role'],
        email: data['email'],
      );
      _ws.connect(body['user_id']);
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
      await _api.setToken(body['access_token']);
      state = AuthState(
        isAuthenticated: true,
        userId: body['user_id'],
        role: body['role'],
        email: data['email'],
      );
      _ws.connect(body['user_id']);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> logout() async {
    // Keep active emergencies open during logout so Org and Volunteer panels can be tested
    _ws.disconnect();
    await _api.clearToken();
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
