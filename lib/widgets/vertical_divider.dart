import 'package:flutter/material.dart';

class VerticalDiv extends StatelessWidget {
  const VerticalDiv({super.key, this.color = const Color(0xff575757)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: 1,
      color: color,
    );
  }
}
