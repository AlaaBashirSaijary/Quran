import 'package:flutter/material.dart';

import '../core/index.dart';
import '../quran/quran.dart';
import '../quran/search.dart';
import '../widgets/surah_number.dart';
import 'index_screen.dart';

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

  void _onChanged(String query) {
    final search = _search;
    if (search == null) return;
    setState(() => _results = search.search(query));
  }

  void _open(int page) => openQuranPage(context, page, isTab: widget.isTab);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstant.searchAyah)),
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
                hintText: 'اكتب كلمة من الآية أو اسم السورة',
                prefixIcon: Icon(Icons.search_rounded, color: colorScheme.gold),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
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
        text: 'ابحث في القرآن الكريم بكلمة أو جزء من آية',
      );
    }
    if (results.isEmpty) {
      return const _Message(
        icon: Icons.search_off_rounded,
        text: 'لا توجد نتائج',
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
                  'سورة ${getSurahNameArabic(surah)}',
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
                ? 'عدد الآيات: ${results.totalAyahs} (تُعرض أول ${results.ayahs.length})'
                : 'عدد الآيات: ${results.totalAyahs}',
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
                        style: TextStyle(
                          fontFamily: AppTheme.secondaryFontFamily,
                          fontSize: 22,
                          height: 1.8,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'سورة ${getSurahNameArabic(ayah.surah)} · الآية ${ayah.number} · ${AppConstant.page} ${ayah.page}',
                        style: TextStyle(color: colorScheme.gold, fontSize: 13),
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
