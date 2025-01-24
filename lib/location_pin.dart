import 'package:flutter/material.dart';

class LocationPin extends StatelessWidget {
  const LocationPin({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shadow
        Positioned(
          bottom: 0,
          child: Container(
            width: 40,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.elliptical(20, 5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
        // Icon
        Icon(
          Icons.location_pin,
          size: 50,
          color: Colors.red,
        ),
      ],
    );
  }
}