import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// No UTC fallback: an unresolved weekly zone fails visibly in the core.
/// A temporary native lookup failure retains the last valid device zone.
class DeviceZone {
  DeviceZone({
    Future<String> Function()? read,
    this.timeout = const Duration(seconds: 1),
  }) : read = read ?? _native;
  final Future<String> Function() read;
  final Duration timeout;
  String identifier = 'Unknown/Unavailable';
  static Future<String> _native() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
  Future<void> refresh() async {
    try {
      final next = await read().timeout(timeout);
      tz.getLocation(next);
      identifier = next;
    } catch (_) {
      /* Keep the last valid zone, including the unavailable marker. */
    }
  }
}
