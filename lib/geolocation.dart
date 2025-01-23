import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'location.dart';

// We use the OpenStreetMap API for geocoding and reverse geocoding
Future<dynamic> makeOpenStreetMapRequest({
  required String path,
  Map<String, dynamic>? queryParams,
}) async {
  try {
    // Convert all special types in the query parameters to strings to avoid errors such as this:
    // type 'int' is not a subtype of type 'Iterable<dynamic>'
    if (queryParams != null) {
      queryParams =
          queryParams.map((key, value) => MapEntry(key, value.toString()))
              as Map<String, dynamic>;
    }

    // Get the current language code from the locale to pass to the API
    final language = Intl.getCurrentLocale().split('_').first;

    // Create the request with the base URL, path, query parameters, and headers
    final request = http.Request(
        'GET',
        Uri.https('nominatim.openstreetmap.org', path, {
          if (queryParams != null) ...queryParams,
          'format': 'geojson',
          'addressdetails': '1',
          'accept-language': language,
        }))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'MyApp/1.0 (https://my.app)',
      })
      ..followRedirects = false
      ..persistentConnection = false;

    print('Requesting: ${request.url}');

    // Send the request and get the StreamedResponse with a timeout
    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('Request timed out');
    });

    // Convert the StreamedResponse into a complete response
    final http.Response response =
        await http.Response.fromStream(streamedResponse);

    // Check the response status and handle accordingly
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final ContentType? contentType = response.headers['content-type'] != null
          ? ContentType.parse(response.headers['content-type']!)
          : null;
      // Check if the response is JSON
      if (contentType?.mimeType == 'application/json') {
        // Expect the response to have a JSON body
        final data = jsonDecode(response.body);
        // Check if the JSON body has an error field
        if (data is Map && data.containsKey('error')) {
          throw Exception('Server error: ${data['error']}');
        } else {
          return data;
        }
      }
    } else {
      throw HttpException('Server error: ${response.statusCode}');
    }
    // Catch possible specific exceptions
  } on TimeoutException {
    throw Exception('Request timed out');
  } on SocketException {
    throw Exception('No internet connection');
  } on HttpException catch (error) {
    throw Exception('Request error: $error');
  } on FormatException {
    throw Exception('Bad response format');
  } catch (error) {
    throw Exception('Error: $error');
  }
}

// Call the OpenStreetMap API to search for locations
// https://nominatim.org/release-docs/latest/api/Search/#free-form-query
Future<List<Location>> searchLocation(String query) async {
  try {
    final data = await makeOpenStreetMapRequest(
      path: 'search',
      queryParams: {
        'q': query,
        'limit': 10,
      },
    );
    // Convert the JSON data into a list of Location objects
    if (data is Map && data.containsKey('features')) {
      final results = List<Map<String, dynamic>>.from(data['features'])
          .map((result) => Location.fromGeoJson(result))
          .toList();
      return results;
    } else {
      return [];
    }
  } catch (error) {
    throw Exception('Error searching for location: $error');
  }
}

// The reverse endpoint returns exactly one result or an error when the coordinate is in an area with no OSM data coverage:
// https://nominatim.org/release-docs/latest/api/Reverse/
Future<Location?> getLocationByCoordinates(
    {required double latitude, required double longitude}) async {
  try {
    final data = await makeOpenStreetMapRequest(
      path: 'reverse',
      queryParams: {
        'lat': latitude,
        'lon': longitude,
      },
    );
    if (data is Map && data.containsKey('features')) {
      final results = List<Map<String, dynamic>>.from(data['features']);
      if (results.isNotEmpty) {
        return Location.fromGeoJson(results.first);
      }
    }
    return null;
  } catch (error) {
    throw Exception('Error getting location from coordinates: $error');
  }
}

// Use the user's locale to get the country code and search for the location
// https://nominatim.org/release-docs/latest/api/Search/#structured-query
Future<Location?> getLocationByLocale() async {
  try {
    final countryCode = Intl.getCurrentLocale().split('_').last;
    final data = await makeOpenStreetMapRequest(
      path: 'search',
      queryParams: {
        'country': countryCode,
      },
    );
    if (data is Map && data.containsKey('features')) {
      final results = List<Map<String, dynamic>>.from(data['features']);
      if (results.isNotEmpty) {
        return Location.fromGeoJson(results.first);
      }
    }
    return null;
  } catch (error) {
    throw Exception('Error getting location from country code: $error');
  }
}

// This function follows the example from the Geolocator package:
// https://pub.dev/packages/geolocator/example
Future<Location> getCurrentLocation() async {
  bool locationServiceEnabled;
  LocationPermission locationPermission;

  // Check if location services are enabled.
  locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!locationServiceEnabled) {
    // Location services are not enabled, request user to enable location services.
    return Future.error('Location services are disabled.');
  }

  locationPermission = await Geolocator.checkPermission();
  if (locationPermission == LocationPermission.denied) {
    locationPermission = await Geolocator.requestPermission();
    if (locationPermission == LocationPermission.denied) {
      // Permissions are denied, you could request permissions again here.
      return Future.error('Location permissions are denied.');
    }
  }

  if (locationPermission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are denied permanently. Please enable them in settings.');
  }

  try {
    // At this point we have permissions and location services are enabled
    final Position position = await Geolocator.getCurrentPosition();
    // Try to get the location from the coordinates
    final Location? location = await getLocationByCoordinates(
        latitude: position.latitude, longitude: position.longitude);
    if (location != null) {
      return location;
    } else {
      return Location(latitude: position.latitude, longitude: position.longitude);
    }
  } catch (error) {
    throw Exception('Error getting current location: $error');
  }
}

Future<Location?> getLastKnownLocation() async {
  try {
    final Position? position = await Geolocator.getLastKnownPosition();
    if (position != null) {
      final Location? location = await getLocationByCoordinates(
          latitude: position.latitude, longitude: position.longitude);
      return location;
    } else {
      return null;
    }
  } catch (error) {
    return null;
  }
}
