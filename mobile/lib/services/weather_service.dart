import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_model.dart';
import 'api_service.dart';
import 'location_service.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _cachedWeatherKey = 'cached_weather_snapshot';
  static const String _cachedAlertsKey = 'cached_disaster_alerts';

  /// Fetches real-time weather and 7-day forecast with GPS auto-detection & caching
  Future<WeatherSnapshot> getCurrentWeather({double? lat, double? lon}) async {
    double targetLat = lat ?? 16.8661;
    double targetLon = lon ?? 96.1951;

    if (lat == null || lon == null) {
      try {
        final pos = await LocationService.getCurrentLocation();
        targetLat = pos.latitude;
        targetLon = pos.longitude;
      } catch (_) {}
    }

    try {
      final res = await ApiService().dio.get(
        '/weather/current',
        queryParameters: {'lat': targetLat, 'lon': targetLon},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );

      if (res.statusCode == 200 && res.data != null) {
        final snapshot = WeatherSnapshot.fromJson(res.data as Map<String, dynamic>);
        _cacheWeatherData(res.data);
        return snapshot;
      }
    } catch (_) {
      // Fallback 1: Try direct Open-Meteo call if backend proxy is down
      try {
        final directSnapshot = await _fetchDirectOpenMeteo(targetLat, targetLon);
        return directSnapshot;
      } catch (_) {}
    }

    // Fallback 2: Load last known cached snapshot
    final cached = await _getCachedWeather();
    if (cached != null) return cached;

    // Fallback 3: Return clean default
    return WeatherSnapshot(
      latitude: targetLat,
      longitude: targetLon,
      timezone: 'Asia/Yangon',
      temperature: 31.0,
      apparentTemperature: 34.0,
      humidity: 70,
      weatherCode: 2,
      conditionEn: 'Partly cloudy',
      conditionMy: 'တိမ်အသင့်အတင့် ဖြစ်ထွန်းသည်',
      iconType: 'partly_cloudy',
      windSpeed: 11.2,
      windDirection: 190,
      uvIndex: 6.0,
      precipitation: 0.0,
      precipitationProbability: 15,
      surfacePressure: 1011.0,
      isDay: true,
      hourlyForecast: [],
      dailyForecast: [],
      floodRiskLevel: 'LOW',
      airQualitySummary: {'aqi': 40, 'status_en': 'Good', 'status_my': 'ကောင်းမွန်ပါသည်'},
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }

  /// Fetches real-time disaster alerts (earthquakes, cyclones, floods) with caching
  Future<List<DisasterAlert>> getDisasterAlerts({double? lat, double? lon}) async {
    double targetLat = lat ?? 16.8661;
    double targetLon = lon ?? 96.1951;

    if (lat == null || lon == null) {
      try {
        final pos = await LocationService.getCurrentLocation();
        targetLat = pos.latitude;
        targetLon = pos.longitude;
      } catch (_) {}
    }

    try {
      final res = await ApiService().dio.get(
        '/weather/disasters',
        queryParameters: {'lat': targetLat, 'lon': targetLon},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );

      if (res.statusCode == 200 && res.data is List) {
        final alerts = (res.data as List)
            .map((e) => DisasterAlert.fromJson(e as Map<String, dynamic>))
            .toList();
        _cacheAlertsData(res.data);
        return alerts;
      }
    } catch (_) {
      // Fallback 1: Direct USGS Earthquakes
      try {
        final directAlerts = await _fetchDirectUSGS(targetLat, targetLon);
        if (directAlerts.isNotEmpty) return directAlerts;
      } catch (_) {}
    }

    // Fallback 2: Cached alerts
    final cached = await _getCachedAlerts();
    if (cached.isNotEmpty) return cached;

    return [];
  }

  /// Fetches safety guides (with offline fallback)
  Future<List<SafetyGuide>> getSafetyGuides() async {
    try {
      final res = await ApiService().dio.get(
        '/weather/safety-guides',
        options: Options(receiveTimeout: const Duration(seconds: 6)),
      );

      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => SafetyGuide.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Offline hardcoded guides
    return _getOfflineSafetyGuides();
  }

  // ── Helpers & Direct Fallbacks ───────────────────────────────────────────

  Future<WeatherSnapshot> _fetchDirectOpenMeteo(double lat, double lon) async {
    final dio = Dio();
    final res = await dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'apparent_temperature',
          'is_day',
          'precipitation',
          'weather_code',
          'surface_pressure',
          'wind_speed_10m',
          'wind_direction_10m',
        ],
        'hourly': [
          'temperature_2m',
          'precipitation_probability',
          'weather_code',
          'wind_speed_10m',
          'is_day',
          'uv_index',
        ],
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_probability_max',
          'sunrise',
          'sunset',
          'uv_index_max',
        ],
        'timezone': 'auto',
        'forecast_days': 7,
      },
    );

    final data = res.data;
    final current = data['current'] ?? {};
    final hourly = data['hourly'] ?? {};
    final daily = data['daily'] ?? {};

    final List<HourlyForecast> hourlyItems = [];
    final times = hourly['time'] as List? ?? [];
    final temps = hourly['temperature_2m'] as List? ?? [];
    final precip = hourly['precipitation_probability'] as List? ?? [];
    final codes = hourly['weather_code'] as List? ?? [];
    final winds = hourly['wind_speed_10m'] as List? ?? [];
    final isDays = hourly['is_day'] as List? ?? [];

    for (int i = 0; i < (times.length > 24 ? 24 : times.length); i++) {
      final code = (codes[i] as num?)?.toInt() ?? 0;
      hourlyItems.add(HourlyForecast(
        time: times[i].toString(),
        temperature: (temps[i] as num?)?.toDouble() ?? 0.0,
        precipitationProbability: (precip[i] as num?)?.toInt() ?? 0,
        weatherCode: code,
        conditionEn: 'Weather condition',
        conditionMy: 'ရာသီဥတု အခြေအနေ',
        windSpeed: (winds[i] as num?)?.toDouble() ?? 0.0,
        isDay: isDays[i] == 1 || isDays[i] == true,
      ));
    }

    final List<DailyForecast> dailyItems = [];
    final dTimes = daily['time'] as List? ?? [];
    final dMax = daily['temperature_2m_max'] as List? ?? [];
    final dMin = daily['temperature_2m_min'] as List? ?? [];
    final dPrecip = daily['precipitation_probability_max'] as List? ?? [];
    final dCodes = daily['weather_code'] as List? ?? [];
    final dSunrise = daily['sunrise'] as List? ?? [];
    final dSunset = daily['sunset'] as List? ?? [];
    final dUv = daily['uv_index_max'] as List? ?? [];

    for (int i = 0; i < (dTimes.length > 7 ? 7 : dTimes.length); i++) {
      final code = (dCodes[i] as num?)?.toInt() ?? 0;
      dailyItems.add(DailyForecast(
        date: dTimes[i].toString(),
        maxTemp: (dMax[i] as num?)?.toDouble() ?? 0.0,
        minTemp: (dMin[i] as num?)?.toDouble() ?? 0.0,
        precipitationProbability: (dPrecip[i] as num?)?.toInt() ?? 0,
        weatherCode: code,
        conditionEn: 'Forecast',
        conditionMy: 'ခန့်မှန်းချက်',
        sunrise: dSunrise.length > i ? dSunrise[i].toString() : '',
        sunset: dSunset.length > i ? dSunset[i].toString() : '',
        uvIndexMax: dUv.length > i ? (dUv[i] as num?)?.toDouble() ?? 5.0 : 5.0,
      ));
    }

    return WeatherSnapshot(
      latitude: lat,
      longitude: lon,
      timezone: data['timezone']?.toString() ?? 'Asia/Yangon',
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 30.0,
      apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ?? 32.0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 65,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      conditionEn: 'Atmospheric update',
      conditionMy: 'လက်ရှိ ရာသီဥတု',
      iconType: 'partly_cloudy',
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0,
      windDirection: (current['wind_direction_10m'] as num?)?.toInt() ?? 0,
      uvIndex: 5.0,
      precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
      precipitationProbability: hourlyItems.isNotEmpty ? hourlyItems[0].precipitationProbability : 10,
      surfacePressure: (current['surface_pressure'] as num?)?.toDouble() ?? 1012.0,
      isDay: current['is_day'] == 1 || current['is_day'] == true,
      hourlyForecast: hourlyItems,
      dailyForecast: dailyItems,
      floodRiskLevel: 'LOW',
      airQualitySummary: {'aqi': 35, 'status_en': 'Good', 'status_my': 'ကောင်းမွန်ပါသည်'},
      lastUpdated: DateTime.now().toIso8601String(),
    );
  }

  Future<List<DisasterAlert>> _fetchDirectUSGS(double lat, double lon) async {
    final dio = Dio();
    final res = await dio.get('https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson');
    final List<DisasterAlert> alerts = [];
    final features = res.data['features'] as List? ?? [];

    for (var f in features) {
      final props = f['properties'] ?? {};
      final geom = f['geometry'] ?? {};
      final coords = geom['coordinates'] as List? ?? [0, 0, 0];
      final eqLon = (coords[0] as num).toDouble();
      final eqLat = (coords[1] as num).toDouble();
      final depth = coords.length > 2 ? (coords[2] as num).toDouble() : 10.0;
      final mag = (props['mag'] as num?)?.toDouble() ?? 0.0;
      final place = props['place']?.toString() ?? 'Earthquake';

      final distKm = LocationService.calculateDistance(lat, lon, eqLat, eqLon) / 1000.0;

      if (distKm <= 2000 || mag >= 5.5) {
        final isCritical = mag >= 6.0 || (mag >= 4.5 && distKm < 300);
        alerts.add(DisasterAlert(
          id: 'usgs-${props['code'] ?? 'eq'}',
          type: 'EARTHQUAKE',
          title: 'M${mag.toStringAsFixed(1)} Earthquake — $place',
          titleMy: 'ပြင်းအား ${mag.toStringAsFixed(1)} ငလျင် — $place',
          description: 'Magnitude $mag at depth ${depth.toStringAsFixed(1)} km, approx ${distKm.toStringAsFixed(0)} km away.',
          descriptionMy: 'ပြင်းအား $mag ငလျင်သည် သင်ရှိရာမှ ${distKm.toStringAsFixed(0)} km အကွာတွင် လှုပ်ခတ်ခဲ့ပါသည်။',
          severity: isCritical ? 'CRITICAL' : (mag >= 4.5 ? 'WARNING' : 'ADVISORY'),
          alertColor: isCritical ? 'RED' : (mag >= 4.5 ? 'ORANGE' : 'YELLOW'),
          latitude: eqLat,
          longitude: eqLon,
          distanceKm: distKm,
          magnitude: mag,
          depthKm: depth,
          timestamp: DateTime.fromMillisecondsSinceEpoch(props['time'] ?? 0).toIso8601String(),
          source: 'USGS Seismology',
          actionAdviceEn: 'Drop, Cover, and Hold On.',
          actionAdviceMy: 'ဝပ်ပါ၊ အကာအကွယ်ယူပါ၊ မြဲမြံစွာကိုင်ထားပါ။',
        ));
      }
    }
    return alerts;
  }

  // ── Cache Handlers ───────────────────────────────────────────────────────

  Future<void> _cacheWeatherData(dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedWeatherKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<WeatherSnapshot?> _getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cachedWeatherKey);
      if (str != null) {
        return WeatherSnapshot.fromJson(jsonDecode(str));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheAlertsData(dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedAlertsKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<List<DisasterAlert>> _getCachedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cachedAlertsKey);
      if (str != null) {
        final list = jsonDecode(str) as List;
        return list.map((e) => DisasterAlert.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  List<SafetyGuide> _getOfflineSafetyGuides() {
    return [
      SafetyGuide(
        id: 'cyclone',
        hazardType: 'CYCLONE',
        titleEn: 'Cyclone & Severe Tropical Storm',
        titleMy: 'မုန်တိုင်းနှင့် လေပြင်းဘေး အန္တရာယ်',
        icon: 'cyclone',
        color: '0xFF0288D1',
        summaryEn: 'Vital safety measures before, during, and after tropical cyclones.',
        summaryMy: 'မုန်တိုင်းတိုက်ခတ်ခြင်းနှင့် ပြင်းထန်သော လေပြင်းဘေးမှ အသက်အန္တရာယ် ကင်းရှင်းရေး။',
        beforeStepsEn: [
          'Reinforce doors, windows, and roof sheets.',
          'Store at least 3 days of clean drinking water and non-perishable food.',
          'Keep flashlight, whistle, power banks, and portable radio ready.',
        ],
        beforeStepsMy: [
          'အိမ်ခေါင်မိုး၊ ပြတင်းပေါက်နှင့် တံခါးများကို ကြံ့ခိုင်အောင် ပြုပြင်ပါ။',
          'အနည်းဆုံး ၃ ရက်စာ သောက်ရေသန့်နှင့် စားနပ်ရိက္ခာ စုဆောင်းထားပါ။',
          'လက်နှိပ်ဓာတ်မီး၊ လေချွန်ခရာ၊ ပါဝါဘဏ်များကို အသင့်ပြင်ဆင်ပါ။',
        ],
        duringStepsEn: [
          'Stay indoors away from exterior windows and glass doors.',
          'Disconnect main electrical breaker and gas valves.',
          'Do NOT venture outside during the eye of the storm.',
        ],
        duringStepsMy: [
          'အိမ်တွင်း၌သာနေပြီး ပြတင်းပေါက်မှန်များနှင့် ဝေးရာတွင် နေပါ။',
          'အဓိက လျှပ်စစ်မိန်းနှင့် ဂတ်စ်အိုးများကို ပိတ်ထားပါ။',
          'မုန်တိုင်းဗဟိုချက်ဖြတ်သန်းချိန် လေငြိမ်သွားသော်လည်း အပြင်မထွက်ပါနှင့်။',
        ],
        afterStepsEn: [
          'Watch out for live dangling electrical wires.',
          'Boil drinking water before consumption.',
        ],
        afterStepsMy: [
          'ပြတ်ကျနေသော လျှပ်စစ်ကြိုးများကို အထူးသတိပြုပါ။',
          'သောက်ရေကို ကျိုချက်ပြီးမှ သောက်သုံးပါ။',
        ],
        emergencyContacts: [
          {'name': 'Fire & Rescue (မီးသတ်)', 'number': '191'},
          {'name': 'Ambulance (လူနာတင်ယာဉ်)', 'number': '192'},
          {'name': 'Red Cross (ကြက်ခြေနီ)', 'number': '01-383680'},
        ],
        goBagItemsEn: ['Bottled water', 'First-aid kit', 'LED flashlight', 'ID documents in waterproof pouch'],
        goBagItemsMy: ['သောက်ရေသန့်', 'ရှေးဦးသူနာပြုစုနည်းအိတ်', 'ဓာတ်မီး', 'ရေလုံအိတ်ထဲမှ မှတ်ပုံတင်စာရွက်စာတမ်းများ'],
      ),
      SafetyGuide(
        id: 'earthquake',
        hazardType: 'EARTHQUAKE',
        titleEn: 'Earthquake Drop, Cover & Hold',
        titleMy: 'ငလျင်ဘေး အရေးပေါ် အသက်ရှင်နည်း',
        icon: 'earthquake',
        color: '0xFFE65100',
        summaryEn: 'Critical survival procedures during sudden seismic shaking.',
        summaryMy: 'ငလျင်လှုပ်ခတ်စဉ် ထိခိုက်ဒဏ်ရာ မရရှိစေရန် ဝပ်၊ ကာ၊ ကိုင် အသက်ရှင်နည်းလမ်းများ။',
        beforeStepsEn: ['Secure heavy furniture and tall shelving to walls.', 'Identify safe shelter spots in every room.'],
        beforeStepsMy: ['လေးလံသော ပရိဘောဂများကို နံရံတွင် မြဲမြံစွာ တွဲချည်ပါ။', 'အခန်းတိုင်းတွင် လုံခြုံသော စားပွဲအောက်နေရာ သတ်မှတ်ထားပါ။'],
        duringStepsEn: ['DROP to hands and knees.', 'COVER head and neck under sturdy desk.', 'HOLD ON until shaking stops.'],
        duringStepsMy: ['ချက်ချင်း ကြမ်းပြင်ပေါ်သို့ ဝပ်ချပါ။ (DROP)', 'စားပွဲအောက်သို့ဝင်၍ ဦးခေါင်းကို အုပ်ကာပါ (COVER)', 'လှုပ်ခတ်မှုရပ်သည်အထိ စားပွဲခြေကို ကိုင်ထားပါ (HOLD ON)'],
        afterStepsEn: ['Expect aftershocks.', 'Check for gas leaks and hazards.', 'Exit cautiously via stairs, never elevators.'],
        afterStepsMy: ['နောက်ဆက်တွဲငလျင်များ ဆက်လက်လှုပ်နိုင်သဖြင့် သတိရှိပါ။', 'ဂတ်စ်ယိုစိမ့်မှု စစ်ဆေးပါ။', 'ဓာတ်လှေကား မသုံးဘဲ ရိုးရိုးလှေကားဖြင့် ထွက်ပါ။'],
        emergencyContacts: [
          {'name': 'Fire & Rescue (မီးသတ်)', 'number': '191'},
          {'name': 'Police (ရဲတပ်ဖွဲ့)', 'number': '199'},
        ],
        goBagItemsEn: ['Dust masks', 'Work gloves', 'Thermal blanket', 'Flashlight & whistle'],
        goBagItemsMy: ['နှာခေါင်းစည်း', 'လက်အိတ်ထူထူ', 'အအေးဒဏ်ကာစောင်', 'ဓာတ်မီးနှင့် လေချွန်ခရာ'],
      ),
    ];
  }
}
