/// A geocoded street address for rides and volunteer requests.
class AddressPlace {
  const AddressPlace({
    required this.formattedAddress,
    this.label,
    this.latitude,
    this.longitude,
  });

  final String formattedAddress;
  final String? label;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayLabel =>
      label != null && label!.trim().isNotEmpty
          ? label!.trim()
          : formattedAddress;

  String get subtitle =>
      label != null && label!.trim().isNotEmpty ? formattedAddress : '';

  Map<String, dynamic> toMap() => {
        'formatted': formattedAddress,
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  factory AddressPlace.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AddressPlace(formattedAddress: '');
    }
    final formatted = (map['formatted'] as String?)?.trim() ?? '';
    return AddressPlace(
      formattedAddress: formatted,
      label: map['label'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  bool get isEmpty => formattedAddress.trim().isEmpty;
}
