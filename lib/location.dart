import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
    this.latLngBounds,
    this.neighbourhood,
    this.postcode,
    this.road,
    this.state,
    this.zoom,
  });

  final double latitude;
  final double longitude;
  final double? zoom;
  final LatLngBounds? latLngBounds;
  final List<Polygon>? geometry;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? displayName;
  final String? neighbourhood;
  final String? postcode;
  final String? road;
  final String? state;

  LatLng get latLng => LatLng(latitude, longitude);

  static List<Polygon> geometryFromGeoJson(Map<String, dynamic> geoJson) {
    // The GeoJSON format can contain different types of geometries: Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon
    // For the sake of simplicity, we only handle Polygon and MultiPolygon here
    // Polygon data looks like this: {"type": "Polygon", "coordinates": [[[4.970096, 52.1224417], [4.9706266, 52.1218922], ...]]}
    // MultiPolygon data looks like this: {"type": "MultiPolygon", "coordinates": [[[[4.970096, 52.1224417], [4.9706266, 52.1218922], ...]], [[[4.970096, 52.1224417], [4.9706266, 52.1218922], ...]]]}
    // Every array that contains two numbers represents a coordinate pair, and is converted to a LatLng object
    // Every array of coordinate pairs represents a polygon, and becomes the points of a Polygon object
    // https://nominatim.org/release-docs/latest/api/Lookup/#polygon-output
    // https://docs.fleaflet.dev/layers/polygon-layer
    List<Polygon> polygons = [];
    if (geoJson['type'] == 'Polygon') {
      final List<LatLng> points = List<List<dynamic>>.from(geoJson['coordinates'][0])
          .map((point) => LatLng(point[1] as double, point[0] as double))
          .toList();
      polygons.add(Polygon(points: points, borderStrokeWidth: 2));
    } else if (geoJson['type'] == 'MultiPolygon') {
      final List<dynamic> multiPolygons = geoJson['coordinates'];
      for (final List<dynamic> polygon in multiPolygons) {
        final List<LatLng> points = List<List<dynamic>>.from(polygon[0])
            .map((point) => LatLng(point[1] as double, point[0] as double))
            .toList();
        polygons.add(Polygon(points: points, borderStrokeWidth: 2));
      }
    }
    return polygons;
  }

  static double zoomFromGeoJson(Map<String, dynamic> geoJson) {
    // This is a very simplistic way to determine the zoom level based on the GeoJSON type
    // You can also calculate the zoom level based on the location type or addresstype
    // https://docs.fleaflet.dev/v3/usage/options/recommended-options#zooms-zoom-minzoom-maxzoom
    // https://nominatim.org/release-docs/latest/api/Lookup/#output-format
    switch (geoJson['type']) {
      case 'Point':
        return 16.0; 
      case 'LineString':
        return 13.0; 
      case 'Polygon':
        return 12.0; 
      case 'MultiPoint':
        return 15.0; 
      case 'MultiLineString':
        return 11.0; 
      case 'MultiPolygon':
        return 10.0; 
      default:
        return 13.0; // Default zoom level
    }
  }

  static LatLngBounds boundsFromJson (List<dynamic> boundsJson) {
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
      displayName: json['display_name'],
      zoom: json.containsKey('geojson')
          ? zoomFromGeoJson(json['geojson'])
          : null,
      latLngBounds: json.containsKey('boundingbox')
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