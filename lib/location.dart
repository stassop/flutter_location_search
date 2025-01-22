import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:equatable/equatable.dart';

// Our Locaiton model class combines data from OpenStreetMap API and LatLng coordinates
// At the very least, we need the latitude and longitude of a location, hence they are required
class Location {
  Location({
    required this.latitude,
    required this.longitude,
    this.city,
    this.country,
    this.countryCode,
    this.displayName,
    this.geometry,
    this.bounds,
    this.neighbourhood,
    this.postcode,
    this.road,
    this.state,
    this.suburb,
    this.zoom,
  });

  final double latitude;
  final double longitude;
  final double? zoom;
  final LatLngBounds? bounds;
  final List<Polygon>? geometry;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? displayName;
  final String? neighbourhood;
  final String? postcode;
  final String? road;
  final String? state;
  final String? suburb;

  LatLng get latLng => LatLng(latitude, longitude);

  // Make it possible to compare two Location objects
  @override
  List<Object?> get props => [
        bounds,
        city,
        country,
        countryCode,
        displayName,
        geometry,
        latitude,
        longitude,
        neighbourhood,
        postcode,
        road,
        state,
        suburb,
        zoom,
      ];

  // The GeoJSON format can contain different types of geometries: Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon
  // For the sake of simplicity, we only handle Polygon and MultiPolygon here
  // Polygon data looks like this: {'type': 'Polygon', 'coordinates': [[[4.970096, 52.1224417], [4.9706266, 52.1218922], ...]]}
  // MultiPolygon data looks like this: {'type': 'MultiPolygon', 'coordinates': [[[[4.970096, 52.1224417], [4.9706266, 52.1218922], ...]], [[[4.970096, 52.1224417], [4.9706266, 52.1218922], ...]]]}
  // An array that contains two numbers represents a coordinate pair, and is converted to a LatLng object
  // An array of coordinate pairs represents a polygon, and becomes the points of a Polygon object
  // https://nominatim.org/release-docs/latest/api/Lookup/#polygon-output
  // https://docs.fleaflet.dev/layers/polygon-layer
  static List<Polygon>? geometryFromGeoJson(Map<String, dynamic> geoJson) {
    List<Polygon> polygons = [];
    if (geoJson['type'] == 'Polygon') {
      final List<LatLng> points =
          List<List<dynamic>>.from(geoJson['coordinates'][0])
              .map((point) => LatLng(point[1] as double, point[0] as double))
              .toList();
      polygons.add(Polygon(points: points, borderStrokeWidth: 2));
      return polygons;
    } else if (geoJson['type'] == 'MultiPolygon') {
      final List<dynamic> multiPolygons = geoJson['coordinates'];
      for (final List<dynamic> polygon in multiPolygons) {
        final List<LatLng> points = List<List<dynamic>>.from(polygon[0])
            .map((point) => LatLng(point[1] as double, point[0] as double))
            .toList();
        polygons.add(Polygon(points: points, borderStrokeWidth: 2));
      }
      return polygons;
    }
    return null;
  }

  // This corresponds roughly to the zoom level used in XYZ tile sources in frameworks like Leaflet.js, Openlayers etc.
  // https://nominatim.org/release-docs/latest/api/Reverse/#result-restriction
  static double zoomFromGeoJson(Map<String, dynamic> geoJson) {
    final String? addressType = geoJson['addresstype'] 
        ?? geoJson['category']
        ?? geoJson['type'];
    const Map<String, double> zoomLevels = {
      'country': 3.0,
      'state': 5.0,
      'province': 5.0, 
      'region': 6.0,
      'county': 8.0,
      'city': 10.0,
      'town': 10.0,
      'village': 12.0,
      'suburb': 13.0,
      'neighborhood': 14.0,
      'district': 9.0,
      'postcode': 12.0,
      'street': 16.0,
      'road': 16.0,
      'avenue': 16.0,
      'boulevard': 16.0,
      'lane': 16.0,
      'place': 15.0,
      'square': 15.0,
      'circle': 15.0,
      'building': 18.0,
      'house': 18.0,
      'apartment': 18.0,
      'unit': 18.0,
      'floor': 18.0,
      'intersection': 17.0,
      'landmark': 16.0,
      'poi': 15.0, 
    };
    // TODO: Fix this later
    return zoomLevels.containsKey(addressType) ? zoomLevels[addressType]! : 10.0;
  }

  static LatLngBounds boundsFromJson(List<dynamic> boundsJson) {
    // OpenStreetMap returns the bounds as a list of strings
    // that need to be converted to a list of doubles
    final List<double> bounds =
        List<String>.from(boundsJson).map(double.parse).toList();
    return LatLngBounds(
      LatLng(bounds[0], bounds[2]),
      LatLng(bounds[1], bounds[3]),
    );
  }

  factory Location.fromOpenStreetMapJson(Map<String, dynamic> json) {
    // If there are no coordinates, throw an error
    if (!json.containsKey('lat') || !json.containsKey('lon')) {
      throw Exception('No coordinates found');
    }
    // We assume that the OpenStreetMap API always follows the same structure
    // so we don't apply any checks here, but you should do it in a real app
    return Location(
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
      countryCode: json['address']['country_code'],
      country: json['address']['country'],
      road: json['address']['road'],
      city: json['address']['city'],
      postcode: json['address']['postcode'],
      state: json['address']['state'],
      neighbourhood: json['address']['neighbourhood'],
      suburb: json['address']['suburb'],
      displayName: json['display_name'],
      zoom: zoomFromGeoJson(json),
      bounds: json.containsKey('boundingbox')
          ? boundsFromJson(json['boundingbox'])
          : null,
      geometry: json.containsKey('geojson')
          ? geometryFromGeoJson(json['geojson'])
          : null,
    );
  }

  @override
  String toString() {
    return displayName ?? '$latitude, $longitude';
  }
}
