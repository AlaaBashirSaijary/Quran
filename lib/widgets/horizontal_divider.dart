import 'package:flutter/material.dart';

class HorizontalDiv extends StatelessWidget {
  const HorizontalDiv({
    super.key,
    this.color = Colors.white,
    this.thickness = 1,
  });

  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(height: thickness, width: double.infinity, color: color);
  }
}
