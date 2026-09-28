import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:quranapplication/providers/show_overlay_provider.dart';
import 'package:quranapplication/widgets/quran_page.dart';
import 'package:provider/provider.dart';

import '../audio/player_bar.dart';
import '../core/index.dart';
import '../quran/page_data.dart';
import '../providers/quran.dart';
import '../widgets/custom_toast.dart';
import '../widgets/info_overlay/info_overlay.dart';
import '../widgets/marker.dart';
import '../widgets/page_number.dart';
import '../widgets/simple_page_info.dart';
import '../providers/settings_provider.dart';
import '../widgets/quran_text_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quran = Provider.of<Quran>(context);
    final overlay = Provider.of<ShowOverlayProvider>(context, listen: false);
    final quranListenFalse = Provider.of<Quran>(context, listen: false);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.aspectRatio > 0.54;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final colorScheme = Theme.of(context).colorScheme;
    final textMode = Provider.of<SettingsProvider>(context).textMode;

    return SafeArea(
      child: GestureDetector(
        onTap: overlay.toggleisShowOverlay,
        child: Scaffold(
          backgroundColor: isLandscape && size.width > 500
              ? colorScheme.scaffoldBg
              : null,
          body: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The mushaf reads right to left in either language.
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    decoration: isLandscape && size.width > 500
                        ? BoxDecoration(
                            border: Border.symmetric(
                              vertical: BorderSide(
                                color: colorScheme.infoText,
                                width: 2,
                              ),
                            ),
                            color: colorScheme.scaffold,
                          )
                        : null,
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: readerZoomed,
                      builder: (context, zoomed, _) => CarouselSlider.builder(
                        carouselController: quran.carouselController,
                        options: CarouselOptions(
                          // A zoomed page pans instead of turning.
                          scrollPhysics: zoomed
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          enableInfiniteScroll: false,
                          height: double.infinity,
                          initialPage: quran.currentPage - 1,
                          viewportFraction: 1,
                          enlargeCenterPage: false,
                          onPageChanged: (int newIndex, _) {
                            quranListenFalse.changePage(newIndex);
                          },
                        ),
                        itemCount: quranPages.length,
                        itemBuilder: (_, pageIndex, _) {
                          if (textMode) {
                            return Column(
                              children: [
                                const SimplePageInfo(),
                                Expanded(
                                  child: QuranTextPage(page: pageIndex + 1),
                                ),
                                const PageNumber(),
                              ],
                            );
                          }
                          return isLandscape || isKeyboardOpen
                              ? ListView(
                                  children: [
                                    const SimplePageInfo(),
                                    QuranPage(pageIndex: pageIndex),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SimplePageInfo(),
                                    QuranPage(pageIndex: pageIndex),
                                    const PageNumber(),
                                  ],
                                );
                        },
                      ),
                    ),
                  ),
                ),
                const Marker(),
                Consumer<ShowOverlayProvider>(
                  builder: (context, overlay, child) =>
                      overlay.isShowOverlay ? const SizedBox.shrink() : child!,
                  child: const CustomToast(),
                ),
                Consumer<ShowOverlayProvider>(
                  builder: (context, overlay, child) =>
                      overlay.isShowOverlay ? const SizedBox.shrink() : child!,
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(child: RecitationBar()),
                  ),
                ),
                const InfoOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
