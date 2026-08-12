import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    // JWT & BaseUrl interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = AppConstants.apiBaseUrl;
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired — could trigger re-login
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'access_token');
  }

  // ── Auth ──────────────────────────────────────────────────────────────
  Future<Response> registerUser(Map<String, dynamic> data) =>
      dio.post('/auth/register/user', data: data);

  Future<Response> registerOrganization(Map<String, dynamic> data) =>
      dio.post('/auth/register/organization', data: data);

  Future<Response> login(String email, String password) =>
      dio.post('/auth/login', data: {'email': email, 'password': password});

  Future<Response> getMe() => dio.get('/auth/me');

  // ── User ──────────────────────────────────────────────────────────────
  Future<Response> getProfile() => dio.get('/users/profile');

  Future<Response> updateProfile(Map<String, dynamic> data) =>
      dio.put('/users/profile', data: data);

  Future<Response> updateUserLocation(double lat, double lng) =>
      dio.put('/users/location', data: {'lat': lat, 'lng': lng});

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
