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