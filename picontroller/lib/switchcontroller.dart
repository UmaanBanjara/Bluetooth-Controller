import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SwitchControllerPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;

  const SwitchControllerPage({
    Key? key,
    required this.device,
    required this.characteristic,
  }) : super(key: key);

  @override
  State<SwitchControllerPage> createState() => _SwitchControllerPageState();
}

class _SwitchControllerPageState extends State<SwitchControllerPage> {
  final Map<String, TextEditingController> _onCommandControllers = {
    'btn1': TextEditingController(),
    'btn2': TextEditingController(),
    'btn3': TextEditingController(),
    'btn4': TextEditingController(),
  };
  
  final Map<String, TextEditingController> _offCommandControllers = {
    'btn1': TextEditingController(),
    'btn2': TextEditingController(),
    'btn3': TextEditingController(),
    'btn4': TextEditingController(),
  };
  
  final Map<String, TextEditingController> _labelControllers = {
    'btn1': TextEditingController(),
    'btn2': TextEditingController(),
    'btn3': TextEditingController(),
    'btn4': TextEditingController(),
  };

  bool _isSending = false;
  Map<String, bool> _isActive = {
    'btn1': false,
    'btn2': false,
    'btn3': false,
    'btn4': false,
  };
  bool _isEditMode = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    // Lock to landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    loadButtonData();
    _listenToConnectionState();
  }

  void _listenToConnectionState() {
    widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = state == BluetoothConnectionState.connected;
        });
      }
    });
  }

  Future<void> loadButtonData() async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in _onCommandControllers.keys) {
      final onCmdValue = prefs.getString('switch_on_cmd_$key') ?? 
          (key == 'btn1' ? 'F' : key == 'btn2' ? 'B' : key == 'btn3' ? 'L' : 'R');
      final offCmdValue = prefs.getString('switch_off_cmd_$key') ?? 'S';
      final labelValue = prefs.getString('switch_label_$key') ?? 
          (key == 'btn1' ? 'Forward' : key == 'btn2' ? 'Backward' : key == 'btn3' ? 'Left' : 'Right');
      
      _onCommandControllers[key]!.text = onCmdValue;
      _offCommandControllers[key]!.text = offCmdValue;
      _labelControllers[key]!.text = labelValue;
    }
    if (mounted) setState(() {});
  }

  Future<void> saveButtonData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('switch_on_cmd_$key', _onCommandControllers[key]!.text);
    await prefs.setString('switch_off_cmd_$key', _offCommandControllers[key]!.text);
    await prefs.setString('switch_label_$key', _labelControllers[key]!.text);
  }

  Future<void> sendData(String data) async {
    try {
      await widget.characteristic.write(data.codeUnits, withoutResponse: false);
    } catch (e) {
      if (mounted) {
        showErrorSnackbar("Failed to send data: $e");
      }
    }
  }

  String _getCombinedCommand() {
    // Combine all active button commands
    List<String> activeCommands = [];
    _isActive.forEach((key, isActive) {
      if (isActive) {
        activeCommands.add(_onCommandControllers[key]!.text);
      }
    });
    
    // If no buttons active, return stop command
    if (activeCommands.isEmpty) {
      return 'S';
    }
    
    // Join all active commands
    return activeCommands.join('');
  }

  void toggleButton(String key) async {
    if (_isEditMode || !mounted) return;
    
    setState(() {
      // Toggle the button state
      _isActive[key] = !_isActive[key]!;
    });
    
    // Check if any button is active
    bool anyActive = _isActive.values.any((active) => active);
    
    if (anyActive) {
      // At least one button is active - start/continue continuous sending
      if (!_isSending) {
        _isSending = true;
        continuouslySendCommand();
      }
    } else {
      // No buttons active - stop sending and send stop command
      _isSending = false;
      await sendData('S');
    }
  }

  void continuouslySendCommand() async {
    while (_isSending && mounted) {
      String command = _getCombinedCommand();
      await sendData(command);
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

  void openEditDialog(String key) async {
    // Switch to portrait for the dialog
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Longer delay to let orientation fully settle
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Get current values as simple strings
    final String initialOnCmd = _onCommandControllers[key]!.text;
    final String initialOffCmd = _offCommandControllers[key]!.text;
    final String initialLabel = _labelControllers[key]!.text;

    // Use a StatefulBuilder for the dialog
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _EditButtonDialog(
          initialOnCmd: initialOnCmd,
          initialOffCmd: initialOffCmd,
          initialLabel: initialLabel,
        );
      },
    );

    // Switch back to landscape
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Process result
    if (result != null && mounted) {
      setState(() {
        _onCommandControllers[key]!.text = result['onCmd']!;
        _offCommandControllers[key]!.text = result['offCmd']!;
        _labelControllers[key]!.text = result['label']!;
      });
      await saveButtonData(key);
    }
  }

  Widget circularButton({
    required String key,
    required Color color1,
    required Color color2,
  }) {
    final label = _labelControllers[key]!.text;
    final onCommand = _onCommandControllers[key]!.text;
    final offCommand = _offCommandControllers[key]!.text;
    final isActive = _isActive[key]!;
    
    return GestureDetector(
      onTap: _isEditMode ? () => openEditDialog(key) : () => toggleButton(key),
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: _isEditMode
                ? [Colors.orange.shade300, Colors.orange.shade700]
                : (isActive
                    ? [Colors.green.shade300, Colors.green.shade800]
                    : [color1, color2]),
          ),
          boxShadow: [
            BoxShadow(
              color: isActive 
                  ? Colors.green.withOpacity(0.6) 
                  : color2.withOpacity(0.5),
              blurRadius: isActive ? 30 : 20,
              offset: const Offset(0, 10),
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
                  _isEditMode 
                      ? Icons.edit_rounded 
                      : (isActive ? Icons.power_settings_new : Icons.circle),
                  size: 35,
                  color: Colors.white,
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _isEditMode 
                        ? 'EDIT' 
                        : (isActive ? 'ON' : label.toUpperCase()),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (!_isEditMode) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? 'ON: $onCommand' : 'OFF: $offCommand',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Stack(
          children: [
            // Main layout - 2x2 grid for landscape
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      circularButton(
                        key: 'btn1',
                        color1: Colors.blue.shade400,
                        color2: Colors.blue.shade700,
                      ),
                      const SizedBox(height: 30),
                      circularButton(
                        key: 'btn3',
                        color1: Colors.purple.shade400,
                        color2: Colors.purple.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      circularButton(
                        key: 'btn2',
                        color1: Colors.pink.shade400,
                        color2: Colors.pink.shade700,
                      ),
                      const SizedBox(height: 30),
                      circularButton(
                        key: 'btn4',
                        color1: Colors.orange.shade400,
                        color2: Colors.orange.shade700,
                      ),
                    ],
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
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
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _isSending = false;
    for (var controller in _onCommandControllers.values) {
      controller.dispose();
    }
    for (var controller in _offCommandControllers.values) {
      controller.dispose();
    }
    for (var controller in _labelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

// Separate StatefulWidget for the dialog to completely isolate controller lifecycle
class _EditButtonDialog extends StatefulWidget {
  final String initialOnCmd;
  final String initialOffCmd;
  final String initialLabel;

  const _EditButtonDialog({
    required this.initialOnCmd,
    required this.initialOffCmd,
    required this.initialLabel,
  });

  @override
  State<_EditButtonDialog> createState() => _EditButtonDialogState();
}

class _EditButtonDialogState extends State<_EditButtonDialog> {
  late final TextEditingController _onCmdController;
  late final TextEditingController _offCmdController;
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers in initState - this is the safest approach
    _onCmdController = TextEditingController(text: widget.initialOnCmd);
    _offCmdController = TextEditingController(text: widget.initialOffCmd);
    _labelController = TextEditingController(text: widget.initialLabel);
  }

  @override
  void dispose() {
    _onCmdController.dispose();
    _offCmdController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Edit Button',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BUTTON LABEL',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _labelController,
                maxLength: 20,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Enter button name',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(color: Colors.grey.shade600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'ON COMMAND (Continuous)',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _onCmdController,
                maxLength: 10,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Command when turned ON',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(color: Colors.grey.shade600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'OFF COMMAND (Single)',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _offCmdController,
                maxLength: 10,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Command when turned OFF',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(color: Colors.grey.shade600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade700, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Multiple buttons can be ON. Commands combine automatically.',
                        style: TextStyle(
                          color: Colors.blue.shade200,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'onCmd': _onCmdController.text,
                'offCmd': _offCmdController.text,
                'label': _labelController.text,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'SAVE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}