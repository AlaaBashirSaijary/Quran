import 'dart:math';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/language.dart';

class PrayerMethod {
  const PrayerMethod(
    this.id,
    this.arabicName,
    this.englishName,
    this.parameters,
  );

  final String id;
  final String arabicName;
  final String englishName;

  String get name => tr(arabicName, englishName);
  final CalculationParameters Function() parameters;
}

final prayerMethods = [
  PrayerMethod(
    'mwl',
    'رابطة العالم الإسلامي',
    'Muslim World League',
    CalculationMethodParameters.muslimWorldLeague,
  ),
  PrayerMethod(
    'ummAlQura',
    'أم القرى (السعودية)',
    'Umm al-Qura (Saudi Arabia)',
    CalculationMethodParameters.ummAlQura,
  ),
  PrayerMethod(
    'egyptian',
    'الهيئة المصرية العامة',
    'Egyptian General Authority',
    CalculationMethodParameters.egyptian,
  ),
  PrayerMethod(
    'jordan',
    'الأردن',
    'Jordan',
    CalculationMethodParameters.jordan,
  ),
  PrayerMethod('dubai', 'دبي', 'Dubai', CalculationMethodParameters.dubai),
  PrayerMethod(
    'gulf',
    'دول الخليج',
    'Gulf region',
    CalculationMethodParameters.gulfRegion,
  ),
  PrayerMethod(
    'kuwait',
    'الكويت',
    'Kuwait',
    CalculationMethodParameters.kuwait,
  ),
  PrayerMethod('qatar', 'قطر', 'Qatar', CalculationMethodParameters.qatar),
  PrayerMethod(
    'turkiye',
    'تركيا (ديانت)',
    'Türkiye (Diyanet)',
    CalculationMethodParameters.turkiye,
  ),
  PrayerMethod(
    'algerian',
    'الجزائر',
    'Algeria',
    CalculationMethodParameters.algerian,
  ),
  PrayerMethod(
    'morocco',
    'المغرب',
    'Morocco',
    CalculationMethodParameters.morocco,
  ),
  PrayerMethod(
    'tunisia',
    'تونس',
    'Tunisia',
    CalculationMethodParameters.tunisia,
  ),
  PrayerMethod(
    'karachi',
    'جامعة العلوم الإسلامية، كراتشي',
    'University of Islamic Sciences, Karachi',
    CalculationMethodParameters.karachi,
  ),
  PrayerMethod(
    'northAmerica',
    'أمريكا الشمالية (ISNA)',
    'North America (ISNA)',
    CalculationMethodParameters.northAmerica,
  ),
  PrayerMethod('france', 'فرنسا', 'France', CalculationMethodParameters.france),
  PrayerMethod(
    'singapore',
    'سنغافورة وماليزيا',
    'Singapore and Malaysia',
    CalculationMethodParameters.singapore,
  ),
];

class City {
  const City(
    this.arabicName,
    this.englishName,
    this.latitude,
    this.longitude,
    this.methodId,
  );

  /// Also what is saved as the chosen place.
  final String arabicName;
  final String englishName;

  String get name => tr(arabicName, englishName);
  final double latitude;
  final double longitude;

  /// The calculation method commonly used there.
  final String methodId;
}

const cities = [
  City('مكة المكرمة', 'Makkah', 21.4225, 39.8262, 'ummAlQura'),
  City('المدينة المنورة', 'Madinah', 24.4672, 39.6111, 'ummAlQura'),
  City('الرياض', 'Riyadh', 24.7136, 46.6753, 'ummAlQura'),
  City('جدة', 'Jeddah', 21.4858, 39.1925, 'ummAlQura'),
  City('دبي', 'Dubai', 25.2048, 55.2708, 'dubai'),
  City('أبوظبي', 'Abu Dhabi', 24.4539, 54.3773, 'dubai'),
  City('الدوحة', 'Doha', 25.2854, 51.5310, 'qatar'),
  City('الكويت', 'Kuwait City', 29.3759, 47.9774, 'kuwait'),
  City('المنامة', 'Manama', 26.2285, 50.5860, 'gulf'),
  City('مسقط', 'Muscat', 23.5880, 58.3829, 'gulf'),
  City('عمّان', 'Amman', 31.9454, 35.9284, 'jordan'),
  City('دمشق', 'Damascus', 33.5138, 36.2765, 'mwl'),
  City('حلب', 'Aleppo', 36.2021, 37.1343, 'mwl'),
  City('حمص', 'Homs', 34.7324, 36.7137, 'mwl'),
  City('بيروت', 'Beirut', 33.8938, 35.5018, 'mwl'),
  City('القدس', 'Jerusalem', 31.7683, 35.2137, 'mwl'),
  City('غزة', 'Gaza', 31.5017, 34.4668, 'egyptian'),
  City('بغداد', 'Baghdad', 33.3152, 44.3661, 'mwl'),
  City('القاهرة', 'Cairo', 30.0444, 31.2357, 'egyptian'),
  City('الإسكندرية', 'Alexandria', 31.2001, 29.9187, 'egyptian'),
  City('الخرطوم', 'Khartoum', 15.5007, 32.5599, 'egyptian'),
  City('طرابلس (ليبيا)', 'Tripoli (Libya)', 32.8872, 13.1913, 'egyptian'),
  City('تونس', 'Tunis', 36.8065, 10.1815, 'tunisia'),
  City('الجزائر', 'Algiers', 36.7538, 3.0588, 'algerian'),
  City('الرباط', 'Rabat', 34.0209, -6.8416, 'morocco'),
  City('الدار البيضاء', 'Casablanca', 33.5731, -7.5898, 'morocco'),
  City('صنعاء', 'Sana‘a', 15.3694, 44.1910, 'mwl'),
  City('إسطنبول', 'Istanbul', 41.0082, 28.9784, 'turkiye'),
  City('أنقرة', 'Ankara', 39.9334, 32.8597, 'turkiye'),
  City('برلين', 'Berlin', 52.5200, 13.4050, 'mwl'),
  City('لندن', 'London', 51.5074, -0.1278, 'mwl'),
  City('باريس', 'Paris', 48.8566, 2.3522, 'france'),
];

class PrayerTime {
  const PrayerTime(this.prayer, this.name, this.time);

  final Prayer prayer;
  final String name;

  /// Local time.
  final DateTime time;
}

const _names = {
  Prayer.fajr: ('الفجر', 'Fajr'),
  Prayer.sunrise: ('الشروق', 'Sunrise'),
  Prayer.dhuhr: ('الظهر', 'Dhuhr'),
  Prayer.asr: ('العصر', 'Asr'),
  Prayer.maghrib: ('المغرب', 'Maghrib'),
  Prayer.isha: ('العشاء', 'Isha'),
};

/// The prayer's name in the interface language.
String prayerName(Prayer prayer) {
  final (ar, en) = _names[prayer]!;
  return tr(ar, en);
}

const _myLocation = 'موقعي الحالي';

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
      _place = prefs.getString('prayer.place');
    }
    methodId = prefs.getString('prayer.method') ?? 'mwl';
    hanafiAsr = prefs.getBool('prayer.hanafi') ?? false;
  }

  final SharedPreferences prefs;

  Coordinates? coordinates;
  String? _place;

  /// The chosen city or the device location, in the interface language.
  String? get placeName {
    final place = _place;
    if (place == null) return null;
    if (place == _myLocation) return tr(place, 'My location');
    for (final c in cities) {
      if (c.arabicName == place) return c.name;
    }
    return place;
  }

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
          prayerName(prayer),
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
    _setLocation(Coordinates(city.latitude, city.longitude), city.arabicName);
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
        error = tr(
          'خدمة الموقع متوقفة. فعّلها من إعدادات الهاتف أو اختر مدينتك.',
          'Location services are off. Turn them on in the phone settings or choose your city.',
        );
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        error = tr(
          'لم يُسمح بالوصول إلى الموقع. يمكنك اختيار مدينتك من القائمة.',
          'Location access was not allowed. You can choose your city from the list.',
        );
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
        _myLocation,
      );
      return true;
    } catch (_) {
      error = tr(
        'تعذّر تحديد الموقع. حاول مرة أخرى أو اختر مدينتك.',
        'Could not find your location. Try again or choose your city.',
      );
      return false;
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  void _setLocation(Coordinates value, String name) {
    coordinates = value;
    _place = name;
    prefs
      ..setDouble('prayer.lat', value.latitude)
      ..setDouble('prayer.lng', value.longitude)
      ..setString('prayer.place', name);
    notifyListeners();
  }
}
