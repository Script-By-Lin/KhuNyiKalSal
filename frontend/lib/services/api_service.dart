import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  late final Dio _tokenDio; // Dedicated Dio instance for refresh calls to avoid infinite loops
  static const _androidOptions = AndroidOptions(
    resetOnError: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  final _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
  bool _isRefreshing = false;

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      try {
        await _storage.deleteAll();
        await _storage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  ApiService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _tokenDio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    // JWT & BaseUrl interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = AppConstants.apiBaseUrl;
        final token = await _safeRead('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final isAuthEndpoint = path.contains('/auth/login') ||
            path.contains('/auth/refresh') ||
            path.contains('/auth/register');

        if (error.response?.statusCode == 401 && !isAuthEndpoint && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshToken = await _safeRead('refresh_token');
            if (refreshToken != null) {
              final refreshRes = await _tokenDio.post(
                '/auth/refresh',
                data: {'refresh_token': refreshToken},
              );

              if (refreshRes.statusCode == 200) {
                final newAccess = refreshRes.data['access_token'];
                final newRefresh = refreshRes.data['refresh_token'];
                await setTokens(
                  accessToken: newAccess,
                  refreshToken: newRefresh ?? refreshToken,
                );

                // Retry original request with new token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccess';
                _isRefreshing = false;
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              }
            }
          } catch (_) {
            // Refresh failed — clear local session
            await clearTokens();
          } finally {
            _isRefreshing = false;
          }
        }
        return handler.next(error);
      },
    ));
  }

  // ── Token & Device Management ─────────────────────────────────────────

  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
    String? sessionId,
  }) async {
    await _safeWrite('access_token', accessToken);
    if (refreshToken != null) {
      await _safeWrite('refresh_token', refreshToken);
    }
    if (sessionId != null) {
      await _safeWrite('session_id', sessionId);
    }
  }

  Future<void> setToken(String token) async {
    await _safeWrite('access_token', token);
  }

  Future<String?> getToken() async {
    return await _safeRead('access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _safeRead('refresh_token');
  }

  Future<void> clearTokens() async {
    await _safeDelete('access_token');
    await _safeDelete('refresh_token');
    await _safeDelete('session_id');
  }

  Future<void> clearToken() async {
    await clearTokens();
  }

  Future<String> getDeviceId() async {
    var deviceId = await _safeRead('device_id');
    if (deviceId == null) {
      final rand = Random().nextInt(1000000);
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_$rand';
      await _safeWrite('device_id', deviceId);
    }
    return deviceId;
  }

  String getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isAndroid) return 'Android Phone';
      if (Platform.isIOS) return 'iPhone / iPad';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isMacOS) return 'macOS Device';
      if (Platform.isLinux) return 'Linux Device';
    } catch (_) {}
    return 'Mobile Device';
  }

  // ── Auth ──────────────────────────────────────────────────────────────
  Future<Response> registerUser(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['device_id'] ??= await getDeviceId();
    payload['device_name'] ??= getDeviceName();
    return dio.post('/auth/register/user', data: payload);
  }

  Future<Response> registerOrganization(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['device_id'] ??= await getDeviceId();
    payload['device_name'] ??= getDeviceName();
    return dio.post('/auth/register/organization', data: payload);
  }

  Future<Response> login(String email, String password) async {
    final deviceId = await getDeviceId();
    final deviceName = getDeviceName();
    return dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'device_name': deviceName,
    });
  }

  Future<Response> refreshToken(String refreshToken) =>
      _tokenDio.post('/auth/refresh', data: {'refresh_token': refreshToken});

  Future<Response> logout() => dio.post('/auth/logout');

  Future<Response> logoutAll() => dio.post('/auth/logout-all');

  Future<Response> getSessions() async {
    try {
      return await dio.get('/auth/sessions');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return await dio.get('/users/sessions');
      }
      rethrow;
    }
  }

  Future<Response> revokeSession(String sessionId) =>
      dio.delete('/auth/sessions/$sessionId');

  Future<Response> getMe() => dio.get('/auth/me');

  // ── User ──────────────────────────────────────────────────────────────
  Future<Response> getProfile() => dio.get('/users/profile');

  Future<Response> updateProfile(Map<String, dynamic> data) =>
      dio.put('/users/profile', data: data);

  Future<Response> updateUserLocation(double lat, double lng) =>
      dio.put('/users/location', data: {'lat': lat, 'lng': lng});

  Future<Response> registerDeviceToken(String fcmToken) async {
    final deviceId = await getDeviceId();
    final deviceName = getDeviceName();
    return dio.post('/users/device-token', data: {
      'fcm_token': fcmToken,
      'device_id': deviceId,
      'device_name': deviceName,
    });
  }

  // ── Organizations ─────────────────────────────────────────────────────
  Future<Response> getNearbyOrgs(double lat, double lng) =>
      dio.get('/organizations/nearby', queryParameters: {'lat': lat, 'lng': lng});

  Future<Response> getAllOrgs({double? lat, double? lng}) =>
      dio.get('/organizations/all', queryParameters: <String, dynamic>{
        // ignore: use_null_aware_elements
        if (lat != null) 'lat': lat,
        // ignore: use_null_aware_elements
        if (lng != null) 'lng': lng,
      });

  // ── Emergency ─────────────────────────────────────────────────────────
  Future<Response> createSOS(String type, double lat, double lng) =>
      dio.post('/emergency/sos', data: {
        'type': type,
        'location_lat': lat,
        'location_lng': lng,
      });

  Future<Response> getActiveEmergencies() => dio.get('/emergency/active');

  Future<Response> getEmergencyHistory() => dio.get('/emergency/history');

  Future<Response> cancelEmergency(String id) =>
      dio.put('/emergency/$id/cancel');

  Future<Response> completeEmergency(String id) =>
      dio.put('/emergency/$id/complete');

  // ── Family System ─────────────────────────────────────────────────────
  Future<Response> createFamilyGroup(String name) =>
      dio.post('/family/create', data: {'group_name': name});

  Future<Response> getMyFamilyGroup() => dio.get('/family/my-group');

  Future<Response> updateFamilyGroup(String name) =>
      dio.put('/family/update', data: {'group_name': name});

  Future<Response> deleteFamilyGroup() =>
      dio.delete('/family/group');

  Future<Response> leaveFamilyGroup() =>
      dio.post('/family/leave');

  Future<Response> addFamilyMember(String email, String relationship) =>
      dio.post('/family/add-member', data: {'email': email, 'relationship': relationship});

  Future<Response> removeFamilyMember(String memberAccountId) =>
      dio.delete('/family/members/$memberAccountId');

  Future<Response> getFamilyAlerts() => dio.get('/family/alerts');

  // ── Volunteers ────────────────────────────────────────────────────────
  Future<Response> createVolunteer(Map<String, dynamic> data) =>
      dio.post('/volunteers/', data: data);

  Future<Response> listVolunteers() => dio.get('/volunteers/');

  Future<Response> getVolunteerAlerts() => dio.get('/volunteers/alerts');

  Future<Response> respondToEmergency(String emergencyId, String action) =>
      dio.post('/volunteers/respond', data: {
        'emergency_id': emergencyId,
        'action': action,
      });

  Future<Response> updateVolunteerLocation(double lat, double lng) =>
      dio.put('/volunteers/location', data: {'lat': lat, 'lng': lng});

  Future<Response> toggleVolunteerStatus(String volunteerId) =>
      dio.put('/volunteers/$volunteerId/toggle-status');

  Future<Response> assignEmergencyToVolunteer(String emergencyId, String volunteerId) =>
      dio.post('/volunteers/assign', data: {
        'emergency_id': emergencyId,
        'volunteer_id': volunteerId,
      });

  Future<Response> getResponderHistory() => dio.get('/volunteers/history');

  // ── Admin ─────────────────────────────────────────────────────────────
  Future<Response> getAdminOrgs() => dio.get('/admin/organizations');

  Future<Response> createAdminOrg(Map<String, dynamic> data) =>
      dio.post('/admin/organizations', data: data);

  Future<Response> updateAdminOrg(String accountId, Map<String, dynamic> data) =>
      dio.put('/admin/organizations/$accountId', data: data);

  Future<Response> deleteAdminOrg(String accountId) =>
      dio.delete('/admin/organizations/$accountId');

  Future<Response> getAdminEmergencies() => dio.get('/admin/emergencies');
}
