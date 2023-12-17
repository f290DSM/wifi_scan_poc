import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: WifiScanPage(),
    );
  }
}

class WifiScanPage extends StatefulWidget {
  const WifiScanPage({Key? key}) : super(key: key);

  @override
  State<WifiScanPage> createState() => _WifiScanPageState();
}

class _WifiScanPageState extends State<WifiScanPage> {
  List<WiFiAccessPoint> accessPoints = <WiFiAccessPoint>[];
  StreamSubscription<List<WiFiAccessPoint>>? subscription;
  bool shouldCheckCan = true;

  bool get isStreaming => subscription != null;

  Future<void> _startScan(BuildContext context) async {
    if (shouldCheckCan) {
      var can = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (can != CanStartScan.yes) {
        if (mounted) kShowSnackBar(context, 'Cannot start scan: $can');
        return;
      }
    }
    final result = await WiFiScan.instance.startScan();
    if (mounted) kShowSnackBar(context, 'startScan: $result');
    setState(() {
      accessPoints = <WiFiAccessPoint>[];
    });
  }

  Future<bool> _canGetScannedResults(BuildContext context) async {
    if (shouldCheckCan) {
      final can =
          await WiFiScan.instance.canGetScannedResults(askPermissions: true);

      if (can != CanGetScannedResults.yes) {
        if (mounted) kShowSnackBar(context, 'Cannot get scanned results: $can');
        accessPoints = <WiFiAccessPoint>[];
        return false;
      }
    }
    return true;
  }

  Future<void> _getScannedResults(BuildContext context) async {
    if (await _canGetScannedResults(context)) {
      final results = await WiFiScan.instance.getScannedResults();
      setState(() {
        accessPoints = results;
      });
    }
  }

  Future<void> _startListeningToScanResults(BuildContext context) async {
    if (await _canGetScannedResults(context)) {
      subscription =
          WiFiScan.instance.onScannedResultsAvailable.listen((event) {
        setState(() {
          accessPoints = event;
        });
      });
    }
  }

  void _stopListeningToScaanResults() {
    subscription?.cancel();
    setState(() {
      subscription = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _stopListeningToScaanResults();
  }

  Widget _buildToogle(
      {String? label,
      bool value = false,
      ValueChanged<bool>? onChanged,
      Color? color}) {
    return Row(
      children: [
        if (label != null) Text(label),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WifiScan Example'),
        actions: [
          _buildToogle(
              label: "Check Can?",
              value: shouldCheckCan,
              onChanged: (value) => setState(() {
                    shouldCheckCan = value;
                  }),
              color: Colors.orange),
        ],
      ),
      body: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    _startScan(context);
                  },
                  icon: const Icon(Icons.perm_scan_wifi),
                  label: const Text('SCAN'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    _getScannedResults(context);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('GET'),
                ),
                _buildToogle(
                    label: 'STREAM',
                    value: isStreaming,
                    onChanged: (value) async => value
                        ? await _startListeningToScanResults(context)
                        : _stopListeningToScaanResults()),
                const Divider(),
                Flexible(
                    child: Center(
                  child: accessPoints.isEmpty
                      ? const Text('NO SCANNED RESULTS')
                      : ListView.builder(
                          itemCount: accessPoints.length,
                          itemBuilder: (context, index) {
                            return _AccessPointTile(accessPoint: accessPoints[index]);
                          },
                        ),
                ))
              ],
            ),
          );
        },
      ),
    );
  }
}

void kShowSnackBar(BuildContext context, String message) {
  // if (kDebugMode) print(message);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _AccessPointTile extends StatelessWidget {
  final WiFiAccessPoint accessPoint;

  const _AccessPointTile({Key? key, required this.accessPoint})
      : super(key: key);

  // build row that can display info, based on label: value pair.
  Widget _buildInfo(String label, dynamic value) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey)),
    ),
    child: Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value.toString()))
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = accessPoint.ssid.isNotEmpty ? accessPoint.ssid : "**EMPTY**";
    final signalIcon = accessPoint.level >= -80
        ? Icons.signal_wifi_4_bar
        : Icons.signal_wifi_0_bar;
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Icon(signalIcon),
      title: Text(title),
      subtitle: Text(accessPoint.capabilities),
      onTap: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfo("BSSDI", accessPoint.bssid),
              _buildInfo("Capability", accessPoint.capabilities),
              _buildInfo("frequency", "${accessPoint.frequency}MHz"),
              _buildInfo("level", accessPoint.level),
              _buildInfo("standard", accessPoint.standard),
              _buildInfo(
                  "centerFrequency0", "${accessPoint.centerFrequency0}MHz"),
              _buildInfo(
                  "centerFrequency1", "${accessPoint.centerFrequency1}MHz"),
              _buildInfo("channelWidth", accessPoint.channelWidth),
              _buildInfo("isPasspoint", accessPoint.isPasspoint),
              _buildInfo(
                  "operatorFriendlyName", accessPoint.operatorFriendlyName),
              _buildInfo("venueName", accessPoint.venueName),
              _buildInfo("is80211mcResponder", accessPoint.is80211mcResponder),
            ],
          ),
        ),
      ),
    );
  }
}
