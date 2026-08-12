class EmergencyModel {
  final String id;
  final String userId;
  final String type;
  final String status;
  final String? assignedOrgId;
  final String? assignedVolunteerId;
  final double locationLat;
  final double locationLng;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmergencyModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    this.assignedOrgId,
    this.assignedVolunteerId,
    required this.locationLat,
    required this.locationLng,
    required this.createdAt,
    this.updatedAt,
  });

  factory EmergencyModel.fromJson(Map<String, dynamic> json) {
    return EmergencyModel(
      id: json['id'] ?? json['emergency_id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'pending',
      assignedOrgId: json['assigned_org_id'],
      assignedVolunteerId: json['assigned_volunteer_id'],
      locationLat: (json['location_lat'] ?? 0).toDouble(),
      locationLng: (json['location_lng'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';

  String get typeIcon {
    switch (type) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'crime':
        return '🚨';
      default:
        return '⚠️';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'fire':
        return 'Fire';
      case 'medical':
        return 'Medical';
      case 'crime':
        return 'Crime';
      default:
        return 'Emergency';
    }
  }
}
