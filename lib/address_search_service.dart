import 'dart:convert';

import 'package:http/http.dart' as http;

import 'address_place.dart';
import 'places_config.dart';

/// Address search: Google Places when configured, else OpenStreetMap Nominatim.
class AddressSearchService {
  AddressSearchService._();

  static final AddressSearchService instance = AddressSearchService._();

  static const _nominatimUserAgent = 'CareSignal/1.0 (caregiver support app)';

  Future<List<AddressPlace>> search(
    String query, {
    String? zipCode,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    if (isGooglePlacesConfigured) {
      final places = await _searchGooglePlaces(trimmed, zipCode: zipCode);
      if (places.isNotEmpty) return places;
    }

    return _searchNominatim(trimmed, zipCode: zipCode);
  }

  /// Fills lat/lng (and formatted address) for a Places prediction or typed text.
  Future<AddressPlace?> resolvePlace(AddressPlace place) async {
    if (place.isEmpty) return null;
    if (place.hasCoordinates && place.placeId == null) return place;

    if (isGooglePlacesConfigured) {
      final placeId = place.placeId?.trim();
      if (placeId != null && placeId.isNotEmpty) {
        final detailed = await _placeDetails(placeId);
        if (detailed != null) return detailed;
      }
      final geocoded = await _geocodeGoogle(place.formattedAddress);
      if (geocoded != null) return geocoded;
    }

    final results = await _searchNominatim(place.formattedAddress);
    return results.isNotEmpty ? results.first : place;
  }

  Future<List<AddressPlace>> _searchGooglePlaces(
    String query, {
    String? zipCode,
  }) async {
    final key = googlePlacesApiKeyOrNull;
    if (key == null) return [];

    var input = query;
    if (zipCode != null && zipCode.length == 5) {
      input = '$query, $zipCode';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': input,
        'types': 'address',
        'components': 'country:us',
        'key': key,
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return [];
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        return [];
      }

      final predictions = data['predictions'];
      if (predictions is! List) return [];

      return predictions
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final description =
                (item['description'] as String?)?.trim() ?? '';
            final placeId = (item['place_id'] as String?)?.trim();
            return AddressPlace(
              formattedAddress: description,
              placeId: placeId,
            );
          })
          .where((place) => place.formattedAddress.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<AddressPlace?> _placeDetails(String placeId) async {
    final key = googlePlacesApiKeyOrNull;
    if (key == null) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'formatted_address,geometry',
        'key': key,
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return null;
      }
      final result = data['result'];
      if (result is! Map<String, dynamic>) return null;

      final formatted =
          (result['formatted_address'] as String?)?.trim() ?? '';
      final location = result['geometry'] is Map<String, dynamic>
          ? (result['geometry'] as Map<String, dynamic>)['location']
          : null;
      final lat = location is Map<String, dynamic>
          ? (location['lat'] as num?)?.toDouble()
          : null;
      final lng = location is Map<String, dynamic>
          ? (location['lng'] as num?)?.toDouble()
          : null;

      if (formatted.isEmpty) return null;
      return AddressPlace(
        formattedAddress: formatted,
        latitude: lat,
        longitude: lng,
        placeId: placeId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AddressPlace?> _geocodeGoogle(String address) async {
    final key = googlePlacesApiKeyOrNull;
    if (key == null) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': address,
        'components': 'country:US',
        'key': key,
      },
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['status'] != 'OK') {
        return null;
      }
      final results = data['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map<String, dynamic>) return null;

      final formatted =
          (first['formatted_address'] as String?)?.trim() ?? address;
      final location = first['geometry'] is Map<String, dynamic>
          ? (first['geometry'] as Map<String, dynamic>)['location']
          : null;
      final lat = location is Map<String, dynamic>
          ? (location['lat'] as num?)?.toDouble()
          : null;
      final lng = location is Map<String, dynamic>
          ? (location['lng'] as num?)?.toDouble()
          : null;

      return AddressPlace(
        formattedAddress: formatted,
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<AddressPlace>> _searchNominatim(
    String query, {
    String? zipCode,
  }) async {
    var q = query;
    if (zipCode != null && zipCode.length == 5) {
      q = '$query, $zipCode, USA';
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
        headers: const {'User-Agent': _nominatimUserAgent},
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
