import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/weather_model.dart';
import '../../providers/settings_provider.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';

class WeatherDisasterScreen extends ConsumerStatefulWidget {
  const WeatherDisasterScreen({super.key});

  @override
  ConsumerState<WeatherDisasterScreen> createState() => _WeatherDisasterScreenState();
}

class _WeatherDisasterScreenState extends ConsumerState<WeatherDisasterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _weatherService = WeatherService();

  WeatherSnapshot? _weather;
  List<DisasterAlert> _alerts = [];
  List<SafetyGuide> _safetyGuides = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedCategory = 'ALL'; // 'ALL', 'CYCLONE', 'EARTHQUAKE', 'FLOOD', 'GUIDES'
  String _locationName = 'Yangon, Myanmar';
  double _currentLat = 16.8661;
  double _currentLon = 96.1951;

  final Set<String> _checkedGoBagItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final pos = await LocationService.getCurrentLocation();
      _currentLat = pos.latitude;
      _currentLon = pos.longitude;

      // Approximate township / region name based on lat/lon
      _locationName = _getTownshipName(_currentLat, _currentLon);

      final weatherFuture = _weatherService.getCurrentWeather(lat: _currentLat, lon: _currentLon);
      final alertsFuture = _weatherService.getDisasterAlerts(lat: _currentLat, lon: _currentLon);
      final guidesFuture = _weatherService.getSafetyGuides();

      final results = await Future.wait([weatherFuture, alertsFuture, guidesFuture]);

      if (mounted) {
        setState(() {
          _weather = results[0] as WeatherSnapshot;
          _alerts = results[1] as List<DisasterAlert>;
          _safetyGuides = results[2] as List<SafetyGuide>;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  String _getTownshipName(double lat, double lon) {
    if ((lat - 16.8).abs() < 0.5 && (lon - 96.15).abs() < 0.5) {
      return 'Yangon (ရန်ကုန်)';
    } else if ((lat - 21.97).abs() < 0.5 && (lon - 96.08).abs() < 0.5) {
      return 'Mandalay (မန္တလေး)';
    } else if ((lat - 19.74).abs() < 0.5 && (lon - 96.12).abs() < 0.5) {
      return 'Naypyitaw (နေပြည်တော်)';
    } else if ((lat - 20.15).abs() < 0.5 && (lon - 92.9).abs() < 0.5) {
      return 'Sittwe / Rakhine (စစ်တွေ/ရခိုင်)';
    } else if ((lat - 16.48).abs() < 0.5 && (lon - 97.62).abs() < 0.5) {
      return 'Mawlamyine / Mon (မော်လမြိုင်/မွန်)';
    } else if ((lat - 16.98).abs() < 0.5 && (lon - 94.54).abs() < 0.5) {
      return 'Pathein / Ayeyarwady (ပုသိမ်/ဧရာဝတီ)';
    }
    return '${lat.toStringAsFixed(2)}°N, ${lon.toStringAsFixed(2)}°E';
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {}
  }

  List<DisasterAlert> get _filteredAlerts {
    if (_selectedCategory == 'ALL') return _alerts;
    return _alerts.where((a) => a.type == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasCriticalAlert = _alerts.any((a) => a.severity == 'CRITICAL');

    return Scaffold(
      body: _isLoading
          ? _buildLoadingState(isDark, isMm)
          : RefreshIndicator(
              onRefresh: () => _loadAllData(silent: true),
              color: AppTheme.primaryRed,
              child: CustomScrollView(
                slivers: [
                  // ── Dynamic Atmospheric Header ─────────────────────────────
                  _buildAtmosphericAppBar(isDark, isMm, hasCriticalAlert),

                  // ── Navigation Sub-Tabs ───────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      tabBar: TabBar(
                        controller: _tabController,
                        labelColor: isDark ? Colors.white : AppTheme.primaryRed,
                        unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
                        indicatorColor: AppTheme.primaryRed,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.wb_sunny_outlined, size: 20),
                            text: isMm ? 'နေ့စဉ် မိုးလေဝသ' : 'Daily Weather',
                          ),
                          Tab(
                            icon: Badge(
                              isLabelVisible: _alerts.isNotEmpty,
                              label: Text('${_alerts.length}'),
                              backgroundColor: hasCriticalAlert ? Colors.red : Colors.orange,
                              child: const Icon(Icons.warning_amber_rounded, size: 20),
                            ),
                            text: isMm ? 'ဘေးအန္တရာယ် သတိပေးချက်' : 'Disaster Radar',
                          ),
                          Tab(
                            icon: const Icon(Icons.health_and_safety_outlined, size: 20),
                            text: isMm ? 'ကာကွယ်ရေး လမ်းညွှန်' : 'Safety Protocols',
                          ),
                        ],
                      ),
                      bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    ),
                  ),

                  // ── Tab Contents ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        switch (_tabController.index) {
                          case 0:
                            return _buildWeatherTab(isDark, isMm);
                          case 1:
                            return _buildDisastersTab(isDark, isMm);
                          case 2:
                            return _buildSafetyGuidesTab(isDark, isMm);
                          default:
                            return _buildWeatherTab(isDark, isMm);
                        }
                      },
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Atmospheric App Bar ──────────────────────────────────────────────────
  Widget _buildAtmosphericAppBar(bool isDark, bool isMm, bool hasCriticalAlert) {
    final w = _weather;
    final isDay = w?.isDay ?? true;
    final weatherType = w?.iconType ?? 'clear';

    // Select dynamic background gradient
    List<Color> gradientColors;
    if (hasCriticalAlert) {
      gradientColors = isDark
          ? [const Color(0xFF7F1D1D), const Color(0xFF450A0A), const Color(0xFF0F172A)]
          : [const Color(0xFFDC2626), const Color(0xFF991B1B), const Color(0xFF7F1D1D)];
    } else if (!isDay) {
      gradientColors = [
        const Color(0xFF0B192C),
        const Color(0xFF1E3E62),
        const Color(0xFF000000),
      ];
    } else if (weatherType == 'storm' || weatherType == 'heavy_rain') {
      gradientColors = [
        const Color(0xFF1E293B),
        const Color(0xFF334155),
        const Color(0xFF0F172A),
      ];
    } else if (weatherType == 'rain') {
      gradientColors = [
        const Color(0xFF0284C7),
        const Color(0xFF0369A1),
        const Color(0xFF0C4A6E),
      ];
    } else {
      gradientColors = [
        const Color(0xFF2563EB),
        const Color(0xFF3B82F6),
        const Color(0xFF60A5FA),
      ];
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: gradientColors.first,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      actions: [
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded, color: Colors.white),
          tooltip: isMm ? 'လက်ရှိနေရာ ပြန်လည်ရယူရန်' : 'Refresh GPS Location',
          onPressed: () => _loadAllData(silent: true),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Location and Alert Badge
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _locationName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasCriticalAlert)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white70),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isMm ? 'ပြင်းထန်သတိပေးချက်' : 'CRITICAL ALERT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Main Temperature and Weather Icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${w?.temperature.toStringAsFixed(0) ?? "--"}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'C',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _getWeatherIconWidget(w?.iconType ?? 'sunny', size: 52),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Condition Text & Feels Like
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMm ? (w?.conditionMy ?? 'ကြည်လင်သည်') : (w?.conditionEn ?? 'Clear Sky'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${isMm ? "ခံစားရမှု" : "Feels like"} ${w?.apparentTemperature.toStringAsFixed(0) ?? "--"}°C',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getWeatherIconWidget(String type, {double size = 32}) {
    IconData iconData;
    Color color = Colors.white;

    switch (type) {
      case 'clear':
        iconData = Icons.wb_sunny_rounded;
        color = Colors.amber;
        break;
      case 'cloudy':
      case 'partly_cloudy':
        iconData = Icons.cloud_queue_rounded;
        break;
      case 'rain':
        iconData = Icons.water_drop_rounded;
        color = Colors.lightBlueAccent;
        break;
      case 'heavy_rain':
        iconData = Icons.grain_rounded;
        color = Colors.cyanAccent;
        break;
      case 'storm':
      case 'severe_storm':
        iconData = Icons.thunderstorm_rounded;
        color = Colors.amberAccent;
        break;
      case 'snow':
        iconData = Icons.ac_unit_rounded;
        break;
      case 'fog':
        iconData = Icons.foggy;
        break;
      default:
        iconData = Icons.wb_sunny_rounded;
    }

    return Icon(iconData, size: size, color: color);
  }

  // ── 1. Daily Weather Tab ─────────────────────────────────────────────────
  Widget _buildWeatherTab(bool isDark, bool isMm) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Urgent Disaster Banner (If any) ───────────────────────────
          if (_alerts.isNotEmpty) _buildTopEmergencyBanner(isDark, isMm),

          // ── Current Weather Metrics Grid ──────────────────────────────
          _buildMetricsGrid(cardBg, cardBorder, textPrimary, textSecondary, isMm),
          const SizedBox(height: 20),

          // ── 24-Hour Hourly Forecast ───────────────────────────────────
          Text(
            isMm ? '၂၄ နာရီအတွင်း မိုးလေဝသ ခန့်မှန်းချက်' : '24-Hour Hourly Forecast',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          _buildHourlyForecastList(cardBg, cardBorder, textPrimary, textSecondary),
          const SizedBox(height: 24),

          // ── 7-Day Daily Forecast ──────────────────────────────────────
          Text(
            isMm ? '၇ ရက်တာ မိုးလေဝသ ခန့်မှန်းချက်' : '7-Day Extended Forecast',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 10),
          _buildDailyForecastList(cardBg, cardBorder, textPrimary, textSecondary, isMm),
          const SizedBox(height: 24),

          // ── Environmental & Flood Awareness ────────────────────────────
          _buildEnvironmentalCard(cardBg, cardBorder, textPrimary, textSecondary, isMm),
        ],
      ),
    );
  }

  Widget _buildTopEmergencyBanner(bool isDark, bool isMm) {
    final topAlert = _alerts.first;
    return GestureDetector(
      onTap: () => _tabController.animateTo(1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: topAlert.displayColor.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: topAlert.displayColor.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: topAlert.displayColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: topAlert.displayColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          topAlert.severity,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isMm ? topAlert.titleMy : topAlert.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMm ? topAlert.actionAdviceMy : topAlert.actionAdviceEn,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
  ) {
    final w = _weather;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _metricTile(
          icon: Icons.water_drop_outlined,
          iconColor: Colors.blue,
          title: isMm ? 'မိုးရွာနိုင်ခြေ' : 'Precipitation',
          value: '${w?.precipitationProbability ?? 0}%',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        _metricTile(
          icon: Icons.air_rounded,
          iconColor: Colors.teal,
          title: isMm ? 'လေတိုက်နှုန်း' : 'Wind Speed',
          value: '${w?.windSpeed.toStringAsFixed(1) ?? "0"} km/h',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        _metricTile(
          icon: Icons.wb_sunny_outlined,
          iconColor: Colors.orange,
          title: isMm ? 'ခရမ်းလွန်ရောင်ခြည်' : 'UV Index',
          value: '${w?.uvIndex.toStringAsFixed(1) ?? "0"} (${_getUvRating(w?.uvIndex ?? 0, isMm)})',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        _metricTile(
          icon: Icons.opacity_rounded,
          iconColor: Colors.indigo,
          title: isMm ? 'စိုထိုင်းဆ' : 'Humidity',
          value: '${w?.humidity ?? 0}%',
          cardBg: cardBg,
          cardBorder: cardBorder,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ],
    );
  }

  String _getUvRating(double uv, bool isMm) {
    if (uv <= 2) return isMm ? 'နိမ့်' : 'Low';
    if (uv <= 5) return isMm ? 'အသင့်အတင့်' : 'Moderate';
    if (uv <= 7) return isMm ? 'မြင့်' : 'High';
    if (uv <= 10) return isMm ? 'အလွန်မြင့်' : 'Very High';
    return isMm ? 'အန္တရာယ်ရှိ' : 'Extreme';
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecastList(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final hourly = _weather?.hourlyForecast ?? [];
    if (hourly.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const Text('No hourly data available'),
      );
    }

    return SizedBox(
      height: 125,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hourly.length,
        itemBuilder: (context, index) {
          final item = hourly[index];
          String hourLabel = item.time;
          try {
            final dt = DateTime.parse(item.time);
            hourLabel = DateFormat('ha').format(dt);
          } catch (_) {}

          return Container(
            width: 72,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  index == 0 ? 'Now' : hourLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                _getWeatherIconWidget(item.isDay ? 'clear' : 'cloudy', size: 24),
                Text(
                  '${item.temperature.toStringAsFixed(0)}°',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                if (item.precipitationProbability > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_drop, size: 10, color: Colors.blue),
                      Text(
                        '${item.precipitationProbability}%',
                        style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyForecastList(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
  ) {
    final daily = _weather?.dailyForecast ?? [];
    if (daily.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: daily.map((day) {
          String dayName = day.date;
          try {
            final dt = DateTime.parse(day.date);
            dayName = DateFormat('EEE, MMM d').format(dt);
          } catch (_) {}

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _getWeatherIconWidget('clear', size: 20),
                const SizedBox(width: 12),
                if (day.precipitationProbability > 10)
                  SizedBox(
                    width: 44,
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop, size: 12, color: Colors.blue),
                        Text(
                          '${day.precipitationProbability}%',
                          style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 44),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${day.minTemp.toStringAsFixed(0)}°',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                      const SizedBox(width: 8),
                      // Mini temperature bar
                      Container(
                        width: 55,
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.orange],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${day.maxTemp.toStringAsFixed(0)}°',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEnvironmentalCard(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
  ) {
    final w = _weather;
    final aqi = w?.airQualitySummary['aqi'] ?? 40;
    final aqiStatus = isMm
        ? (w?.airQualitySummary['status_my'] ?? 'ကောင်းမွန်သည်')
        : (w?.airQualitySummary['status_en'] ?? 'Good');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              Text(
                isMm ? 'လေထုနှင့် ရေကြီးမှု အညွှန်းကိန်း' : 'Air Quality & Flood Indicator',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMm ? 'လေထုအရည်အသွေး (AQI)' : 'Air Quality Index',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$aqi',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            aqiStatus,
                            style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMm ? 'ရေကြီးနိုင်ခြေ အဆင့်' : 'Flood Risk Index',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      w?.floodRiskLevel ?? 'LOW',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: w?.floodRiskLevel == 'HIGH' ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Natural Disaster Alerts & Radar Tab ────────────────────────────────
  Widget _buildDisastersTab(bool isDark, bool isMm) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    final alerts = _filteredAlerts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('ALL', isMm ? 'အားလုံး' : 'All Hazards', isDark),
                const SizedBox(width: 8),
                _filterChip('CYCLONE', isMm ? 'မုန်တိုင်း' : 'Storms & Cyclones', isDark),
                const SizedBox(width: 8),
                _filterChip('EARTHQUAKE', isMm ? 'ငလျင်ဘေး' : 'Earthquakes', isDark),
                const SizedBox(width: 8),
                _filterChip('FLOOD', isMm ? 'ရေကြီးမှု' : 'Flood Alerts', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (alerts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 14),
                  Text(
                    isMm ? 'လက်ရှိတွင် ပြင်းထန်သော သဘာဝဘေး သတိပေးချက် မရှိပါ' : 'No Critical Natural Disaster Alerts in Region',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMm
                        ? 'USGS ငလျင်နှင့် GDACS မုန်တိုင်း/ရေကြီးမှု စနစ်များမှ ပုံမှန်စောင့်ကြည့်နေပါသည်။'
                        : 'Real-time seismic feeds & global hazard coordination are actively monitoring.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildDisasterAlertCard(alert, cardBg, cardBorder, textPrimary, textSecondary, isMm, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String category, String label, bool isDark) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryRed,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = category);
      },
    );
  }

  Widget _buildDisasterAlertCard(
    DisasterAlert alert,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
    bool isDark,
  ) {
    final alertColor = alert.displayColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: alertColor.withValues(alpha: isDark ? 0.4 : 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Severity and Distance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(alert.iconData, color: alertColor, size: 20),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: alertColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    alert.severity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                if (alert.distanceKm != null && alert.distanceKm! > 0)
                  Text(
                    '${alert.distanceKm!.toStringAsFixed(0)} km away',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMm ? alert.titleMy : alert.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isMm ? alert.descriptionMy : alert.description,
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                ),
                const SizedBox(height: 12),

                // Action Advice Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isMm ? alert.actionAdviceMy : alert.actionAdviceEn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Source and Timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Source: ${alert.source}',
                      style: TextStyle(fontSize: 10, color: textSecondary.withValues(alpha: 0.8)),
                    ),
                    Text(
                      _formatAlertTime(alert.timestamp),
                      style: TextStyle(fontSize: 10, color: textSecondary.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAlertTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  // ── 3. Emergency Safety Protocols & Survival Guide Tab ────────────────────
  Widget _buildSafetyGuidesTab(bool isDark, bool isMm) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Emergency Hotlines Quick Dial ──────────────────────────────
          _buildHotlinesCard(cardBg, cardBorder, textPrimary, textSecondary, isMm),
          const SizedBox(height: 20),

          // ── Go-Bag Interactive Checklist ──────────────────────────────
          _buildGoBagCard(cardBg, cardBorder, textPrimary, textSecondary, isMm),
          const SizedBox(height: 24),

          // ── Multi-Hazard Survival Protocols Accordion ─────────────────
          Text(
            isMm ? 'သဘာဝဘေးအန္တရာယ် အသက်ရှင်ရေး လမ်းညွှန်များ' : 'Disaster Preparedness Manuals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 12),

          ..._safetyGuides.map((guide) => _buildGuideAccordion(guide, cardBg, cardBorder, textPrimary, textSecondary, isMm)),
        ],
      ),
    );
  }

  Widget _buildHotlinesCard(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFF880E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isMm ? 'အရေးပေါ် ဖုန်းနံပါတ်များ (၁ ချက်နှိပ် ခေါ်ဆိုရန်)' : 'Emergency Response Hotlines',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _hotlineButton('191', isMm ? 'မီးသတ်/ကယ်ဆယ်' : 'Fire/Rescue'),
              const SizedBox(width: 8),
              _hotlineButton('192', isMm ? 'လူနာတင်ယာဉ်' : 'Ambulance'),
              const SizedBox(width: 8),
              _hotlineButton('199', isMm ? 'ရဲတပ်ဖွဲ့' : 'Police'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hotlineButton(String number, String label) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _makePhoneCall(number),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoBagCard(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
  ) {
    final items = [
      isMm ? 'သောက်ရေသန့် (တစ်ဦးလျှင် အနည်းဆုံး ၃ လီတာ)' : 'Clean drinking water (3L per person)',
      isMm ? 'အရေးကြီး မှတ်ပုံတင်စာရွက်စာတမ်းများ (ရေလုံအိတ်)' : 'Official ID cards & documents in waterproof pouch',
      isMm ? 'ရှေးဦးသူနာပြုစုနည်း ဆေးဝါးသေတ္တာ' : 'Emergency first-aid medical kit',
      isMm ? 'အားကောင်းသော ဓာတ်မီး၊ ပါဝါဘဏ်နှင့် လေချွန်ခရာ' : 'High-powered flashlight, power bank & whistle',
      isMm ? 'အသင့်စား ခြောက်သွေ့ အစားအစာများ (၃ ရက်စာ)' : 'Non-perishable ready-to-eat dry rations',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.backpack_outlined, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMm ? 'အရေးပေါ် ပြောင်းရွှေ့အိတ် (Go-Bag Checklist)' : 'Emergency Evacuation Go-Bag',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ),
              Text(
                '${_checkedGoBagItems.length}/${items.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            final isChecked = _checkedGoBagItems.contains(item);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _checkedGoBagItems.remove(item);
                  } else {
                    _checkedGoBagItems.add(item);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isChecked ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12,
                          color: isChecked ? textSecondary : textPrimary,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGuideAccordion(
    SafetyGuide guide,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    bool isMm,
  ) {
    Color guideColor = Colors.blue;
    try {
      guideColor = Color(int.parse(guide.color));
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: guideColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shield_outlined, color: guideColor, size: 22),
          ),
          title: Text(
            isMm ? guide.titleMy : guide.titleEn,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          subtitle: Text(
            isMm ? guide.summaryMy : guide.summaryEn,
            style: TextStyle(fontSize: 11, color: textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _guideSection(
                    title: isMm ? '၁။ မဖြစ်ပွားမီ ကြိုတင်ပြင်ဆင်ရန် (Before)' : '1. Preparedness (Before)',
                    steps: isMm ? guide.beforeStepsMy : guide.beforeStepsEn,
                    color: Colors.green,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 10),
                  _guideSection(
                    title: isMm ? '၂။ ဖြစ်ပွားနေစဉ် လိုက်နာရန် (During)' : '2. Action Protocols (During)',
                    steps: isMm ? guide.duringStepsMy : guide.duringStepsEn,
                    color: Colors.orange,
                    textPrimary: textPrimary,
                  ),
                  const SizedBox(height: 10),
                  _guideSection(
                    title: isMm ? '၃။ ဖြစ်ပွားပြီးနောက် ဆောင်ရန်/ရှောင်ရန် (After)' : '3. Recovery & Safety (After)',
                    steps: isMm ? guide.afterStepsMy : guide.afterStepsEn,
                    color: Colors.blue,
                    textPrimary: textPrimary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideSection({
    required String title,
    required List<String> steps,
    required Color color,
    required Color textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(fontSize: 12, color: textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark, bool isMm) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryRed),
            const SizedBox(height: 16),
            Text(
              isMm ? 'ရာသီဥတုနှင့် သဘာဝဘေး အချက်အလက်များ ရယူနေပါသည်...' : 'Fetching Live Weather & Disaster Radar...',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;

  _TabBarDelegate({required this.tabBar, required this.bgColor});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bgColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
