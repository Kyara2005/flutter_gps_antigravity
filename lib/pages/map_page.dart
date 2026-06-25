import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../location_model.dart';

class MapPage extends StatefulWidget {
  final List<LocationLog> logs;
  final LocationLog? currentLocation;

  const MapPage({
    super.key,
    required this.logs,
    this.currentLocation,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-center when a new location arrives
    if (widget.currentLocation != null &&
        widget.currentLocation != oldWidget.currentLocation) {
      _mapController.move(
        LatLng(
          widget.currentLocation!.latitude,
          widget.currentLocation!.longitude,
        ),
        _mapController.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.currentLocation != null
        ? LatLng(
            widget.currentLocation!.latitude,
            widget.currentLocation!.longitude,
          )
        : const LatLng(-0.2295, -78.5243); // Quito, Ecuador (default)

    final polylinePoints = widget.logs
        .map((l) => LatLng(l.latitude, l.longitude))
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // ── Base tile layer (OpenStreetMap, no API key needed) ──
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.flutter_gps_antigravity',
          maxZoom: 19,
        ),

        // ── Trail polyline ──
        if (polylinePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                color: const Color(0xFF00E676),
                strokeWidth: 3.5,
              ),
            ],
          ),

        // ── Past location markers ──
        MarkerLayer(
          markers: widget.logs.map((log) {
            final isLast = log == widget.logs.last;
            return Marker(
              point: LatLng(log.latitude, log.longitude),
              width: isLast ? 24 : 12,
              height: isLast ? 24 : 12,
              child: Container(
                decoration: BoxDecoration(
                  color: isLast
                      ? const Color(0xFF00E676)
                      : const Color(0xFF00E676).withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isLast ? 2.5 : 1,
                  ),
                  boxShadow: isLast
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E676).withValues(alpha: 0.6),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
