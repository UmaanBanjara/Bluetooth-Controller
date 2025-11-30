// ==================== PAGE 4: CLEAN EDIT BUTTON PAGE ====================
import 'package:flutter/material.dart';

class EditButtonPage extends StatelessWidget {
  final String buttonKey;
  final TextEditingController pressController;
  final TextEditingController releaseController;
  final VoidCallback onSave;

  const EditButtonPage({
    Key? key,
    required this.buttonKey,
    required this.pressController,
    required this.releaseController,
    required this.onSave,
  }) : super(key: key);

  String getButtonName(String key) {
    switch (key) {
      case 'F':
        return 'Forward';
      case 'B':
        return 'Backward';
      case 'L':
        return 'Left';
      case 'R':
        return 'Right';
      default:
        return key;
    }
  }

  IconData getButtonIcon(String key) {
    switch (key) {
      case 'F':
        return Icons.arrow_upward_rounded;
      case 'B':
        return Icons.arrow_downward_rounded;
      case 'L':
        return Icons.arrow_back_rounded;
      case 'R':
        return Icons.arrow_forward_rounded;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color getAccentColor(String key) {
    switch (key) {
      case 'F':
        return Colors.blue;
      case 'B':
        return Colors.purple;
      case 'L':
        return Colors.teal;
      case 'R':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = getAccentColor(buttonKey);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(getButtonIcon(buttonKey), color: accentColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Edit ${getButtonName(buttonKey)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 40 : 24,
                vertical: isLandscape ? 16 : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isLandscape ? 32 : 48),
                ),
                child: isLandscape
                    ? _buildLandscapeLayout(accentColor)
                    : _buildPortraitLayout(accentColor),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Input cards
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildInputCard(
                label: 'Press Signal',
                icon: Icons.touch_app_rounded,
                controller: pressController,
                accentColor: accentColor,
                hint: 'Enter press command',
              ),
              const SizedBox(height: 16),
              _buildInputCard(
                label: 'Release Signal',
                icon: Icons.pan_tool_rounded,
                controller: releaseController,
                accentColor: accentColor,
                hint: 'Enter release command',
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Right side - Save button
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    onSave();
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: accentColor),
                            const SizedBox(width: 12),
                            const Text(
                              'Saved successfully!',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF2A2A2A),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.save, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        
        _buildInputCard(
          label: 'Press Signal',
          icon: Icons.touch_app_rounded,
          controller: pressController,
          accentColor: accentColor,
          hint: 'Enter press command',
        ),
        
        const SizedBox(height: 24),
        
        _buildInputCard(
          label: 'Release Signal',
          icon: Icons.pan_tool_rounded,
          controller: releaseController,
          accentColor: accentColor,
          hint: 'Enter release command',
        ),
        
        const SizedBox(height: 40),
        
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              onSave();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: accentColor),
                      const SizedBox(width: 12),
                      const Text(
                        'Saved successfully!',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF2A2A2A),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required Color accentColor,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}