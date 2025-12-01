import 'package:ble_controller/choosecontroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  void startScan() {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });
    
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    Future.delayed(const Duration(seconds: 4), () {
      setState(() {
        _isScanning = false;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      // Show connecting dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connecting...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? characteristic;
      
      for (var service in services) {
        for (var c in service.characteristics) {
          if (c.properties.write) {
            characteristic = c;
            break;
          }
        }
      }
      
      // Close connecting dialog
      Navigator.pop(context);
      
      if (characteristic != null) {
        // Navigate to controller selection page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ControllerSelectionPage(
              device: device,
              characteristic: characteristic!,
            ),
          ),
        );
      } else {
        showErrorSnackbar("No writable characteristic found.");
      }
    } catch (e) {
      // Close connecting dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      showErrorSnackbar("Failed to connect: $e");
    }
  }

  void showErrorSnackbar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text(
          'Bluetooth Devices',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_searching_rounded,
                    size: 64,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isScanning ? "Scanning..." : "Scan for Bluetooth Devices",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isScanning ? null : startScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade700,
                      disabledForegroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      shadowColor: Colors.orange.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isScanning)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey.shade400,
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.search_rounded, size: 24),
                        const SizedBox(width: 12),
                        Text(_isScanning ? "SCANNING" : "SCAN"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          SliverToBoxAdapter(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: Colors.grey.shade800,
            ),
          ),

          // Devices List or Empty State
          _scanResults.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled_rounded,
                          size: 80,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? "Looking for devices..."
                              : "No devices found",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!_isScanning) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Tap scan to search",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final result = _scanResults[index];
                        final deviceName = result.device.name.isNotEmpty
                            ? result.device.name
                            : "Unknown Device";
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade800,
                                Colors.grey.shade900,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.bluetooth_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            title: Text(
                              deviceName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                result.device.id.toString(),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            onTap: () => connectToDevice(result.device),
                          ),
                        );
                      },
                      childCount: _scanResults.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}