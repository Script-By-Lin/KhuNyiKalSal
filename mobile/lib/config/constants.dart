class AppConstants {
  static const String appName = 'Khu Nyi Kal Sal';

  // API host — Cloudflare Tunnel for remote testing
  static const String apiBaseUrl =
      'https://khunyikalsal-production.up.railway.app/api';
  static const String wsBaseUrl =
      'wss://khunyikalsal-production.up.railway.app/ws';

  // SOS
  static const Duration sosHoldDuration = Duration(seconds: 3);
  static const int maxSosPerDay = 5;

  // Map
  static const double defaultLat = 16.8661; // Yangon
  static const double defaultLng = 96.1951;
  static const double defaultZoom = 14.0;
}

// https://khunyikalsal-production.up.railway.app