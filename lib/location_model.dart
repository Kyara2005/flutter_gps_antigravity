import 'dart:convert';

/// Represents a single GPS location record captured by the tracker.
class LocationLog {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;     // m/s
  final double altitude;  // meters
  final DateTime timestamp;
  final bool isBackground; // true = captured while app was in background

  LocationLog({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.altitude,
    required this.timestamp,
    required this.isBackground,
  });

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'acc': accuracy,
        'spd': speed,
        'alt': altitude,
        'ts': timestamp.toIso8601String(),
        'bg': isBackground,
      };

  factory LocationLog.fromJson(Map<String, dynamic> j) => LocationLog(
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lng'] as num).toDouble(),
        accuracy: (j['acc'] as num? ?? 0).toDouble(),
        speed: (j['spd'] as num? ?? 0).toDouble(),
        altitude: (j['alt'] as num? ?? 0).toDouble(),
        timestamp: DateTime.parse(j['ts'] as String),
        isBackground: j['bg'] as bool? ?? false,
      );

  /// Encode a list of logs to a JSON string for SharedPreferences storage.
  static String encodeList(List<LocationLog> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  /// Decode a JSON string from SharedPreferences back into a list of logs.
  static List<LocationLog> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => LocationLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Speed in km/h (converted from m/s).
  double get speedKmh => speed * 3.6;
}
