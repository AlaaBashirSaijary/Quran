import 'package:flutter/material.dart';

import '../core/index.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstant.searchAyah)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 72, color: colorScheme.gold),
              const SizedBox(height: 16),
              const Text(AppConstant.noSearchYet, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppConstant.goBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
