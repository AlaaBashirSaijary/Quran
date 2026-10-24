import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/index.dart';
import '../harvest/harvest_screen.dart';
import '../hifz/hifz.dart';
import '../kids/kids_screen.dart';
import '../providers/reading_provider.dart';
import 'hifz_screen.dart';
import 'wird_screen.dart';

/// The top of the Quran tab: where you left off, and four shortcuts. Kept
/// short so the list of surahs starts near the top of the screen.
class QuranHomeHeader extends StatelessWidget {
  const QuranHomeHeader({
    super.key,
    required this.surahName,
    required this.page,
    required this.onContinue,
  });

  final String surahName;
  final int page;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContinueBar(surahName: surahName, page: page, onTap: onContinue),
        const SizedBox(height: 10),
        const _QuickTiles(),
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.surahName,
    required this.page,
    required this.onTap,
  });

  final String surahName;
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    return Material(
      color: isLight ? AppColor.green : AppColor.nightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.gold.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: colorScheme.gold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('متابعة القراءة', 'Continue reading'),
                      style: TextStyle(color: colorScheme.gold, fontSize: 12),
                    ),
                    Text(
                      '${tr('سورة $surahName', 'Surah $surahName')} · '
                      '${AppConstant.page} $page',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colorScheme.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTiles extends StatelessWidget {
  const _QuickTiles();

  void _open(BuildContext context, Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => screen),
  );

  @override
  Widget build(BuildContext context) {
    final reading = Provider.of<ReadingProvider>(context);
    final hifz = Provider.of<HifzProvider>(context);
    final goal = reading.goal == 0 ? 1 : reading.goal;
    return Row(
      children: [
        _Tile(
          icon: Icons.auto_stories_rounded,
          label: tr('الورد', 'Daily'),
          ring: (reading.today / goal).clamp(0.0, 1.0),
          onTap: () => _open(context, const WirdScreen()),
        ),
        const SizedBox(width: 8),
        _Tile(
          icon: Icons.psychology_rounded,
          label: tr('الحفظ', 'Memorize'),
          badge: hifz.due.length,
          onTap: () => _open(context, const HifzScreen()),
        ),
        const SizedBox(width: 8),
        _Tile(
          icon: Icons.child_care_rounded,
          label: tr('الصغار', 'Kids'),
          onTap: () => _open(context, const KidsCornerScreen()),
        ),
        const SizedBox(width: 8),
        _Tile(
          icon: Icons.auto_awesome_rounded,
          label: tr('حصادي', 'My month'),
          onTap: () => _open(context, const HarvestScreen()),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.ring,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Progress around the icon (0 to 1), when the tile has one.
  final double? ring;

  /// A count shown in a small badge, hidden when zero.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (ring != null)
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: ring,
                            strokeWidth: 3,
                            strokeCap: StrokeCap.round,
                            color: colorScheme.gold,
                            backgroundColor: colorScheme.div,
                          ),
                        ),
                      Icon(icon, color: colorScheme.gold, size: 24),
                      if (badge > 0)
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.gold,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.juzCardText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
