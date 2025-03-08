import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/admin_service.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({Key? key}) : super(key: key);

  @override
  _SettingsPanelState createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  final AdminService _adminService = AdminService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _versionController = TextEditingController();
  final _updateMessageController = TextEditingController();
  final _updateLinkController = TextEditingController();

  // Form values
  bool _maintenanceMode = false;
  bool _updateRequired = false;
  bool _forceUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _adminService.getSettings();
    setState(() {
      _maintenanceMode = settings.maintenanceMode;
      _updateRequired = settings.updateRequired;
      _forceUpdate = settings.forceUpdate;
      _versionController.text = settings.currentVersion;
      _updateMessageController.text = settings.updateMessage;
      _updateLinkController.text = settings.updateLink;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final settings = AppSettings(
        maintenanceMode: _maintenanceMode,
        currentVersion: _versionController.text,
        updateRequired: _updateRequired,
        updateMessage: _updateMessageController.text,
        updateLink: _updateLinkController.text,
        forceUpdate: _forceUpdate,
      );

      await _adminService.updateSettings(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        actions: [
          TextButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Save Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<AppSettings>(
        stream: _adminService.getSettingsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Maintenance Mode Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Maintenance Mode',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable Maintenance Mode'),
                            subtitle: const Text(
                              'When enabled, users will see a maintenance message',
                            ),
                            value: _maintenanceMode,
                            onChanged: (value) {
                              setState(() {
                                _maintenanceMode = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Version Control Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Version Control',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _versionController,
                            decoration: const InputDecoration(
                              labelText: 'Current Version',
                              hintText: 'e.g., 1.0.0',
                            ),
                            validator:
                                (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Update Required'),
                            subtitle: const Text(
                              'Show update message to users',
                            ),
                            value: _updateRequired,
                            onChanged: (value) {
                              setState(() {
                                _updateRequired = value;
                                if (!value) {
                                  _forceUpdate = false;
                                }
                              });
                            },
                          ),
                          if (_updateRequired) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _updateMessageController,
                              decoration: const InputDecoration(
                                labelText: 'Update Message',
                                hintText: 'Enter message to show users',
                              ),
                              maxLines: 3,
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _updateLinkController,
                              decoration: const InputDecoration(
                                labelText: 'Update Link',
                                hintText: 'Enter download link for the update',
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Force Update'),
                              subtitle: const Text(
                                'Users must update to continue using the app',
                              ),
                              value: _forceUpdate,
                              onChanged: (value) {
                                setState(() {
                                  _forceUpdate = value;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _versionController.dispose();
    _updateMessageController.dispose();
    _updateLinkController.dispose();
    super.dispose();
  }
}
