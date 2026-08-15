import 'package:url_launcher/url_launcher.dart';
import 'offline_service.dart';

class SMSDispatchService {
  // National Emergency Hotlines in Myanmar
  static const String hotlineFire = '192';
  static const String hotlineAmbulance = '191';
  static const String hotlinePolice = '199';
  static const String hotlineRedCross = '01383680';

  static Future<bool> makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String buildEmergencySMSBody({
    required String emergencyType,
    required double lat,
    required double lng,
    String? victimName,
    String? bloodType,
    String? medicalConditions,
  }) {
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    final typeLabel = emergencyType.toUpperCase();
    final name = victimName?.isNotEmpty == true ? victimName : 'Citizen';
    final blood = bloodType?.isNotEmpty == true ? bloodType : 'Unknown';
    final med = medicalConditions?.isNotEmpty == true ? medicalConditions : 'None';

    return '[EMERGENCY SOS - KHU NYI KAL SAL]\n'
        'TYPE: $typeLabel EMERGENCY\n'
        'VICTIM: $name (Blood: $blood)\n'
        'CONDITIONS: $med\n'
        'GPS: $lat, $lng\n'
        'MAP: $mapsUrl\n'
        'Please send urgent emergency assistance!';
  }

  static Future<bool> sendEmergencySMS({
    required String phoneNumber,
    required String emergencyType,
    required double lat,
    required double lng,
    String? victimName,
    String? bloodType,
    String? medicalConditions,
  }) async {
    final body = buildEmergencySMSBody(
      emergencyType: emergencyType,
      lat: lat,
      lng: lng,
      victimName: victimName,
      bloodType: bloodType,
      medicalConditions: medicalConditions,
    );

    final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');
    if (cleanedPhone.isEmpty) return false;

    // Primary: Standard sms URI with query parameter
    try {
      final uri = Uri(
        scheme: 'sms',
        path: cleanedPhone,
        queryParameters: <String, String>{'body': body},
      );
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      }
    } catch (_) {}

    // Fallback 1: Direct encoded sms: URI
    try {
      final encodedBody = Uri.encodeComponent(body);
      final fallbackUri = Uri.parse('sms:$cleanedPhone?body=$encodedBody');
      final ok = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}

    // Fallback 2: smsto: scheme (widely supported on Samsung/Xiaomi/Oppo devices)
    try {
      final encodedBody = Uri.encodeComponent(body);
      final smstoUri = Uri.parse('smsto:$cleanedPhone?body=$encodedBody');
      final ok = await launchUrl(smstoUri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}

    // Fallback 3: Launch SMS app with just the number if body is too long for intent
    try {
      final plainSmsUri = Uri(scheme: 'sms', path: cleanedPhone);
      return await launchUrl(plainSmsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> dispatchBroadcastSMS({
    required String emergencyType,
    required double lat,
    required double lng,
    String? targetPhoneNumber,
  }) async {
    final profile = await OfflineService().getCachedUserProfile();
    final cachedOrgs = await OfflineService().getCachedOrganizations();
    final contacts = await OfflineService().getCachedEmergencyContacts();

    final victimName = profile?['full_name'] as String?;
    final bloodType = profile?['blood_type'] as String?;
    final medicalConditions = profile?['medical_conditions'] as String?;

    String targetPhone = '';

    // 1. If explicit phone provided, use it
    if (targetPhoneNumber != null && targetPhoneNumber.trim().isNotEmpty) {
      targetPhone = targetPhoneNumber.trim();
    } 
    // 2. Use nearest/matching cached local organization
    else if (cachedOrgs.isNotEmpty) {
      // Try to find matching category first
      final matching = cachedOrgs.firstWhere(
        (o) {
          final cat = (o['category'] ?? '').toString().toLowerCase();
          final name = (o['org_name'] ?? '').toString().toLowerCase();
          final etype = emergencyType.toLowerCase().replaceAll(' ', '_');
          if (etype == 'fire') return cat.contains('fire') || name.contains('fire') || name.contains('မီးသတ်');
          if (etype == 'medical' || etype == 'accident') return cat.contains('medical') || name.contains('medical') || name.contains('ဆေး') || name.contains('hospital') || name.contains('ambulance');
          if (etype == 'natural_disaster' || etype == 'disaster') return cat.contains('fire') || cat.contains('voluntary') || cat.contains('volunteer') || name.contains('ကယ်ဆယ်') || name.contains('rescue');
          return true;
        },
        orElse: () => cachedOrgs.first,
      );

      final orgPhone = matching['phone_number'] ?? matching['phone'] ?? '';
      if (orgPhone.toString().trim().isNotEmpty) {
        targetPhone = orgPhone.toString().trim();
      }
    }

    // 3. If still empty, check cached emergency contacts
    if (targetPhone.isEmpty && contacts.isNotEmpty) {
      final firstContactPhone = contacts.first['phone_number'] ?? contacts.first['phone'] ?? '';
      if (firstContactPhone.toString().trim().isNotEmpty) {
        targetPhone = firstContactPhone.toString().trim();
      }
    }

    if (targetPhone.isEmpty) {
      return false;
    }

    return await sendEmergencySMS(
      phoneNumber: targetPhone,
      emergencyType: emergencyType,
      lat: lat,
      lng: lng,
      victimName: victimName,
      bloodType: bloodType,
      medicalConditions: medicalConditions,
    );
  }
}
