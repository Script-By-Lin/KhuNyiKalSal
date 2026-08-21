import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organization.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';

class OrganizationNotifier
    extends StateNotifier<AsyncValue<List<OrganizationModel>>> {
  final ApiService _api = ApiService();
  final OfflineService _offline = OfflineService();

  OrganizationNotifier() : super(const AsyncValue.data([]));

  Future<void> loadNearby(double lat, double lng) async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.getNearbyOrgs(lat, lng);
      final rawList = List<Map<String, dynamic>>.from(res.data);
      await _offline.cacheOrganizations(rawList);
      final list = rawList.map((e) => OrganizationModel.fromJson(e)).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      final cached = await _offline.getCachedOrganizations();
      if (cached.isNotEmpty) {
        final list = cached.map((e) => OrganizationModel.fromJson(e)).toList();
        state = AsyncValue.data(list);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> loadAll({double? lat, double? lng}) async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.getAllOrgs(lat: lat, lng: lng);
      final rawList = List<Map<String, dynamic>>.from(res.data);
      await _offline.cacheOrganizations(rawList);
      final list = rawList.map((e) => OrganizationModel.fromJson(e)).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      final cached = await _offline.getCachedOrganizations();
      if (cached.isNotEmpty) {
        final list = cached.map((e) => OrganizationModel.fromJson(e)).toList();
        state = AsyncValue.data(list);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final organizationProvider = StateNotifierProvider<OrganizationNotifier,
    AsyncValue<List<OrganizationModel>>>((ref) => OrganizationNotifier());

final allOrganizationsProvider = StateNotifierProvider<OrganizationNotifier,
    AsyncValue<List<OrganizationModel>>>((ref) => OrganizationNotifier());

