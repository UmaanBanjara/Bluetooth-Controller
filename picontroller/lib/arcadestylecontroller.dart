// ==================== ARCADE STYLE CONTROLLER ====================
import 'package:ble_controller/editpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArcadeControllerPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;

  const ArcadeControllerPage({
    Key? key,
    required this.device,
    required this.characteristic,
  }) : super(key: key);

  @override
  State<ArcadeControllerPage> createState() => _ArcadeControllerPageState();
}

class _ArcadeControllerPageState extends State<ArcadeControllerPage> {
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
  bool _isEditMode = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    loadButtonCommands();
    _listenToConnectionState();
  }

  void _listenToConnectionState() {
    widget.device.connectionState.listen((state) {
      setState(() {
        _isConnected = state == BluetoothConnectionState.connected;
      });
    });
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
    if (_isEditMode) return;
    setState(() {
      _isPressed[key] = true;
    });
    _isSending = true;
    _currentCommand = _pressControllers[key]!.text;
    continuouslySendCommand();
  }

  void handleButtonRelease(String key) {
    if (_isEditMode) return;
    setState(() {
      _isPressed[key] = false;
    });
    _isSending = false;
    sendData(_releaseControllers[key]!.text);
  }

  void continuouslySendCommand() async {
    while (_isSending) {
      await sendData(_currentCommand);
      await Future.delayed(const Duration(milliseconds: 1));
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

  void openEditPage(String key) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditButtonPage(
          buttonKey: key,
          pressController: _pressControllers[key]!,
          releaseController: _releaseControllers[key]!,
          onSave: () {
            saveButtonCommand(key);
            setState(() {});
          },
        ),
      ),
    ).then((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  Widget arcadeButton({
    required String key,
    required IconData icon,
    required String label,
    required Color topColor,
    required Color bottomColor,
  }) {
    return GestureDetector(
      onTapDown: (_isEditMode) ? null : (_) => handleButtonPress(key),
      onTapUp: (_isEditMode) ? null : (_) => handleButtonRelease(key),
      onTapCancel: (_isEditMode) ? null : () => handleButtonRelease(key),
      onTap: (_isEditMode) ? () => openEditPage(key) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isEditMode
                ? [Colors.orange.shade400, Colors.orange.shade700]
                : (_isPressed[key]!
                    ? [Colors.red.shade400, Colors.red.shade800]
                    : [topColor, bottomColor]),
          ),
          border: Border.all(
            color: _isPressed[key]! ? Colors.red.shade900 : Colors.black54,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: _isPressed[key]! ? Colors.red.withOpacity(0.6) : Colors.black.withOpacity(0.5),
              blurRadius: _isPressed[key]! ? 25 : 20,
              offset: Offset(0, _isPressed[key]! ? 5 : 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isEditMode ? Icons.edit_rounded : icon,
                  size: 65,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isEditMode ? 'EDIT' : label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = screenHeight * 0.4;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Arcade panel background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade900,
                    Colors.black,
                  ],
                ),
              ),
            ),
            
            // Main arcade button layout - Two columns
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Left column - Forward and Backward
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: buttonHeight,
                          child: arcadeButton(
                            key: 'F',
                            icon: Icons.arrow_upward_rounded,
                            label: 'FORWARD',
                            topColor: Colors.green.shade400,
                            bottomColor: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          height: buttonHeight,
                          child: arcadeButton(
                            key: 'B',
                            icon: Icons.arrow_downward_rounded,
                            label: 'BACK',
                            topColor: Colors.yellow.shade400,
                            bottomColor: Colors.yellow.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 30),
                  
                  // Right column - Left and Right
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: buttonHeight,
                          child: arcadeButton(
                            key: 'L',
                            icon: Icons.arrow_back_rounded,
                            label: 'LEFT',
                            topColor: Colors.purple.shade400,
                            bottomColor: Colors.purple.shade800,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          height: buttonHeight,
                          child: arcadeButton(
                            key: 'R',
                            icon: Icons.arrow_forward_rounded,
                            label: 'RIGHT',
                            topColor: Colors.cyan.shade400,
                            bottomColor: Colors.cyan.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Connection status at top center
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green.shade600 : Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Edit button at top right
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditMode = !_isEditMode;
                      if (!_isEditMode) {
                        _isSending = false;
                      }
                    });
                  },
                  icon: Icon(
                    _isEditMode ? Icons.check_circle_rounded : Icons.edit_rounded,
                    size: 24,
                  ),
                  label: Text(
                    _isEditMode ? 'DONE' : 'EDIT',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditMode ? Colors.green.shade600 : Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
