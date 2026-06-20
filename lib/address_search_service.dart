import 'dart:convert';

import 'package:http/http.dart' as http;

import 'address_place.dart';

/// OpenStreetMap Nominatim search (no API key; demo-friendly).
class AddressSearchService {
  AddressSearchService._();

  static final AddressSearchService instance = AddressSearchService._();

  static const _userAgent = 'CareSignal/1.0 (caregiver support app)';

  Future<List<AddressPlace>> search(
    String query, {
    String? zipCode,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    var q = trimmed;
    if (zipCode != null && zipCode.length == 5) {
      q = '$trimmed, $zipCode, USA';
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': q,
        'format': 'json',
        'addressdetails': '1',
        'limit': '6',
        'countrycodes': 'us',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data is! List) return [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => AddressPlace(
              formattedAddress: (item['display_name'] as String?)?.trim() ?? '',
              latitude: double.tryParse('${item['lat']}'),
              longitude: double.tryParse('${item['lon']}'),
            ),
          )
          .where((place) => place.formattedAddress.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
