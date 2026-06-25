import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'background_service.dart';
import 'location_model.dart';
import 'pages/history_page.dart';
import 'pages/map_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackgroundService();
  runApp(const GpsApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// App root
// ─────────────────────────────────────────────────────────────────────────────

class GpsApp extends StatelessWidget {
  const GpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF1DE9B6),
          surface: Color(0xFF1A1A2E),
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const GpsHomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home page
// ─────────────────────────────────────────────────────────────────────────────

class GpsHomePage extends StatefulWidget {
  const GpsHomePage({super.key});

  @override
  State<GpsHomePage> createState() => _GpsHomePageState();
}

class _GpsHomePageState extends State<GpsHomePage>
    with TickerProviderStateMixin {
  int _tab = 0; // 0 = Mapa, 1 = Info, 2 = Historial

  bool _tracking = false;
  bool _permissionsOk = false;

  LocationLog? _current;
  List<LocationLog> _logs = [];

  // Subscription to background service events
  StreamSubscription? _bgSub;

  // Pulse animation for the tracking indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _init();
  }

  Future<void> _init() async {
    await _checkPermissions();
    await _loadStoredLogs();
    final running = await isTracking();
    if (running) _subscribeToService();
    setState(() => _tracking = running);
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<void> _checkPermissions() async {
    var loc = await Permission.location.status;
    debugPrint('Location status inicial: $loc');
    if (loc.isDenied) loc = await Permission.location.request();
    debugPrint('Location status después de pedir permiso: $loc');

    if (loc.isGranted) {
      // Ask for background on Android 10+
      var bgLoc = await Permission.locationAlways.status;
      if (bgLoc.isDenied) bgLoc = await Permission.locationAlways.request();
      debugPrint('Background location status: $bgLoc');
      // Notification permission (Android 13+)
      await Permission.notification.request();

      setState(() => _permissionsOk = bgLoc.isGranted || bgLoc.isLimited);
    } else {
      setState(() => _permissionsOk = false);
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadStoredLogs() async {
    final logs = await loadLogs();
    setState(() {
      _logs = logs;
      if (logs.isNotEmpty) _current = logs.last;
    });
  }

  // ── Background service IPC ────────────────────────────────────────────────

  void _subscribeToService() {
    final service = FlutterBackgroundServiceBridge();
    _bgSub = service.on('location').listen((data) {
      debugPrint('Evento recibido: $data');

      if (data == null) return;
      final log = LocationLog.fromJson(data);
      debugPrint(
      'GPS -> ${log.latitude}, ${log.longitude} '
      'vel=${log.speedKmh}km/h '
      'acc=${log.accuracy}m',);

      setState(() {
        _current = log;
        _logs.add(log);
      });
    });
  }

  void _unsubscribeFromService() {
    _bgSub?.cancel();
    _bgSub = null;
  }

  // ── Tracking controls ─────────────────────────────────────────────────────

  Future<void> _toggleTracking() async {
    if (!_permissionsOk) {
      _showPermissionDialog();
      return;
    }
    if (_tracking) {
      debugPrint('Deteniendo tracking...');
      await stopTracking();
      _unsubscribeFromService();
      setState(() => _tracking = false);
    } else {
      debugPrint('Iniciando tracking...');
      await startTracking();
      _subscribeToService();
      setState(() => _tracking = true);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpiar historial',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Eliminar todos los registros GPS guardados?',
          style: TextStyle(color: Color(0xFF8888AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF8888AA))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await clearLogs();
      setState(() {
        _logs = [];
        _current = null;
      });
    }
  }

  // ── Permission dialog ─────────────────────────────────────────────────────

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 8),
            Text('Permisos requeridos',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Para rastrear en segundo plano necesitas conceder el permiso '
          '"Permitir siempre" en la configuración del sistema.\n\n'
          'Ve a Configuración → Aplicaciones → GPS Tracker → Ubicación → '
          'Permitir siempre.',
          style: TextStyle(color: Color(0xFF8888AA), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF8888AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _unsubscribeFromService();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF12122A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // App icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.gps_fixed, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _tracking ? 'Rastreo activo' : 'Rastreo detenido',
                  style: TextStyle(
                    color: _tracking
                        ? const Color(0xFF00E676)
                        : const Color(0xFF6B6B8A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Live indicator
          if (_tracking)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, _) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                      SizedBox(width: 5),
                      Text('LIVE',
                          style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    const tabs = [
      ('Mapa', Icons.map_outlined),
      ('Posición', Icons.my_location),
      ('Historial', Icons.history),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF00E676).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(
                          color: const Color(0xFF00E676).withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[i].$2,
                      size: 20,
                      color: selected
                          ? const Color(0xFF00E676)
                          : const Color(0xFF5A5A7A),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i].$1,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF00E676)
                            : const Color(0xFF5A5A7A),
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildMapTab();
      case 1:
        return _buildInfoTab();
      case 2:
        return HistoryPage(logs: _logs, onClear: _clearHistory);
      default:
        return const SizedBox.shrink();
    }
  }

  // Map tab
  Widget _buildMapTab() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: MapPage(logs: _logs, currentLocation: _current),
        ),
        // Overlay: no permissions warning
        if (!_permissionsOk)
          _buildOverlay(
            icon: Icons.location_off,
            title: 'Sin permisos de ubicación',
            subtitle: 'Toca el botón para configurarlos',
            action: _checkPermissions,
          ),
        // Overlay: no logs yet but tracking
        if (_permissionsOk && _logs.isEmpty && _tracking)
          _buildOverlay(
            icon: Icons.satellite_alt,
            title: 'Buscando señal GPS…',
            subtitle: 'Muévete un poco para capturar la primera ubicación.',
          ),
      ],
    );
  }

  Widget _buildOverlay({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? action,
  }) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xCC0D0D1A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF3A3A5C)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF6B6B8A), fontSize: 13)),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Configurar permisos'),
              )
            ],
          ],
        ),
      ),
    );
  }

  // Info / Position tab
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _InfoCard(current: _current, tracking: _tracking, logs: _logs),
          const SizedBox(height: 120), // space for FAB
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _toggleTracking,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _tracking
                  ? [Colors.redAccent, const Color(0xFFFF6D00)]
                  : [const Color(0xFF00E676), const Color(0xFF1DE9B6)],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: (_tracking ? Colors.redAccent : const Color(0xFF00E676))
                    .withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _tracking ? Icons.stop_circle_outlined : Icons.play_circle_fill,
                color: Colors.black,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                _tracking ? 'Detener rastreo' : 'Iniciar rastreo',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info card widget
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final LocationLog? current;
  final bool tracking;
  final List<LocationLog> logs;

  const _InfoCard({
    required this.current,
    required this.tracking,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final hasFix = current != null;
    final time = hasFix
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(current!.timestamp.toLocal())
        : '—';

    return Column(
      children: [
        // ── Status card ──
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gps_fixed,
                      color: Color(0xFF00E676), size: 18),
                  const SizedBox(width: 8),
                  const Text('Posición actual',
                      style: TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tracking
                          ? const Color(0xFF00E676).withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: tracking
                              ? const Color(0xFF00E676).withValues(alpha: 0.4)
                              : const Color(0xFF3A3A5C)),
                    ),
                    child: Text(
                      tracking ? 'ACTIVO' : 'DETENIDO',
                      style: TextStyle(
                        color: tracking
                            ? const Color(0xFF00E676)
                            : const Color(0xFF6B6B8A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (hasFix) ...[
                _CoordRow(
                    label: 'Latitud',
                    value: current!.latitude.toStringAsFixed(7)),
                const SizedBox(height: 8),
                _CoordRow(
                    label: 'Longitud',
                    value: current!.longitude.toStringAsFixed(7)),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A2A3E)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetricChip(
                      icon: Icons.speed,
                      label: 'Velocidad',
                      value:
                          '${current!.speedKmh.toStringAsFixed(1)} km/h',
                    ),
                    const SizedBox(width: 10),
                    _MetricChip(
                      icon: Icons.landscape,
                      label: 'Altitud',
                      value: '${current!.altitude.toStringAsFixed(0)} m',
                    ),
                    const SizedBox(width: 10),
                    _MetricChip(
                      icon: Icons.adjust,
                      label: 'Precisión',
                      value: '±${current!.accuracy.toStringAsFixed(0)} m',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 13, color: Color(0xFF5A5A7A)),
                    const SizedBox(width: 5),
                    Text(time,
                        style: const TextStyle(
                            color: Color(0xFF5A5A7A), fontSize: 12)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        final text =
                            '${current!.latitude}, ${current!.longitude}';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coordenadas copiadas'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF00E676),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.copy,
                              size: 13, color: Color(0xFF00E676)),
                          SizedBox(width: 4),
                          Text('Copiar',
                              style: TextStyle(
                                  color: Color(0xFF00E676), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(Icons.satellite_alt,
                            size: 44, color: Color(0xFF3A3A5C)),
                        SizedBox(height: 10),
                        Text('Sin señal GPS',
                            style: TextStyle(
                                color: Color(0xFF6B6B8A), fontSize: 14)),
                        SizedBox(height: 4),
                        Text(
                          'Inicia el rastreo y espera la señal.',
                          style: TextStyle(
                              color: Color(0xFF4A4A6A), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Stats card ──
        _GlassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                  icon: Icons.pin_drop,
                  label: 'Puntos',
                  value: '${logs.length}'),
              _Divider(),
              _StatItem(
                  icon: Icons.cloud_done,
                  label: 'En segundo plano',
                  value:
                      '${logs.where((l) => l.isBackground).length}'),
              _Divider(),
              _StatItem(
                  icon: Icons.route,
                  label: 'Distancia',
                  value: _calcDistance(logs)),
            ],
          ),
        ),
      ],
    );
  }

  String _calcDistance(List<LocationLog> logs) {
    if (logs.length < 2) return '0 m';
    double total = 0;
    for (int i = 1; i < logs.length; i++) {
      total += Geolocator.distanceBetween(
        logs[i - 1].latitude,
        logs[i - 1].longitude,
        logs[i].latitude,
        logs[i].longitude,
      );
    }
    return total >= 1000
        ? '${(total / 1000).toStringAsFixed(2)} km'
        : '${total.toStringAsFixed(0)} m';
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: const Color(0xFF2A2A4A), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;
  const _CoordRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label  ',
              style: const TextStyle(
                  color: Color(0xFF6B6B8A), fontSize: 13)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      );
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF12122A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF00E676)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF5A5A7A), fontSize: 10)),
            ],
          ),
        ),
      );
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF00E676)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF5A5A7A), fontSize: 11)),
        ],
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 50,
        color: const Color(0xFF2A2A3E),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin IPC bridge (re-exposes FlutterBackgroundService.on for the UI)
// ─────────────────────────────────────────────────────────────────────────────

class FlutterBackgroundServiceBridge {
  Stream<Map<String, dynamic>?> on(String method) {
    return FlutterBackgroundService().on(method);
  }
}


