import 'package:flutter/material.dart';

class PageField extends StatefulWidget {
  const PageField(
      {super.key, required this.onChanged, required this.onSubmitted});

  final void Function(String) onChanged;
  final void Function(String) onSubmitted;

  @override
  State<PageField> createState() => _PageFieldState();
}

class _PageFieldState extends State<PageField> {
  late TextEditingController textController;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();
    focusNode = FocusNode();
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 1,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.number,
      focusNode: focusNode,
      decoration: InputDecoration(
        constraints: const BoxConstraints(maxWidth: 60, maxHeight: 40),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        filled: true,
        fillColor: Colors.black12,
        hintText: '43',
        border: _inputBorder(Colors.black38),
        enabledBorder: _inputBorder(Colors.black38),
        focusedBorder: _inputBorder(Colors.black54),
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderSide: BorderSide(
        color: color,
        width: 3,
      ),
    );
  }
}
