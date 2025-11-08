import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomePage(),
  ));
}

// ==================== PAGE 1: HOME ====================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BluetoothScanPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Bluetooth'),
            ),
            const SizedBox(width: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WifiPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Wifi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PAGE 2: BLUETOOTH SCAN ====================
class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  List<ScanResult> _scanResults = [];

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
    _scanResults.clear();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
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

      if (characteristic != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ControllerPage(
              device: device,
              characteristic: characteristic!,
            ),
          ),
        );
      } else {
        showErrorSnackbar("No writable characteristic found.");
      }
    } catch (e) {
      showErrorSnackbar("Failed to connect: $e");
    }
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: startScan,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Scan for Bluetooth Devices"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: _scanResults.map((r) {
                  return ListTile(
                    title: Text(r.device.name.isNotEmpty
                        ? r.device.name
                        : r.device.id.toString()),
                    subtitle: Text(r.device.id.toString()),
                    onTap: () => connectToDevice(r.device),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PAGE 3: BLUETOOTH CONTROLLER ====================
class ControllerPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;

  const ControllerPage({
    Key? key,
    required this.device,
    required this.characteristic,
  }) : super(key: key);

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  final Map<String, TextEditingController> _pressControllers = {
    'F': TextEditingController(),
    'B': TextEditingController(),
    'L': TextEditingController(),
    'R': TextEditingController(),
  };
  final Map<String, TextEditingController> _releaseControllers = {
    'F': TextEditingController(),
    'B': TextEditingController(),
    'L': TextEditingController(),
    'R': TextEditingController(),
  };

  bool _isSending = false;
  String _currentCommand = "";
  Map<String, bool> _isPressed = {
    'F': false,
    'B': false,
    'L': false,
    'R': false,
  };

  @override
  void initState() {
    super.initState();
    loadButtonCommands();
  }

  Future<void> loadButtonCommands() async {
    final prefs = await SharedPreferences.getInstance();
    _pressControllers.forEach((key, controller) {
      controller.text = prefs.getString('btn_press_$key') ?? key;
    });
    _releaseControllers.forEach((key, controller) {
      controller.text = prefs.getString('btn_release_$key') ?? 'S';
    });
    setState(() {});
  }

  Future<void> saveButtonCommand(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('btn_press_$key', _pressControllers[key]!.text);
    await prefs.setString('btn_release_$key', _releaseControllers[key]!.text);
  }

  Future<void> sendData(String data) async {
    try {
      await widget.characteristic.write(data.codeUnits, withoutResponse: false);
    } catch (e) {
      showErrorSnackbar("Failed to send data: $e");
    }
  }

  void handleButtonPress(String key) {
    setState(() {
      _isPressed[key] = true;
    });
    _isSending = true;
    _currentCommand = _pressControllers[key]!.text;
    continuouslySendCommand();
  }

  void handleButtonRelease(String key) {
    setState(() {
      _isPressed[key] = false;
    });
    _isSending = false;
    sendData(_releaseControllers[key]!.text);
  }

  void continuouslySendCommand() async {
    while (_isSending) {
      await sendData(_currentCommand);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget joystickButton({required String key, required IconData icon}) {
    return GestureDetector(
      onTapDown: (_) => handleButtonPress(key),
      onTapUp: (_) => handleButtonRelease(key),
      onTapCancel: () => handleButtonRelease(key),
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isPressed[key]! ? Colors.red : Colors.blue.shade400,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 40, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                joystickButton(key: 'L', icon: Icons.arrow_back),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    joystickButton(key: 'F', icon: Icons.arrow_upward),
                    const SizedBox(height: 20),
                    joystickButton(key: 'B', icon: Icons.arrow_downward),
                  ],
                ),
                const SizedBox(width: 20),
                joystickButton(key: 'R', icon: Icons.arrow_forward),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isSending = false;
    _pressControllers.values.forEach((c) => c.dispose());
    _releaseControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
}

// ==================== PAGE 4: WIFI ====================
class WifiPage extends StatelessWidget {
  const WifiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditWifiPage()),
            );
          },
          child: const Text('Edit WiFi Setting'),
        ),
      ),
    );
  }
}

// ==================== PAGE 5: EDIT WIFI SETTINGS ====================
class EditWifiPage extends StatelessWidget {
  EditWifiPage({super.key});

  final TextEditingController ipController =
      TextEditingController(text: '192.168.4.1');

  final Map<String, TextEditingController> pressControllers = {
    'F1': TextEditingController(text: '/move?state='),
    'F2': TextEditingController(),
    'B1': TextEditingController(text: '/move?state='),
    'B2': TextEditingController(),
    'L1': TextEditingController(text: '/move?state='),
    'L2': TextEditingController(),
    'R1': TextEditingController(text: '/move?state='),
    'R2': TextEditingController(),
  };

  final Map<String, TextEditingController> releaseControllers = {
    'F1': TextEditingController(text: '/move?state='),
    'F2': TextEditingController(),
    'B1': TextEditingController(text: '/move?state='),
    'B2': TextEditingController(),
    'L1': TextEditingController(text: '/move?state='),
    'L2': TextEditingController(),
    'R1': TextEditingController(text: '/move?state='),
    'R2': TextEditingController(),
  };

  Future<void> saveSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifi_ip', ipController.text);

    for (var key in pressControllers.keys) {
      await prefs.setString('wifi_press_$key', pressControllers[key]!.text);
    }
    for (var key in releaseControllers.keys) {
      await prefs.setString('wifi_release_$key', releaseControllers[key]!.text);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Settings saved successfully!"),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WifiControllerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upperCaseInputFormatter =
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z]'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit WiFi & Button Settings'),
        actions: [
          TextButton(
            onPressed: () => saveSettings(context),
            child: const Text(
              "Save",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ...['F', 'B', 'L', 'R'].map((dir) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pressControllers['${dir}1'],
                          decoration: InputDecoration(
                            labelText: '$dir Press 1',
                            border: const OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: pressControllers['${dir}2'],
                          decoration: InputDecoration(
                            labelText: '$dir Press 2',
                            border: const OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            upperCaseInputFormatter,
                            LengthLimitingTextInputFormatter(1),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: releaseControllers['${dir}1'],
                          decoration: InputDecoration(
                            labelText: '$dir Release 1',
                            border: const OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: releaseControllers['${dir}2'],
                          decoration: InputDecoration(
                            labelText: '$dir Release 2',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PAGE 6: WIFI CONTROLLER PAGE ====================
class WifiControllerPage extends StatefulWidget {
  const WifiControllerPage({super.key});

  @override
  State<WifiControllerPage> createState() => _WifiControllerPageState();
}

class _WifiControllerPageState extends State<WifiControllerPage> {
  final Dio dio = Dio();

  Future<void> sendState(String state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String ip = prefs.getString('wifi_ip') ?? '192.168.4.1';
      final url = 'http://$ip/move?state=$state';
      await dio.get(url);
      showMessageSnackbar("Sent state: $state");
    } catch (e) {
      showErrorSnackbar("Error sending state: $e");
    }
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void showMessageSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Map<String, bool> _isPressed = {
    'F': false,
    'B': false,
    'L': false,
    'R': false,
  };

  double _sliderValue = 0;

  Widget controlButton(String key, IconData icon, String pressState, String releaseState) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed[key] = true);
        sendState(pressState);
      },
      onTapUp: (_) {
        setState(() => _isPressed[key] = false);
        sendState(releaseState);
      },
      onTapCancel: () {
        setState(() => _isPressed[key] = false);
        sendState(releaseState);
      },
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isPressed[key]! ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Controller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Adjust Range',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdjustRangePage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  controlButton('L', Icons.arrow_back, 'L', 'S'),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      controlButton('F', Icons.arrow_upward, 'F', 'H'),
                      const SizedBox(height: 20),
                      controlButton('B', Icons.arrow_downward, 'B', 'G'),
                    ],
                  ),
                  const SizedBox(width: 20),
                  controlButton('R', Icons.arrow_forward, 'R', 'I'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PAGE 7: ADJUST RANGE ====================
class AdjustRangePage extends StatefulWidget {
  const AdjustRangePage({super.key});

  @override
  State<AdjustRangePage> createState() => _AdjustRangePageState();
}

class _AdjustRangePageState extends State<AdjustRangePage> {
  final TextEditingController minController = TextEditingController(text: '0');
  final TextEditingController maxController = TextEditingController(text: '100');
  double sliderValue = 50;
  double minValue = 0;
  double maxValue = 100;

  final Dio dio = Dio();

  void updateRange() {
    setState(() {
      minValue = double.tryParse(minController.text) ?? 0;
      maxValue = double.tryParse(maxController.text) ?? 100;
      if (sliderValue < minValue) sliderValue = minValue;
      if (sliderValue > maxValue) sliderValue = maxValue;
    });
  }

  Future<void> sendSliderValue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String ip = prefs.getString('wifi_ip') ?? '192.168.4.1';
      final url = 'http://$ip/move?state=${sliderValue.toString()}';
      await dio.get(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sent slider value: ${sliderValue.toStringAsFixed(2)}"),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sending slider value: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust Range')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: minController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Min Value',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => updateRange(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max Value',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => updateRange(),
              ),
              const SizedBox(height: 40),
              Slider(
                value: sliderValue,
                min: minValue,
                max: maxValue,
                divisions: null,
                label: sliderValue.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() => sliderValue = value);
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Current: ${sliderValue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: sendSliderValue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("Confirm"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
