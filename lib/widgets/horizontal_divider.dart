import 'package:flutter/material.dart';

class HorizontalDiv extends StatelessWidget {
  const HorizontalDiv({Key? key, this.color =  Colors.white, this.thickness = 1})
      : super(key: key);

  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      width: double.infinity,
      color: color,
    );
  }
}
