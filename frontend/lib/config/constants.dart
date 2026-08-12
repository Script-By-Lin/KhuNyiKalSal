class AppConstants {
  static const String appName = 'Khu Nyi Kal Sal';

  // API — using ADB reverse port forwarding (127.0.0.1:8000)
  static const String apiBaseUrl = 'http://127.0.0.1:8000/api';
  static const String wsBaseUrl = 'ws://127.0.0.1:8000/ws';

  // SOS
  static const Duration sosHoldDuration = Duration(seconds: 3);
  static const int maxSosPerDay = 5;

  // Map
  static const double defaultLat = 16.8661; // Yangon
  static const double defaultLng = 96.1951;
  static const double defaultZoom = 14.0;
}
