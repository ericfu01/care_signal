import 'package:url_launcher/url_launcher.dart';

import 'address_place.dart';

Future<bool> openUberRide({
  AddressPlace? pickup,
  AddressPlace? destination,
}) async {
  final pickupValue = _rideParam(pickup);
  final destinationValue = _rideParam(destination);

  if (pickup?.hasCoordinates == true) {
    final params = <String, String>{
      'action': 'setPickup',
      'pickup[latitude]': '${pickup!.latitude}',
      'pickup[longitude]': '${pickup.longitude}',
    };
    if (destination?.hasCoordinates == true) {
      params['dropoff[latitude]'] = '${destination!.latitude}';
      params['dropoff[longitude]'] = '${destination.longitude}';
    } else if (destinationValue != null) {
      params['dropoff[formatted_address]'] = destinationValue;
    }
    final appUri = Uri.parse('uber://?${Uri(queryParameters: params).query}');
    if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  }

  final query = <String, String>{};
  if (pickupValue != null) query['pickup'] = pickupValue;
  if (destinationValue != null) query['drop[0]'] = destinationValue;

  final uri = query.isEmpty
      ? Uri.parse('https://m.uber.com/looking')
      : Uri.https('m.uber.com', '/looking', query);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openLyftRide({
  AddressPlace? pickup,
  AddressPlace? destination,
}) async {
  final pickupParam = _rideParam(pickup);
  final destinationParam = _rideParam(destination);

  if (pickup?.hasCoordinates == true) {
    final params = <String, String>{
      'id': 'lyft',
      'pickup[latitude]': '${pickup!.latitude}',
      'pickup[longitude]': '${pickup.longitude}',
    };
    if (destination?.hasCoordinates == true) {
      params['destination[latitude]'] = '${destination!.latitude}';
      params['destination[longitude]'] = '${destination.longitude}';
    } else if (destinationParam != null) {
      params['destination'] = destinationParam;
    }
    final appUri =
        Uri.parse('lyft://ridetype?${Uri(queryParameters: params).query}');
    if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  }

  final Uri webUri;
  if (pickupParam != null && destinationParam != null) {
    webUri = Uri.parse(
      'https://lyft.com/ride?pickup=${Uri.encodeComponent(pickupParam)}'
      '&destination=${Uri.encodeComponent(destinationParam)}',
    );
  } else if (pickupParam != null) {
    webUri = Uri.parse(
      'https://lyft.com/ride?pickup=${Uri.encodeComponent(pickupParam)}',
    );
  } else {
    webUri = Uri.parse('https://www.lyft.com/rider');
  }
  return launchUrl(webUri, mode: LaunchMode.externalApplication);
}

String? _rideParam(AddressPlace? place) {
  if (place == null || place.isEmpty) return null;
  if (place.hasCoordinates) {
    return '${place.latitude},${place.longitude}';
  }
  return place.formattedAddress;
}
