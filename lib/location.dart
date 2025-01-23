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
