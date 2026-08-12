class OrganizationModel {
  final String accountId;
  final String orgName;
  final String phoneNumber;
  final double geoLat;
  final double geoLng;
  final String category;
  final double coverageRadiusKm;
  final bool isActive;
  final double? distanceKm;

  OrganizationModel({
    required this.accountId,
    required this.orgName,
    required this.phoneNumber,
    required this.geoLat,
    required this.geoLng,
    this.category = 'Medical',
    this.coverageRadiusKm = 50.0,
    this.isActive = true,
    this.distanceKm,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      accountId: json['account_id'] ?? '',
      orgName: json['org_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      geoLat: (json['geo_lat'] ?? 0).toDouble(),
      geoLng: (json['geo_lng'] ?? 0).toDouble(),
      category: json['category'] ?? 'Medical',
      coverageRadiusKm: (json['coverage_radius_km'] ?? 50).toDouble(),
      isActive: json['is_active'] ?? true,
      distanceKm: json['distance_km']?.toDouble(),
    );
  }
}
