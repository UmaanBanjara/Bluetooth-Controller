// ==================== CONTROLLER SELECTION PAGE ====================
import 'package:ble_controller/arcadestylecontroller.dart';
import 'package:ble_controller/bluetoothcontrollers.dart';
import 'package:ble_controller/dpadstylecontroller.dart';
import 'package:ble_controller/joystickstylecontroller.dart';
import 'package:ble_controller/switchcontroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControllerSelectionPage extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic characteristic;

  const ControllerSelectionPage({
    Key? key,
    required this.device,
    required this.characteristic,
  }) : super(key: key);

  @override
  State<ControllerSelectionPage> createState() => _ControllerSelectionPageState();
}

class _ControllerSelectionPageState extends State<ControllerSelectionPage> {
  String? _selectedController;

  @override
  void initState() {
    super.initState();
    _loadSelectedController();
  }

  Future<void> _loadSelectedController() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedController = prefs.getString('selected_controller');
    });
  }

  Future<void> _saveSelectedController(String controllerType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_controller', controllerType);
    setState(() {
      _selectedController = controllerType;
    });
  }

  void _navigateToController(String controllerType) {
    _saveSelectedController(controllerType);
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    Widget controllerPage;
    switch (controllerType) {
      case 'split':
        controllerPage = ControllerPage(
          device: widget.device,
          characteristic: widget.characteristic,
        );
        break;
      case 'joystick':
        controllerPage = JoystickControllerPage(
          device: widget.device,
          characteristic: widget.characteristic,
        );
        break;
      case 'dpad':
        controllerPage = DPadControllerPage(
          device: widget.device,
          characteristic: widget.characteristic,
        );
        break;
      case 'arcade':
        controllerPage = ArcadeControllerPage(
          device: widget.device,
          characteristic: widget.characteristic,
        );
        break;
      case 'switch':
        // Add your switch controller page here when created
        controllerPage = SwitchControllerPage(
          device: widget.device,
          characteristic: widget.characteristic,
        );
        break;
      default:
        controllerPage = ControllerPage(
          device: widget.device,
          characteristic: widget.characteristic,
        );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => controllerPage),
    ).then((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  Widget _buildControllerCard({
    required String title,
    required String description,
    required IconData icon,
    required String controllerType,
    required Color color1,
    required Color color2,
  }) {
    final isSelected = _selectedController == controllerType;
    
    return GestureDetector(
      onTap: () => _navigateToController(controllerType),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color1, color2],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color2.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'SELECTED',
                                style: TextStyle(
                                  color: color2,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 30,
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
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CHOOSE YOUR CONTROLLER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade900],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Select a controller layout that best suits your preference',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Controller options
            _buildControllerCard(
              title: 'SPLIT VIEW',
              description: 'Full-screen split buttons - simple and direct control',
              icon: Icons.view_column_rounded,
              controllerType: 'split',
              color1: Colors.blue.shade400,
              color2: Colors.blue.shade700,
            ),
            
            _buildControllerCard(
              title: 'JOYSTICK',
              description: 'Classic joystick layout with circular buttons in cross pattern',
              icon: Icons.control_camera_rounded,
              controllerType: 'joystick',
              color1: Colors.purple.shade400,
              color2: Colors.purple.shade700,
            ),
            
            _buildControllerCard(
              title: 'D-PAD',
              description: 'Traditional gaming D-pad - console-style controls',
              icon: Icons.gamepad_rounded,
              controllerType: 'dpad',
              color1: Colors.teal.shade400,
              color2: Colors.teal.shade700,
            ),
            
            _buildControllerCard(
              title: 'ARCADE',
              description: 'Retro arcade machine style with colorful action buttons',
              icon: Icons.sports_esports_rounded,
              controllerType: 'arcade',
              color1: Colors.orange.shade400,
              color2: Colors.orange.shade700,
            ),
            
            _buildControllerCard(
              title: 'SWITCH',
              description: 'Nintendo Switch style with separated Joy-Con layout',
              icon: Icons.switch_account_rounded,
              controllerType: 'switch',
              color1: Colors.red.shade400,
              color2: Colors.red.shade700,
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}