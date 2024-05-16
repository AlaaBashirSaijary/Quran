import 'package:flutter/material.dart';

class HorizentalDiv extends StatelessWidget {
  const HorizentalDiv({Key? key, this.color =  Colors.white, this.thickness = 1})
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
