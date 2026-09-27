import 'package:flutter/material.dart';

import '../core/index.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../widgets/surah_number.dart';
import 'index_screen.dart';
import 'tafsir_screen.dart';
import '../providers/settings_provider.dart';
import '../share/share_card.dart';
import '../widgets/translation_text.dart';
import '../quran/translation.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.isTab = false});

  /// Opened from the main tabs rather than from inside the reader.
  final bool isTab;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  QuranSearch? _search;
  SearchResults? _results;

  @override
  void initState() {
    super.initState();
    QuranSearch.load().then((search) {
      if (!mounted) return;
      setState(() => _search = search);
      _onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static final _latin = RegExp('[A-Za-z]');

  Future<void> _onChanged(String query) async {
    final search = _search;
    if (search == null) return;
    if (!_latin.hasMatch(query)) {
      setState(() => _results = search.search(query));
      return;
    }
    // Words in English: search the translation of the meanings and the
    // transliterated surah names.
    final translation = await Translation.load();
    if (!mounted || _controller.text != query) return;
    final (found, total) = translation.search(query);
    final needle = query.trim().toLowerCase();
    setState(
      () => _results = SearchResults(
        [
          if (needle.length >= 2)
            for (var s = 1; s <= 114; s++)
              if (surahNameOf(s).toLowerCase().contains(needle) ||
                  surahNameEnglish(s).toLowerCase().contains(needle))
                s,
        ],
        [for (final (s, a) in found) search.ayahsOfSurah(s)[a - 1]],
        total,
      ),
    );
  }

  void _open(int page) => openQuranPage(context, page, isTab: widget.isTab);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppConstant.searchAyah)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: tr(
                  'اكتب كلمة من الآية أو اسم السورة',
                  'A word in Arabic or English, or a surah name',
                ),
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.gold),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('مسح', 'Clear'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                filled: true,
                fillColor: colorScheme.brightness == Brightness.light
                    ? Colors.white
                    : AppColor.nightSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.div),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.div),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.gold, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final results = _results;

    if (_search == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results == null || _controller.text.trim().length < 2) {
      return _Message(
        icon: Icons.manage_search_rounded,
        text: tr(
          'ابحث في القرآن الكريم بكلمة أو جزء من آية',
          'Search the Quran for a word or part of an ayah (in Arabic)',
        ),
      );
    }
    if (results.isEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        text: tr('لا توجد نتائج', 'No results'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        for (final surah in results.surahs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: SurahNumber(number: surah),
                title: Text(
                  surahTitle(surah),
                  style: const TextStyle(
                    fontFamily: AppTheme.secondaryFontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(getSurahData(surah)),
                onTap: () => _open(getSurahFirstPage(surah)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            results.totalAyahs > results.ayahs.length
                ? tr(
                    'عدد الآيات: ${results.totalAyahs} (تُعرض أول ${results.ayahs.length})',
                    'Ayahs: ${results.totalAyahs} (showing the first ${results.ayahs.length})',
                  )
                : tr(
                    'عدد الآيات: ${results.totalAyahs}',
                    'Ayahs: ${results.totalAyahs}',
                  ),
            style: TextStyle(color: colorScheme.pageNumber),
          ),
        ),
        for (final ayah in results.ayahs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(ayah.page),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ayah.text,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: AppTheme.secondaryFontFamily,
                          fontSize: context.contentSize(22),
                          height: 1.8,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      TranslationText(ayahs: [(ayah.surah, ayah.number)]),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${surahTitle(ayah.surah)} · ${ayahLabel(ayah.number)} · ${AppConstant.page} ${ayah.page}',
                              style: TextStyle(
                                color: colorScheme.gold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: tr('مشاركة كصورة', 'Share as image'),
                            icon: Icon(
                              Icons.ios_share_rounded,
                              size: 20,
                              color: colorScheme.gold,
                            ),
                            onPressed: () => shareAsImage(
                              context,
                              text: ayah.text,
                              reference: quranReference(
                                getSurahNameArabic(ayah.surah),
                                ayah.number,
                              ),
                              quran: true,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => TafsirScreen.open(
                              context,
                              ayah.page,
                              focusAyah: ayah,
                            ),
                            icon: const Icon(Icons.menu_book_rounded, size: 18),
                            label: Text(tr('التفسير', 'Tafsir')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colorScheme.gold),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.pageNumber),
            ),
          ],
        ),
      ),
    );
  }
}
