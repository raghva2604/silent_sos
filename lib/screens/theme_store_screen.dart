import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ui_mode_service.dart';
import '../core/ui_modes.dart';

class ThemeStoreScreen extends StatelessWidget {
  const ThemeStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uiModeService = Provider.of<UIModeService>(context);
    final modes = AppUIMode.values.toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          uiModeService.changeMode(AppUIMode.safety);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              uiModeService.changeMode(AppUIMode.safety);
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Interface Store'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose an interface',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick a disguise. The safety engine runs silently in the background.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: modes.length,
                  itemBuilder: (context, index) {
                    final mode = modes[index];
                    final isSelected = uiModeService.currentMode == mode;

                    return GestureDetector(
                      onTap: () {
                        uiModeService.changeMode(mode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${_modeName(mode)} interface'),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _buildModePreview(context, mode),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _modeName(mode),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _modeDescription(mode),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeName(AppUIMode mode) {
    switch (mode) {
      case AppUIMode.safety:
        return 'Safety';
      case AppUIMode.game:
        return 'Game';
      case AppUIMode.calculator:
        return 'Calculator';
      case AppUIMode.chat:
        return 'Chat';
      case AppUIMode.notes:
        return 'Notes';
      case AppUIMode.instagram:
        return 'Instagram';
      case AppUIMode.bank:
        return 'Bank';
      case AppUIMode.shopping:
        return 'Shopping';
      case AppUIMode.army:
        return 'Army';
    }
  }

  String _modeDescription(AppUIMode mode) {
    switch (mode) {
      case AppUIMode.safety:
        return 'Standard SOS interface with controls and status.';
      case AppUIMode.game:
        return 'Looks like a game; long press for hidden SOS.';
      case AppUIMode.calculator:
        return 'Looks like a calculator app.';
      case AppUIMode.chat:
        return 'Looks like a chat messenger app.';
      case AppUIMode.notes:
        return 'Looks like a notes editor.';
      case AppUIMode.instagram:
        return 'Looks like a photo sharing app.';
      case AppUIMode.bank:
        return 'Looks like a banking app.';
      case AppUIMode.shopping:
        return 'Looks like a shopping store app.';
      case AppUIMode.army:
        return 'Looks like a military dashboard.';
    }
  }

  Widget _buildModePreview(BuildContext context, AppUIMode mode) {
    switch (mode) {
      case AppUIMode.safety:
        return _previewSafety(context);
      case AppUIMode.game:
        return _previewGame(context);
      case AppUIMode.calculator:
        return _previewCalculator(context);
      case AppUIMode.chat:
        return _previewChat(context);
      case AppUIMode.notes:
        return _previewNotes(context);
      case AppUIMode.instagram:
        return _previewInstagram(context);
      case AppUIMode.bank:
        return _previewBank(context);
      case AppUIMode.shopping:
        return _previewShopping(context);
      case AppUIMode.army:
        return _previewArmy(context);
    }
  }

  Widget _previewSafety(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Icon(Icons.shield, size: 48, color: Colors.red.shade700),
      ),
    );
  }

  Widget _previewGame(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Center(
        child: Icon(Icons.videogame_asset, size: 48, color: Colors.blue.shade700),
      ),
    );
  }

  Widget _previewCalculator(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Icon(Icons.calculate, size: 48, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _previewChat(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Center(
        child: Icon(Icons.chat_bubble, size: 48, color: Colors.green.shade700),
      ),
    );
  }

  Widget _previewNotes(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Center(
        child: Icon(Icons.note, size: 48, color: Colors.orange.shade700),
      ),
    );
  }

  Widget _previewInstagram(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.pink.shade200),
      ),
      child: Center(
        child: Icon(Icons.camera_alt, size: 48, color: Colors.pink.shade700),
      ),
    );
  }

  Widget _previewBank(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Center(
        child: Icon(Icons.account_balance, size: 48, color: Colors.teal.shade700),
      ),
    );
  }

  Widget _previewShopping(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Center(
        child: Icon(Icons.shopping_cart, size: 48, color: Colors.purple.shade700),
      ),
    );
  }

  Widget _previewArmy(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade800.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade700),
      ),
      child: Center(
        child: Icon(Icons.security, size: 48, color: Colors.green.shade700),
      ),
    );
  }
}
