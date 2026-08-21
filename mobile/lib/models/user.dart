class UserModel {
  final String id;
  final String email;
  final String role;
  final bool isActive;
  final String? fullName;
  final String? phoneNumber;
  final String? bloodType;
  final String? medicalConditions;
  final List<Map<String, dynamic>>? emergencyContacts;
  final double? locationLat;
  final double? locationLng;
  final bool isSuspended;
  final String? suspendedUntil;
  final int remainingSuspensionSeconds;
  final int suspensionCount;
  final String? suspensionReason;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.isActive = true,
    this.fullName,
    this.phoneNumber,
    this.bloodType,
    this.medicalConditions,
    this.emergencyContacts,
    this.locationLat,
    this.locationLng,
    this.isSuspended = false,
    this.suspendedUntil,
    this.remainingSuspensionSeconds = 0,
    this.suspensionCount = 0,
    this.suspensionReason,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['account_id'] ?? json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['is_active'] ?? true,
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      bloodType: json['blood_type'],
      medicalConditions: json['medical_conditions'],
      emergencyContacts: json['emergency_contacts'] != null
          ? List<Map<String, dynamic>>.from(json['emergency_contacts'])
          : null,
      locationLat: json['location_lat']?.toDouble(),
      locationLng: json['location_lng']?.toDouble(),
      isSuspended: json['is_suspended'] ?? false,
      suspendedUntil: json['suspended_until'],
      remainingSuspensionSeconds: json['remaining_suspension_seconds'] ?? 0,
      suspensionCount: json['suspension_count'] ?? 0,
      suspensionReason: json['suspension_reason'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'blood_type': bloodType,
        'medical_conditions': medicalConditions,
        'emergency_contacts': emergencyContacts,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'is_suspended': isSuspended,
        'suspended_until': suspendedUntil,
        'remaining_suspension_seconds': remainingSuspensionSeconds,
        'suspension_count': suspensionCount,
        'suspension_reason': suspensionReason,
      };
}
