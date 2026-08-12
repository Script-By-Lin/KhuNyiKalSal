import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency.dart';
import '../services/api_service.dart';

class EmergencyNotifier extends StateNotifier<AsyncValue<List<EmergencyModel>>> {
  final ApiService _api = ApiService();

  EmergencyNotifier() : super(const AsyncValue.loading());

  Future<void> loadActive() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.getActiveEmergencies();
      final list = (res.data as List)
          .map((e) => EmergencyModel.fromJson(e))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? lastError;

  Future<String?> createSOS(String type, double lat, double lng) async {
    lastError = null;
    try {
      final res = await _api.createSOS(type, lat, lng);
      await loadActive();
      return res.data['emergency_id'];
    } catch (e) {
      lastError = _extractError(e);
      return null;
    }
  }

  String _extractError(dynamic e) {
    try {
      final dioErr = e as dynamic;
      if (dioErr.response != null && dioErr.response.data != null) {
        final data = dioErr.response.data;
        if (data is Map && data.containsKey('detail')) {
          return data['detail'].toString();
        }
      }
      return dioErr.message?.toString() ?? 'Emergency request failed';
    } catch (_) {
      return e.toString();
    }
  }

  Future<void> cancelEmergency(String id) async {
    await _api.cancelEmergency(id);
    await loadActive();
  }

  Future<void> completeEmergency(String id) async {
    await _api.completeEmergency(id);
    await loadActive();
  }
}

final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, AsyncValue<List<EmergencyModel>>>(
        (ref) => EmergencyNotifier());
