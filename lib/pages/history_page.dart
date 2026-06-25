import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../location_model.dart';

class HistoryPage extends StatelessWidget {
  final List<LocationLog> logs;
  final VoidCallback onClear;

  const HistoryPage({
    super.key,
    required this.logs,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final reversed = logs.reversed.toList();

    return Column(
      children: [
        // ── Header toolbar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${logs.length} registros',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              if (logs.isNotEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Limpiar',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),

        const Divider(color: Color(0xFF2A2A3E), height: 1),

        // ── List ──
        Expanded(
          child: logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: Color(0xFF3A3A5C)),
                      SizedBox(height: 12),
                      Text(
                        'Sin registros todavía.\nInicia el rastreo para capturar ubicaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B6B8A),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: reversed.length,
                  itemBuilder: (context, index) {
                    final log = reversed[index];
                    return _LogTile(log: log, index: reversed.length - index);
                  },
                ),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final LocationLog log;
  final int index;

  const _LogTile({required this.log, required this.index});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd/MM/yyyy  HH:mm:ss').format(log.timestamp.toLocal());
    final coordText =
        '${log.latitude.toStringAsFixed(6)}, ${log.longitude.toStringAsFixed(6)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: log.isBackground
              ? const Color(0xFF00E676).withValues(alpha: 0.15)
              : const Color(0xFF3A3A5C),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: log.isBackground
                ? const Color(0xFF00E676).withValues(alpha: 0.12)
                : const Color(0xFF2A2A4A),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: log.isBackground
                    ? const Color(0xFF00E676)
                    : const Color(0xFF8888AA),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          coordText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(color: Color(0xFF8888AA), fontSize: 11.5),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _Badge(
                  icon: Icons.speed,
                  label: '${log.speedKmh.toStringAsFixed(1)} km/h',
                ),
                const SizedBox(width: 8),
                _Badge(
                  icon: Icons.landscape,
                  label: '${log.altitude.toStringAsFixed(0)} m',
                ),
                const SizedBox(width: 8),
                _Badge(
                  icon: Icons.gps_fixed,
                  label: '±${log.accuracy.toStringAsFixed(0)} m',
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 16, color: Color(0xFF00E676)),
          tooltip: 'Copiar coordenadas',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: coordText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Coordenadas copiadas'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFF00E676),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: const Color(0xFF5A5A7A)),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: Color(0xFF5A5A7A), fontSize: 10.5)),
      ],
    );
  }
}
