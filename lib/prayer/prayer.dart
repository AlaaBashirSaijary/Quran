import 'dart:math';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerMethod {
  const PrayerMethod(this.id, this.name, this.parameters);

  final String id;
  final String name;
  final CalculationParameters Function() parameters;
}

final prayerMethods = [
  PrayerMethod(
    'mwl',
    'رابطة العالم الإسلامي',
    CalculationMethodParameters.muslimWorldLeague,
  ),
  PrayerMethod(
    'ummAlQura',
    'أم القرى (السعودية)',
    CalculationMethodParameters.ummAlQura,
  ),
  PrayerMethod(
    'egyptian',
    'الهيئة المصرية العامة',
    CalculationMethodParameters.egyptian,
  ),
  PrayerMethod('jordan', 'الأردن', CalculationMethodParameters.jordan),
  PrayerMethod('dubai', 'دبي', CalculationMethodParameters.dubai),
  PrayerMethod('gulf', 'دول الخليج', CalculationMethodParameters.gulfRegion),
  PrayerMethod('kuwait', 'الكويت', CalculationMethodParameters.kuwait),
  PrayerMethod('qatar', 'قطر', CalculationMethodParameters.qatar),
  PrayerMethod('turkiye', 'تركيا (ديانت)', CalculationMethodParameters.turkiye),
  PrayerMethod('algerian', 'الجزائر', CalculationMethodParameters.algerian),
  PrayerMethod('morocco', 'المغرب', CalculationMethodParameters.morocco),
  PrayerMethod('tunisia', 'تونس', CalculationMethodParameters.tunisia),
  PrayerMethod(
    'karachi',
    'جامعة العلوم الإسلامية، كراتشي',
    CalculationMethodParameters.karachi,
  ),
  PrayerMethod(
    'northAmerica',
    'أمريكا الشمالية (ISNA)',
    CalculationMethodParameters.northAmerica,
  ),
  PrayerMethod('france', 'فرنسا', CalculationMethodParameters.france),
  PrayerMethod(
    'singapore',
    'سنغافورة وماليزيا',
    CalculationMethodParameters.singapore,
  ),
];

class City {
  const City(this.name, this.latitude, this.longitude, this.methodId);

  final String name;
  final double latitude;
  final double longitude;

  /// The calculation method commonly used there.
  final String methodId;
}

const cities = [
  City('مكة المكرمة', 21.4225, 39.8262, 'ummAlQura'),
  City('المدينة المنورة', 24.4672, 39.6111, 'ummAlQura'),
  City('الرياض', 24.7136, 46.6753, 'ummAlQura'),
  City('جدة', 21.4858, 39.1925, 'ummAlQura'),
  City('دبي', 25.2048, 55.2708, 'dubai'),
  City('أبوظبي', 24.4539, 54.3773, 'dubai'),
  City('الدوحة', 25.2854, 51.5310, 'qatar'),
  City('الكويت', 29.3759, 47.9774, 'kuwait'),
  City('المنامة', 26.2285, 50.5860, 'gulf'),
  City('مسقط', 23.5880, 58.3829, 'gulf'),
  City('عمّان', 31.9454, 35.9284, 'jordan'),
  City('دمشق', 33.5138, 36.2765, 'mwl'),
  City('حلب', 36.2021, 37.1343, 'mwl'),
  City('حمص', 34.7324, 36.7137, 'mwl'),
  City('بيروت', 33.8938, 35.5018, 'mwl'),
  City('القدس', 31.7683, 35.2137, 'mwl'),
  City('غزة', 31.5017, 34.4668, 'egyptian'),
  City('بغداد', 33.3152, 44.3661, 'mwl'),
  City('القاهرة', 30.0444, 31.2357, 'egyptian'),
  City('الإسكندرية', 31.2001, 29.9187, 'egyptian'),
  City('الخرطوم', 15.5007, 32.5599, 'egyptian'),
  City('طرابلس (ليبيا)', 32.8872, 13.1913, 'egyptian'),
  City('تونس', 36.8065, 10.1815, 'tunisia'),
  City('الجزائر', 36.7538, 3.0588, 'algerian'),
  City('الرباط', 34.0209, -6.8416, 'morocco'),
  City('الدار البيضاء', 33.5731, -7.5898, 'morocco'),
  City('صنعاء', 15.3694, 44.1910, 'mwl'),
  City('إسطنبول', 41.0082, 28.9784, 'turkiye'),
  City('أنقرة', 39.9334, 32.8597, 'turkiye'),
  City('برلين', 52.5200, 13.4050, 'mwl'),
  City('لندن', 51.5074, -0.1278, 'mwl'),
  City('باريس', 48.8566, 2.3522, 'france'),
];

class PrayerTime {
  const PrayerTime(this.prayer, this.name, this.time);

  final Prayer prayer;
  final String name;

  /// Local time.
  final DateTime time;
}

const _names = {
  Prayer.fajr: 'الفجر',
  Prayer.sunrise: 'الشروق',
  Prayer.dhuhr: 'الظهر',
  Prayer.asr: 'العصر',
  Prayer.maghrib: 'المغرب',
  Prayer.isha: 'العشاء',
};

/// Prayer times for the saved location and calculation settings.
///
/// Times are calculated on the device (adhan_dart) and shown in the
/// device's time zone, so they are right for the phone's own location.
class PrayerProvider extends ChangeNotifier {
  PrayerProvider(this.prefs) {
    final lat = prefs.getDouble('prayer.lat');
    final lng = prefs.getDouble('prayer.lng');
    if (lat != null && lng != null) {
      coordinates = Coordinates(lat, lng);
      placeName = prefs.getString('prayer.place');
    }
    methodId = prefs.getString('prayer.method') ?? 'mwl';
    hanafiAsr = prefs.getBool('prayer.hanafi') ?? false;
  }

  final SharedPreferences prefs;

  Coordinates? coordinates;
  String? placeName;
  late String methodId;
  late bool hanafiAsr;

  bool locating = false;
  String? error;

  bool get hasLocation => coordinates != null;

  PrayerMethod get method => prayerMethods.firstWhere(
    (m) => m.id == methodId,
    orElse: () => prayerMethods.first,
  );

  PrayerTimes _timesFor(DateTime day) {
    final params = method.parameters()
      ..madhab = hanafiAsr ? Madhab.hanafi : Madhab.shafi;
    return PrayerTimes(
      date: DateTime(day.year, day.month, day.day),
      coordinates: coordinates!,
      calculationParameters: params,
    );
  }

  /// Fajr, sunrise, dhuhr, asr, maghrib and isha on [day], in local time.
  List<PrayerTime> timesOn(DateTime day) {
    final times = _timesFor(day);
    return [
      for (final prayer in _names.keys)
        PrayerTime(
          prayer,
          _names[prayer]!,
          times.timeForPrayer(prayer).toLocal(),
        ),
    ];
  }

  /// The next prayer after [now] (sunrise excluded), looking into tomorrow
  /// after isha.
  PrayerTime nextPrayer(DateTime now) {
    final candidates = [
      ...timesOn(now),
      ...timesOn(now.add(const Duration(days: 1))),
    ].where((t) => t.prayer != Prayer.sunrise);
    return candidates.firstWhere((t) => t.time.isAfter(now));
  }

  /// The prayer whose time has come and not yet passed, if any.
  Prayer? currentPrayer(DateTime now) {
    Prayer? current;
    for (final t in timesOn(now)) {
      if (!t.time.isAfter(now)) current = t.prayer;
    }
    return current == Prayer.sunrise ? null : current;
  }

  /// Direction of the Kaaba in degrees clockwise from true north.
  double get qibla => Qibla.qibla(coordinates!);

  /// Within about 20 km of the Kaaba, where a compass bearing means little.
  bool get nearKaaba {
    const earthRadiusKm = 6371.0;
    double rad(double deg) => deg * pi / 180;
    final here = coordinates!;
    const kaaba = Qibla.makkah;
    final dLat = rad(kaaba.latitude - here.latitude);
    final dLng = rad(kaaba.longitude - here.longitude);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(rad(here.latitude)) *
            cos(rad(kaaba.latitude)) *
            pow(sin(dLng / 2), 2);
    return 2 * earthRadiusKm * asin(sqrt(a)) < 20;
  }

  void setCity(City city) {
    _setLocation(Coordinates(city.latitude, city.longitude), city.name);
    setMethod(city.methodId);
  }

  void setMethod(String id) {
    methodId = id;
    prefs.setString('prayer.method', id);
    notifyListeners();
  }

  void setHanafiAsr(bool value) {
    hanafiAsr = value;
    prefs.setBool('prayer.hanafi', value);
    notifyListeners();
  }

  /// Asks for the device location. Returns false with [error] set when it
  /// is unavailable or refused.
  Future<bool> useDeviceLocation() async {
    locating = true;
    error = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'خدمة الموقع متوقفة. فعّلها من إعدادات الهاتف أو اختر مدينتك.';
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        error = 'لم يُسمح بالوصول إلى الموقع. يمكنك اختيار مدينتك من القائمة.';
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _setLocation(
        Coordinates(position.latitude, position.longitude),
        'موقعي الحالي',
      );
      return true;
    } catch (_) {
      error = 'تعذّر تحديد الموقع. حاول مرة أخرى أو اختر مدينتك.';
      return false;
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  void _setLocation(Coordinates value, String name) {
    coordinates = value;
    placeName = name;
    prefs
      ..setDouble('prayer.lat', value.latitude)
      ..setDouble('prayer.lng', value.longitude)
      ..setString('prayer.place', name);
    notifyListeners();
  }
}
