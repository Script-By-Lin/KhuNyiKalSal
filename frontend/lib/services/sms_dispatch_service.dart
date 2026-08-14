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
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
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
    final uri = Uri(
      scheme: 'sms',
      path: cleanedPhone,
      queryParameters: <String, String>{'body': body},
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  static Future<bool> dispatchBroadcastSMS({
    required String emergencyType,
    required double lat,
    required double lng,
  }) async {
    final profile = await OfflineService().getCachedUserProfile();
    final contacts = await OfflineService().getCachedEmergencyContacts();

    final victimName = profile?['full_name'] as String?;
    final bloodType = profile?['blood_type'] as String?;
    final medicalConditions = profile?['medical_conditions'] as String?;

    // Determine target recipient (first contact or hotline)
    String targetPhone = hotlineAmbulance;
    if (contacts.isNotEmpty) {
      final firstPhone = contacts.first['phone_number'] ?? contacts.first['phone'];
      if (firstPhone != null && firstPhone.toString().isNotEmpty) {
        targetPhone = firstPhone.toString();
      }
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
