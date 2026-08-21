import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';

class EmergencyNotifier extends StateNotifier<AsyncValue<List<EmergencyModel>>> {
  final ApiService _api = ApiService();
  String? lastError;
  bool isLastNetworkError = false;

  EmergencyNotifier() : super(const AsyncValue.loading()) {
    OfflineService().onSOSQueueSynced.listen((count) {
      if (count > 0) {
        loadActive();
      }
    });
  }

  Future<void> loadActive({bool showLoading = false}) async {
    if (showLoading || !state.hasValue) {
      state = const AsyncValue.loading();
    }
    try {
      final res = await _api.getActiveEmergencies();
      final list = (res.data as List)
          .map((e) => EmergencyModel.fromJson(e))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void markAccepted(String emergencyId, {String? assignedOrgId, String? assignedVolunteerId}) {
    if (state.hasValue) {
      final updated = state.value!.map((e) {
        if (e.id == emergencyId) {
          return EmergencyModel(
            id: e.id,
            userId: e.userId,
            type: e.type,
            status: 'accepted',
            locationLat: e.locationLat,
            locationLng: e.locationLng,
            assignedOrgId: assignedOrgId ?? e.assignedOrgId,
            assignedVolunteerId: assignedVolunteerId ?? e.assignedVolunteerId,
            createdAt: e.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        return e;
      }).toList();
      state = AsyncValue.data(updated);
    }
  }

  Future<String?> createSOS(String type, double lat, double lng) async {
    lastError = null;
    isLastNetworkError = false;
    try {
      final res = await _api.createSOS(type, lat, lng);
      await loadActive();
      return (res.data['emergency_id'] ?? res.data['id'])?.toString();
    } catch (e) {
      if (e is DioException) {
        if (e.response == null) {
          // Genuine no-response network failure (socket error, timeout, DNS failure)
          isLastNetworkError = true;
        } else {
          // Server responded with an actual error code (400, 403, 429, 500)
          isLastNetworkError = false;
        }
      }
      lastError = _extractError(e);
      return null;
    }
  }

  String _extractError(dynamic e) {
    try {
      if (e is DioException) {
        if (e.response != null && e.response!.data != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey('detail')) {
            return data['detail'].toString();
          }
        }
        return e.message ?? 'Emergency request failed. Please check connection.';
      }
      return e.toString();
    } catch (_) {
      return 'Emergency request failed.';
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
