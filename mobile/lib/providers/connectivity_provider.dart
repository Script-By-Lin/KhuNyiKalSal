import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_service.dart';

class ConnectivityNotifier extends StateNotifier<bool> {
  final OfflineService _offlineService = OfflineService();

  ConnectivityNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    state = await _offlineService.checkInternet();
    _offlineService.onConnectivityChanged.listen((isOnline) {
      state = isOnline;
    });
  }

  Future<void> refresh() async {
    state = await _offlineService.checkInternet();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});
