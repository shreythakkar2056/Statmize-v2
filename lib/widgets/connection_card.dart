import 'package:flutter/material.dart';

class ConnectionCard extends StatelessWidget {
  final bool isConnected;
  final bool isScanning;
  final bool isConnecting;
  final DateTime? lastDataReceived;
  final Color Function() getConnectionStatusColor;

  const ConnectionCard({
    super.key,
    required this.isConnected,
    required this.isScanning,
    required this.isConnecting,
    required this.lastDataReceived,
    required this.getConnectionStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              getConnectionStatusColor().withValues(alpha: 0.1),
              getConnectionStatusColor().withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getConnectionStatusColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : isScanning
                            ? Icons.bluetooth_searching
                            : Icons.bluetooth_disabled,
                    color: getConnectionStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected
                            ? "Device Connected"
                            : isScanning
                                ? "Scanning for Device"
                                : isConnecting
                                    ? "Connecting..."
                                    : "Device Disconnected",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: getConnectionStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? "ESP32_IMU • Ready to receive data"
                            : isScanning
                                ? "Looking for ESP32_IMU..."
                                : isConnecting
                                    ? "Establishing connection..."
                                    : "Bluetooth device not found",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "LIVE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            if (isScanning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                backgroundColor: getConnectionStatusColor().withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                    getConnectionStatusColor()),
              ),
            ],
            if (lastDataReceived != null && isConnected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.update,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Last update: ${DateTime.now().difference(lastDataReceived!).inSeconds}s ago",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}