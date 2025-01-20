import 'package:flutter/material.dart';

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.radius = 24.0,
    this.onPressed,
  });

  final Icon icon;
  final double radius;
  final Function? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed as void Function()?,
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.fromRadius(radius),
        maximumSize: Size.fromRadius(radius),
      ),
      child: icon,
    );
  }
}
