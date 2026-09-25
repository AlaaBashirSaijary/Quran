import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../providers/ahadith_details_provider.dart';
import '../widgets/hadith_details.dart';

class AhadithTab extends StatelessWidget {
  const AhadithTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AhadithDetailsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الأحاديث النبوية')),
      body: provider.ahadithData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.ahadithData.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final hadith = provider.ahadithData[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      hadith.title,
                      style: const TextStyle(
                        fontFamily: AppTheme.secondaryFontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_left_rounded,
                      color: colorScheme.gold,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HadithDetails(hadith: hadith),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
