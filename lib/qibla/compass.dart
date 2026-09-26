import 'dart:math';

/// Compass heading in degrees clockwise from magnetic north, for a phone
/// whose accelerometer reads [gravity] and magnetometer reads [magnetic]
/// (both in the device's x, y, z axes). Returns null when the readings
/// can't give a direction (free fall, or pointing straight at the field).
///
/// This is the rotation-matrix method of Android's SensorManager: east is
/// magnetic × gravity, north is gravity × east, and the heading is the
/// angle of the phone's y axis between them. It works at any tilt.
double? headingFrom(
  (double, double, double) gravity,
  (double, double, double) magnetic,
) {
  final (ax, ay, az) = gravity;
  final (ex, ey, ez) = magnetic;

  var hx = ey * az - ez * ay;
  var hy = ez * ax - ex * az;
  var hz = ex * ay - ey * ax;
  final normH = sqrt(hx * hx + hy * hy + hz * hz);
  final normA = sqrt(ax * ax + ay * ay + az * az);
  if (normH < 0.1 || normA < 0.1) return null;
  hx /= normH;
  hy /= normH;
  hz /= normH;
  final nx = ax / normA, nz = az / normA;
  final my = nz * hx - nx * hz;

  final azimuth = atan2(hy, my) * 180 / pi;
  return (azimuth + 360) % 360;
}

/// Smooths a stream of angles without jumping at the 359° / 0° seam.
class AngleSmoother {
  AngleSmoother({this.factor = 0.15});

  final double factor;
  double? _value;

  double add(double degrees) {
    final current = _value;
    if (current == null) return _value = degrees;
    final delta = ((degrees - current + 540) % 360) - 180;
    return _value = (current + delta * factor + 360) % 360;
  }
}

/// How far to turn, in degrees from -180 to 180, to face [target] when the
/// phone points at [heading]. Positive means turn clockwise (right).
double turnTowards(double target, double heading) =>
    ((target - heading + 540) % 360) - 180;
