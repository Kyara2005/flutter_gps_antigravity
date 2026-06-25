import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'location_model.dart';

const String kPrefLogsKey = 'gps_logs';
const String kPrefTrackingKey = 'gps_tracking';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();
/// Initialise and configure the FlutterBackgroundService.
/// Call once from main() before runApp().
Future<void> initBackgroundService() async {
  const AndroidNotificationChannel channel =
      AndroidNotificationChannel(
    'gps_tracker_channel',
    'GPS Tracking',
    description: 'Servicio de rastreo GPS',
    importance: Importance.low,
  );

  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'gps_tracker_channel',
      initialNotificationTitle: 'GPS Tracker',
      initialNotificationContent: 'Iniciando rastreo...',
      foregroundServiceNotificationId: 1001,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

/// iOS background handler (required by the package even if not fully supported).
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Entry point for the background isolate — runs on Android foreground service.
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Listen for stop command from UI
  service.on('stop').listen((_) async {
    await _setTracking(false);
    await service.stopSelf();
  });

  // Mark tracking as active
  //await _setTracking(true);

  // Start listening to position updates
  final locationStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // record every 5 metres of movement
    ),
  );

  locationStream.listen((Position pos) async {
    final log = LocationLog(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      altitude: pos.altitude,
      timestamp: DateTime.now(),
      isBackground: true,
    );

    // Persist to SharedPreferences
    //await _appendLog(log);

    // Update the foreground notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'GPS Tracker — Activo',
        content:
            'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
      );
    }

    // Send update to the UI isolate (if the app is open)
    service.invoke('location', log.toJson());
  });
}

// ─── SharedPreferences helpers ──────────────────────────────────────────────

Future<void> _appendLog(LocationLog log) async {
  final prefs = SharedPreferencesAsync();
  final raw = await prefs.getString(kPrefLogsKey) ?? '[]';
  final list = LocationLog.decodeList(raw);
  list.add(log);
  // Keep at most 5 000 entries to avoid unbounded growth
  final trimmed = list.length > 5000 ? list.sublist(list.length - 5000) : list;
  await prefs.setString(kPrefLogsKey, LocationLog.encodeList(trimmed));
}

Future<void> _setTracking(bool value) async {
  final prefs = SharedPreferencesAsync();
  await prefs.setBool(kPrefTrackingKey, value);
}

// ─── Public helpers used from the UI ───────────────────────────────────────

Future<List<LocationLog>> loadLogs() async {
  final prefs = SharedPreferencesAsync();
  final raw = await prefs.getString(kPrefLogsKey) ?? '[]';
  return LocationLog.decodeList(raw);
}

Future<void> clearLogs() async {
  final prefs = SharedPreferencesAsync();
  await prefs.remove(kPrefLogsKey);
}

Future<bool> isTracking() async {
  final prefs = SharedPreferencesAsync();
  return await prefs.getBool(kPrefTrackingKey) ?? false;
}

Future<void> startTracking() async {
  final service = FlutterBackgroundService();
  await service.startService();
}

Future<void> stopTracking() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}
