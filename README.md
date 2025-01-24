# Free-Tier Mapping and Location Search in Flutter
## Create Stunning Maps and Seamless Location Search in Flutter — For Free!

### Synopsis

Integrating mapping and location search into apps can be a significant hurdle for startups. Many popular services involve complex setups, confusing pricing, and can quickly become expensive.

Startups need easy-to-implement, cost-effective solutions that allow them to experiment and refine their app without the fear of accruing significant mapping expenses.

This article guides you through building a professional-looking and user-friendly location search widget in Flutter. We’ll explore how to leverage the power of free-tier mapping to create a superb user experience.

### Example App

Here’s what we’ll be building:

![Flutter Location Search](flutter_location_search.gif)

Let’s consider the basic requirements for our app:

* Display a basic interactive map (e.g., using a free-tier mapping service like Mapbox or Leaflet).
* Allow users to pan and zoom the map.
* Allow users to recenter on the previously selected location after map movements.
* Allow users to see their current location (with user permission).
* Allow users to search for a location, select a search result, and show it on the map marked by a location pin.
* When a location pin is tapped, display location details in a bottom sheet.
* Allow users to open the currently selected location in the default maps app.

### Flutter Map

The [Flutter Map](https://docs.fleaflet.dev) package leverages the power of [Leaflet](https://leafletjs.com) maps to bring interactive maps to your Flutter applications. This open-source package provides a rich and highly customizable feature set.

While Flutter Map is commonly used with Leaflet maps, it’s designed to be agnostic to the underlying map provider. This flexibility allows developers to potentially integrate with other mapping services like Mapbox.

Install the Flutter Map package:

```
flutter pub add flutter_map
```

### Flutter Geolocator

The [Flutter Geolocator](https://pub.dev/packages/geolocator) package simplifies location services within your Flutter apps. It provides access to device location data, including current position and location updates.

Geolocator supports various providers, offers options for permission handling, and enhances user privacy, making it essential for building location-aware applications.

Install the [Geolocator](https://pub.dev/packages/geolocator/install) package:

```
flutter pub add geolocator
```

We also need to add location permissions in order for it to work.

For iOS, add this to `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location when open.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location when in the background.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location when open and in the background.</string>
```

For Android, add this to `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```

### LatLong Library

The [LatLong](https://pub.dev/packages/latlong2) package is a lightweight library for performing common geospatial calculations in Dart. It provides a simple and intuitive API for working with geographical coordinates (latitude and longitude).

It enables developers to easily calculate distances between points, determine bearings, and perform other essential geospatial operations, and is extensively used by Flutter Map.

Install the [LatLong](https://pub.dev/packages/latlong2/install) package:

```
flutter pub add latlong2
```

### Location Class

The `Location` class serves as a model to encapsulate location details within our application. This class is broadly based the [GeoJSON](https://datatracker.ietf.org/doc/html/rfc7946) standard, providing a standardized way to represent and exchange location data.

Note that `Location` model leverages the [Equatable](https://pub.dev/packages/equatable) package, allowing for efficient comparison to other locations. This simplifies tasks like identifying duplicates and optimizing location related logic.

```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:equatable/equatable.dart';

// Our Locaiton model class combines data from OpenStreetMap GeoJSON and LatLng coordinates
// At the very least, we need the latitude and longitude of a location, hence they are required
class Location {
  Location({
    required this.latitude,
    required this.longitude,
    this.borough,
    this.bounds,
    this.city,
    this.country,
    this.countryCode,
    this.displayName,
    this.houseNumber,
    this.municipality,
    this.name,
    this.neighbourhood,
    this.postcode,
    this.road,
    this.state,
    this.suburb,
  });

  final LatLngBounds? bounds;
  final String? borough;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? displayName;
  final String? houseNumber;
  final double latitude;
  final double longitude;
  final String? municipality;
  final String? name;
  final String? neighbourhood;
  final String? postcode;
  final String? road;
  final String? state;
  final String? suburb;

  LatLng get latLng => LatLng(latitude, longitude);

  // Make it possible for Equatable to compare two Location objects
  @override
  List<Object?> get props => [
        borough,
        bounds,
        city,
        country,
        countryCode,
        displayName,
        houseNumber,
        latitude,
        longitude,
        municipality,
        name,
        neighbourhood,
        postcode,
        road,
        state,
        suburb,
      ];

  factory Location.fromGeoJson(Map<String, dynamic> geoJson) {
    // We assume that the GeoJSON data always has the same structure
    // so we don't apply any checks here, but you should do it in a real app
    final address = geoJson['properties']['address'];
    final bounds = List<double>.from(geoJson['bbox']);
    // Longitude precedes latitude in GeoJSON
    final latLngBounds = LatLngBounds(
        LatLng(
          bounds[1],
          bounds[0],
        ),
        LatLng(
          bounds[3],
          bounds[2],
        ));

    return Location(
      bounds: latLngBounds,
      city: address['city'],
      country: address['country'],
      countryCode: address['country_code'],
      displayName: geoJson['properties']['display_name'],
      houseNumber: address['house_number'],
      latitude: geoJson['geometry']['coordinates'][1],
      longitude: geoJson['geometry']['coordinates'][0],
      name: geoJson['properties']['name'],
      neighbourhood: address['neighbourhood'],
      postcode: address['postcode'],
      road: address['road'],
      state: address['state'],
      suburb: address['suburb'],
    );
  }

  @override
  String toString() {
    return displayName ?? name ?? '$latitude, $longitude';
  }
}
```

### Geolocation Class

The `Geolocation` class encapsulates the core logic for accessing and handling location data. This class is also responsible for making network requests to the geolocation service.

Note that every request must include a `User-Agent` header. This header identifies your application to the server, preventing requests from being rejected by the [Nominatim](https://nominatim.org/release-docs/latest/api/Overview/) server.

```dart
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
    // Imperatively convert all query params to strings to avoid type errors
    if (queryParams != null) {
      queryParams =
          queryParams.map((key, value) => MapEntry(key, value.toString()))
              as Map<String, dynamic>;
    }

    // Pass the user's locale to the API to get the results in the correct language
    final language = Intl.getCurrentLocale().split('_').first;

    // Create a request object with the OpenStreetMap API URL and parameters
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
    // print('Requesting: ${request.url}');

    // Send the request and get the StreamedResponse with a timeout
    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('Request timed out');
    });

    // Convert the StreamedResponse into a complete response
    final http.Response response = await http.Response.fromStream(streamedResponse);

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

// Call the OpenStreetMap search endpoint with a free-form query
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

// The reverse endpoint returns exactly one result or an error
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

// Use the user's locale to get the location from the country code
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

// This function follows the example from the Geolocator package
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
```

### LocationMap Widget

This is the main class of our app responsible for managing the map widget, the location search bar, and any associated UI components, ensuring a seamless and cohesive user experience.

Upon map initialization, if no `initialLocation` is specified, we attempt to retrieve the user's last known location or determine the user's location based on their device's locale country.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

import 'geolocation.dart' as Geolocation;

import 'debounced_search_bar.dart';
import 'round_icon_button.dart';
import 'location_pin.dart';
import 'location.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    this.initialLocation,
    this.onBoundsChanged,
    this.onLocationChanged,
  });

  final Location? initialLocation;
  final Function(Location location)? onLocationChanged;
  final Function(LatLngBounds bounds, LatLng center)? onBoundsChanged;

  @override
  State<StatefulWidget> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final MapController _mapController = MapController();
  Location? _location;
  bool _isMapMoved = false;
  Timer? _mapMovedTimer;

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMapsApp() async {
    if (_location == null) {
      return;
    }
    final lat = _location!.latitude;
    final lon = _location!.longitude;
    final zoom = _mapController.camera.zoom;
    final Uri? mapsUri;
    try {
      // Check if the maps app is available on the device
      if (await canLaunchUrl(Uri.parse('maps:'))) {
        // Use the maps: URL scheme on iOS
        mapsUri = Uri.parse('maps://?ll=$lat,$lon&z=$zoom');
      } else if (await canLaunchUrl(Uri.parse('geo:'))) {
        // Use the geo: URL scheme on Android
        mapsUri = Uri.parse('geo:$lat,$lon?z=$zoom');
      } else if (await canLaunchUrl(Uri.parse('comgooglemaps:'))) {
        // Use the comgooglemaps: URL scheme on Android
        mapsUri = Uri.parse('comgooglemaps://?center=$lat,$lon&zoom=$zoom');
      } else if (await canLaunchUrl(Uri.parse('waze:'))) {
        // Use the waze: URL scheme on Android
        mapsUri = Uri.parse('waze://?ll=$lat,$lon&z=$zoom');
      } else {
        throw 'Failed to open maps';
      }
      await launchUrl(mapsUri);
    } catch (error) {
      _showErrorDialog('Failed to open maps', error.toString());
    }
  }

  void _setLocation(Location location) {
    // Move the map to the new location
    _mapController.move(location.latLng, 10.0);
    _mapController.rotate(0.0);
    // Fit the camera to the bounds if available
    if (location.bounds != null) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: location.bounds!,
        padding: const EdgeInsets.all(16.0),
      ));
    }
    setState(() {
      // Update the location and reset the map moved flag
      _location = location;
      _isMapMoved = false;
    });
    // If the location has changed, call the onLocationChanged callback
    if (location != widget.initialLocation) {
      widget.onLocationChanged?.call(location);
    }
  }

  Future<List<Location>> _searchLocation(String query) async {
    try {
      // Try searching for the location using the OpenStreetMap search endpoint
      final List<Location> results = await Geolocation.searchLocation(query);
      return results;
    } catch (error) {
      _showErrorDialog('Failed to search location', error.toString());
      // Because the SearchBar search function still expects a List, return an empty list
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await Geolocation.getCurrentLocation();
      _setLocation(location);
    } catch (error) {
      _showErrorDialog('Failed to get current location', error.toString());
    }
  }

  Future<void> _initMap() async {
    // This is a very hacky way to wait for the parent dimensions, otherwise the map will not render correctly
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Try getting initial location from widget, last known location, or location by locale
      final Location? location = widget.initialLocation ??
          await Geolocation.getLastKnownLocation() ??
          await Geolocation.getLocationByLocale();
      if (location != null) {
        _setLocation(location);
      }
    } catch (error) {
      _showErrorDialog('Failed to get initial location', error.toString());
    }
  }

  void _onMapMoved() {
    // Set the map moved flag to true to show the recenter button
    setState(() {
      _isMapMoved = true;
    });
    // To avoid calling onBoundsChanged too frequently, use a simple debounce mechanism
    if (_mapMovedTimer != null) {
      _mapMovedTimer!.cancel();
    }
    // Wait for 500ms before calling onBoundsChanged again
    _mapMovedTimer = Timer(const Duration(milliseconds: 500), () {
      final bounds = _mapController.camera.visibleBounds;
      final center = _mapController.camera.center;
      widget.onBoundsChanged?.call(bounds, center);
    });
  }

  void _onLongPress(LatLng latLng) async {
    // When the user long-presses on the map, try to get the location at that point
    try {
      final location = await Geolocation.getLocationByCoordinates(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      );
      if (location != null) {
        _setLocation(location);
      }
    } catch (error) {
      _showErrorDialog('Failed to get location', error.toString());
    }
  }

  void _showLocationDetails() {
    if (_location == null) {
      return;
    }
    // Show location details in a bottom sheet
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_location!.name ?? 'Location', style: Theme.of(context).textTheme.titleLarge),
                  Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Text(_location!.displayName ?? 'Address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16.0),
              Text('Lat/lng: ${_location!.latitude}, ${_location!.longitude}'),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _location?.latLng ?? LatLng(0.0, 0.0),
            initialZoom: 10.0,
            interactionOptions: const InteractionOptions(
              // Disable rotation
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (position, hasGesture) {
              _onMapMoved();
            },
            onLongPress: (point, latLng) {
              _onLongPress(latLng);
            },
            onMapReady: () {
              _initMap();
            },
          ),
          children: [
            TileLayer(
              // Use the OpenStreetMap tile server
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            if (_location != null) ...[
              MarkerLayer(
                markers: [  
                  Marker(
                    point: _location!.latLng,
                    alignment: Alignment.topCenter,
                    height: 48,
                    width: 48,
                    child: GestureDetector(
                      onTap: () {
                        _showLocationDetails();
                      },
                      child: LocationPin(),
                    ),
                  ),
                ],
              ),
            ],
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ],
            ),
          ],
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DebouncedSearchBar<Location>(
                hintText: 'Search location',
                initialValue: _location,
                titleBuilder: (Location location) => Text(location.toString()),
                leadingIconBuilder: (Location location) => const Icon(Icons.location_pin),
                searchFunction: _searchLocation,
                onResultSelected: (Location location) {
                  _setLocation(location);
                },
              ),
              Spacer(), // Add a Spacer to push the buttons to the bottom
              if (_location != null && _isMapMoved) ...[
                RoundIconButton(
                  icon: const Icon(Icons.near_me),
                  onPressed: () {
                    _setLocation(_location!);
                  },
                ),
                const SizedBox(height: 8.0),
              ],
              if (_location != null) ...[
                RoundIconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () {
                    _openMapsApp();
                  },
                ),
                const SizedBox(height: 8.0),
              ],
              RoundIconButton(
                icon: const Icon(Icons.my_location),
                onPressed: () {
                  _getCurrentLocation();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

### DebouncedSearchBar Widget

Debouncing is crucial for optimizing search functionality. When a user types quickly in a search bar, numerous requests can be sent to the server, overwhelming it and potentially causing delays or even crashes.

[My previous article](https://stassop.medium.com/debouncing-flutter-searchanchor-65101042e5aa) explains the implementation of [DebouncedSearchBar](https://github.com/stassop/flutter_debounced_search_bar) in detail. This optimization significantly improves performance and enhances the overall user experience.

```dart
import 'package:flutter/material.dart';
import 'dart:async'; 

/// This is a simplified version of debounced search based on the following example:
/// https://api.flutter.dev/flutter/material/Autocomplete-class.html?v=1.0.20#material.Autocomplete.5
typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer(duration: const Duration(milliseconds: 500));
    try {
      await debounceTimer!.future;
    } catch (error) {
      print(error); // Should be 'Debounce cancelled' when cancelled.
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer({required this.duration}) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Duration duration;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError('Debounce cancelled');
  }
}

class DebouncedSearchBar<T> extends StatefulWidget {
  const DebouncedSearchBar({
    super.key,
    required this.onResultSelected,
    required this.searchFunction,
    required this.titleBuilder,
    this.hintText,
    this.initialValue,
    this.leadingIconBuilder,
    this.subtitleBuilder,
  });

  final String? hintText;
  final T? initialValue;
  final Widget? Function(T result)? titleBuilder;
  final Widget? Function(T result)? subtitleBuilder;
  final Widget? Function(T result)? leadingIconBuilder;
  final Function(T result)? onResultSelected;
  final Future<Iterable<T>> Function(String query) searchFunction;

  @override
  State<StatefulWidget> createState() => _DebouncedSearchBarState<T>();
}

class _DebouncedSearchBarState<T> extends State<DebouncedSearchBar<T>> {
  final _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;
  final pastResults = <T>[];

  _selectResult(T result) {
    widget.onResultSelected?.call(result);
    // Add the result on top of the list of past results if it is not already there
    // If the number of past results exceeds 10, remove the oldest one
    if (!pastResults.contains(result)) {
      pastResults.insert(0, result);
      if (pastResults.length > 10) {
        pastResults.removeLast();
      }
    }
  }

  Future<Iterable<T>> _search(String query) async {
    if (query.isEmpty) {
      return <T>[];
    }

    try {
      final results = await widget.searchFunction(query);
      return results;
    } catch (error) {
      return <T>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(_search);
    _searchController.text = widget.initialValue != null 
        ? widget.initialValue.toString() 
        : '';
  }

  @override
  void didUpdateWidget(DebouncedSearchBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _searchController.text = widget.initialValue != null 
          ? widget.initialValue.toString() 
          : '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0)),
          onTap: () {
            controller.openView();
          },
          leading: const Icon(Icons.search),
          hintText: widget.hintText,
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final Future<Iterable<T>?> future = _debouncedSearch(controller.text);
        try {
          final Iterable<T>? results = await future;
          // If there are results, return a list of result tiles
          if (results?.isNotEmpty ?? false) {
            return results!.map((result) {
              return ListTile(
                title: widget.titleBuilder?.call(result),
                subtitle: widget.subtitleBuilder?.call(result),
                leading: widget.leadingIconBuilder?.call(result),
                onTap: () {
                  _selectResult(result);
                  controller.closeView(result.toString());
                },
              );
            }).toList();
          }
          // If there's no search text and there are past results, return a list of past results
          if (controller.text.isEmpty && pastResults.isNotEmpty) {
            // Add a tile with a history icon and 'Search history' title
            return <Widget>[
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Search history'),
              ),
              for (final result in pastResults)
                ListTile(
                  title: widget.titleBuilder?.call(result),
                  subtitle: widget.subtitleBuilder?.call(result),
                  leading: widget.leadingIconBuilder?.call(result),
                  onTap: () {
                    _selectResult(result);
                    controller.closeView(result.toString());
                  },
                ),
            ];
          }
          // If there's search text but no results, return a 'No results found' tile
          if (controller.text.isNotEmpty) {
            return <Widget>[
              ListTile(
                title: const Text('No results found'),
              ),
            ];
          }
          // If there's no search text and no past results, return an empty list
          return <Widget>[];
        } catch (error) {
          return <Widget>[
            ListTile(
              title: const Text('An error occurred'),
            ),
          ];
        }
      },
    );
  }
}
```

### Putting It All Together

Here’s our `main.dart` class. As you can see, the top-level structure is clean and simple, making it easy to repurpose our location search widget in other applications.

```dart
import 'package:flutter/material.dart';

import 'location_map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LocationMap(),
    );
  }
}
```

### Conclusion

Implementing a robust and feature-rich location search and mapping experience within your Flutter application can be surprisingly straightforward and cost-effective.

By leveraging free-tier tools and following simple guidelines, startups and developers alike can easily integrate maps into their projects without incurring significant expenses.

These free-tier solutions offer a wealth of possibilities, allowing developers to experiment, iterate, and build compelling location-based features while minimizing development costs.