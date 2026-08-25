import 'package:flutter/material.dart';

class HourlyForecast {
  final String time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;
  final String conditionEn;
  final String conditionMy;
  final double windSpeed;
  final bool isDay;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.conditionEn,
    required this.conditionMy,
    required this.windSpeed,
    required this.isDay,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: json['time']?.toString() ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      precipitationProbability: (json['precipitation_probability'] as num?)?.toInt() ?? 0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      conditionEn: json['condition_en']?.toString() ?? 'Clear',
      conditionMy: json['condition_my']?.toString() ?? 'ကြည်လင်သည်',
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      isDay: json['is_day'] as bool? ?? true,
    );
  }
}

class DailyForecast {
  final String date;
  final double maxTemp;
  final double minTemp;
  final int precipitationProbability;
  final int weatherCode;
  final String conditionEn;
  final String conditionMy;
  final String sunrise;
  final String sunset;
  final double uvIndexMax;

  const DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationProbability,
    required this.weatherCode,
    required this.conditionEn,
    required this.conditionMy,
    required this.sunrise,
    required this.sunset,
    required this.uvIndexMax,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: json['date']?.toString() ?? '',
      maxTemp: (json['max_temp'] as num?)?.toDouble() ?? 0.0,
      minTemp: (json['min_temp'] as num?)?.toDouble() ?? 0.0,
      precipitationProbability: (json['precipitation_probability'] as num?)?.toInt() ?? 0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      conditionEn: json['condition_en']?.toString() ?? 'Clear',
      conditionMy: json['condition_my']?.toString() ?? 'ကြည်လင်သည်',
      sunrise: json['sunrise']?.toString() ?? '',
      sunset: json['sunset']?.toString() ?? '',
      uvIndexMax: (json['uv_index_max'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class WeatherSnapshot {
  final double latitude;
  final double longitude;
  final String timezone;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final int weatherCode;
  final String conditionEn;
  final String conditionMy;
  final String iconType;
  final double windSpeed;
  final int windDirection;
  final double uvIndex;
  final double precipitation;
  final int precipitationProbability;
  final double surfacePressure;
  final bool isDay;
  final List<HourlyForecast> hourlyForecast;
  final List<DailyForecast> dailyForecast;
  final String floodRiskLevel; // 'LOW', 'MODERATE', 'HIGH', 'SEVERE'
  final Map<String, dynamic> airQualitySummary;
  final String lastUpdated;

  const WeatherSnapshot({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.conditionEn,
    required this.conditionMy,
    required this.iconType,
    required this.windSpeed,
    required this.windDirection,
    required this.uvIndex,
    required this.precipitation,
    required this.precipitationProbability,
    required this.surfacePressure,
    required this.isDay,
    required this.hourlyForecast,
    required this.dailyForecast,
    required this.floodRiskLevel,
    required this.airQualitySummary,
    required this.lastUpdated,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 16.8661,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 96.1951,
      timezone: json['timezone']?.toString() ?? 'Asia/Yangon',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 30.0,
      apparentTemperature: (json['apparent_temperature'] as num?)?.toDouble() ?? 32.0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 65,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      conditionEn: json['condition_en']?.toString() ?? 'Clear Sky',
      conditionMy: json['condition_my']?.toString() ?? 'ကြည်လင်သော မိုးကောင်းကင်',
      iconType: json['icon_type']?.toString() ?? 'sunny',
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 10.0,
      windDirection: (json['wind_direction'] as num?)?.toInt() ?? 0,
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 5.0,
      precipitation: (json['precipitation'] as num?)?.toDouble() ?? 0.0,
      precipitationProbability: (json['precipitation_probability'] as num?)?.toInt() ?? 10,
      surfacePressure: (json['surface_pressure'] as num?)?.toDouble() ?? 1012.0,
      isDay: json['is_day'] as bool? ?? true,
      hourlyForecast: (json['hourly_forecast'] as List<dynamic>?)
              ?.map((e) => HourlyForecast.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyForecast: (json['daily_forecast'] as List<dynamic>?)
              ?.map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      floodRiskLevel: json['flood_risk_level']?.toString() ?? 'LOW',
      airQualitySummary: json['air_quality_summary'] as Map<String, dynamic>? ?? {},
      lastUpdated: json['last_updated']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

class DisasterAlert {
  final String id;
  final String type; // 'EARTHQUAKE', 'CYCLONE', 'FLOOD', 'TSUNAMI', 'HEATWAVE', 'OFFICIAL_ANNOUNCEMENT'
  final String title;
  final String titleMy;
  final String description;
  final String descriptionMy;
  final String severity; // 'CRITICAL', 'WARNING', 'ADVISORY'
  final String alertColor; // 'RED', 'ORANGE', 'YELLOW', 'GREEN'
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final double? magnitude;
  final double? depthKm;
  final double? windSpeedKmh;
  final String timestamp;
  final String source;
  final String actionAdviceEn;
  final String actionAdviceMy;

  const DisasterAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.titleMy,
    required this.description,
    required this.descriptionMy,
    required this.severity,
    required this.alertColor,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.magnitude,
    this.depthKm,
    this.windSpeedKmh,
    required this.timestamp,
    required this.source,
    required this.actionAdviceEn,
    required this.actionAdviceMy,
  });

  factory DisasterAlert.fromJson(Map<String, dynamic> json) {
    return DisasterAlert(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'DISASTER',
      title: json['title']?.toString() ?? 'Disaster Advisory',
      titleMy: json['title_my']?.toString() ?? 'သဘာဝဘေး သတိပေးချက်',
      description: json['description']?.toString() ?? '',
      descriptionMy: json['description_my']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'ADVISORY',
      alertColor: json['alert_color']?.toString() ?? 'YELLOW',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      magnitude: (json['magnitude'] as num?)?.toDouble(),
      depthKm: (json['depth_km'] as num?)?.toDouble(),
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble(),
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      source: json['source']?.toString() ?? 'EOC',
      actionAdviceEn: json['action_advice_en']?.toString() ?? '',
      actionAdviceMy: json['action_advice_my']?.toString() ?? '',
    );
  }

  Color get displayColor {
    switch (alertColor) {
      case 'RED':
        return const Color(0xFFD32F2F);
      case 'ORANGE':
        return const Color(0xFFE65100);
      case 'YELLOW':
        return const Color(0xFFF57F17);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  IconData get iconData {
    switch (type) {
      case 'EARTHQUAKE':
        return Icons.vibration;
      case 'CYCLONE':
        return Icons.cyclone;
      case 'FLOOD':
        return Icons.flood_outlined;
      case 'TSUNAMI':
        return Icons.tsunami_outlined;
      case 'HEATWAVE':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}

class SafetyGuide {
  final String id;
  final String hazardType;
  final String titleEn;
  final String titleMy;
  final String icon;
  final String color;
  final String summaryEn;
  final String summaryMy;
  final List<String> beforeStepsEn;
  final List<String> beforeStepsMy;
  final List<String> duringStepsEn;
  final List<String> duringStepsMy;
  final List<String> afterStepsEn;
  final List<String> afterStepsMy;
  final List<Map<String, String>> emergencyContacts;
  final List<String> goBagItemsEn;
  final List<String> goBagItemsMy;

  const SafetyGuide({
    required this.id,
    required this.hazardType,
    required this.titleEn,
    required this.titleMy,
    required this.icon,
    required this.color,
    required this.summaryEn,
    required this.summaryMy,
    required this.beforeStepsEn,
    required this.beforeStepsMy,
    required this.duringStepsEn,
    required this.duringStepsMy,
    required this.afterStepsEn,
    required this.afterStepsMy,
    required this.emergencyContacts,
    required this.goBagItemsEn,
    required this.goBagItemsMy,
  });

  factory SafetyGuide.fromJson(Map<String, dynamic> json) {
    return SafetyGuide(
      id: json['id']?.toString() ?? '',
      hazardType: json['hazard_type']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      titleMy: json['title_my']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'warning',
      color: json['color']?.toString() ?? '0xFF1976D2',
      summaryEn: json['summary_en']?.toString() ?? '',
      summaryMy: json['summary_my']?.toString() ?? '',
      beforeStepsEn: (json['before_steps_en'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      beforeStepsMy: (json['before_steps_my'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      duringStepsEn: (json['during_steps_en'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      duringStepsMy: (json['during_steps_my'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      afterStepsEn: (json['after_steps_en'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      afterStepsMy: (json['after_steps_my'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      emergencyContacts: (json['emergency_contacts'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      goBagItemsEn: (json['go_bag_items_en'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      goBagItemsMy: (json['go_bag_items_my'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
