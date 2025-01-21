import 'package:flutter/material.dart';

import 'location_map.dart';
import 'geolocation.dart';
import 'location.dart';

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
      home: LocationMap(
        initialLocation: Location(
          latitude: 37.7749,
          longitude: -122.4194,
          displayName: 'San Francisco, California, United States',
        ),
      ),
    );
  }
}
