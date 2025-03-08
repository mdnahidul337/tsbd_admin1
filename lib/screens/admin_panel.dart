import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_data.dart';
import '../services/admin_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'settings_panel.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final AdminService _adminService = AdminService();
  bool _isMaintenanceMode = false;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _titleController = TextEditingController();
  final _downloadLinkController = TextEditingController();
  final _releaseDateController = TextEditingController();
  final _sizeController = TextEditingController();
  final _thumbnailController = TextEditingController();
  final _whatsNewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMaintenanceMode();
  }

  Future<void> _loadMaintenanceMode() async {
    final status = await _adminService.getMaintenanceMode();
    setState(() {
      _isMaintenanceMode = status;
    });
  }

  void _clearForm() {
    _titleController.clear();
    _downloadLinkController.clear();
    _releaseDateController.clear();
    _sizeController.clear();
    _thumbnailController.clear();
    _whatsNewController.clear();
  }

  Future<void> _addNewApp() async {
    if (_formKey.currentState!.validate()) {
      final newApp = AppData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        downloadLink: _downloadLinkController.text,
        releaseDate: _releaseDateController.text,
        size: _sizeController.text,
        thumbnail: _thumbnailController.text,
        whatsNew: _whatsNewController.text,
      );

      await _adminService.addApp(newApp);
      _clearForm();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App added successfully')));
    }
  }

  Future<void> _editApp(AppData app) async {
    _titleController.text = app.title;
    _downloadLinkController.text = app.downloadLink;
    _releaseDateController.text = app.releaseDate;
    _sizeController.text = app.size;
    _thumbnailController.text = app.thumbnail;
    _whatsNewController.text = app.whatsNew;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit App'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _downloadLinkController,
                      decoration: const InputDecoration(
                        labelText: 'Download Link',
                      ),
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _releaseDateController,
                      decoration: const InputDecoration(
                        labelText: 'Release Date',
                      ),
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          _releaseDateController.text =
                              date.toString().split(' ')[0];
                        }
                      },
                    ),
                    TextFormField(
                      controller: _sizeController,
                      decoration: const InputDecoration(labelText: 'Size'),
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _thumbnailController,
                      decoration: const InputDecoration(
                        labelText: 'Thumbnail URL',
                      ),
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _whatsNewController,
                      decoration: const InputDecoration(
                        labelText: "What's New",
                      ),
                      maxLines: 3,
                      validator:
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final updatedApp = app.copyWith(
                      title: _titleController.text,
                      downloadLink: _downloadLinkController.text,
                      releaseDate: _releaseDateController.text,
                      size: _sizeController.text,
                      thumbnail: _thumbnailController.text,
                      whatsNew: _whatsNewController.text,
                    );
                    await _adminService.updateApp(updatedApp);
                    Navigator.pop(context);
                    _clearForm();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TSBD Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPanel()),
              );
            },
          ),
          Switch(
            value: _isMaintenanceMode,
            onChanged: (value) async {
              await _adminService.setMaintenanceMode(value);
              setState(() {
                _isMaintenanceMode = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? 'Maintenance mode enabled'
                        : 'Maintenance mode disabled',
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text('Maintenance Mode'),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left side - App List
          Expanded(
            flex: 2,
            child: StreamBuilder<List<AppData>>(
              stream: _adminService.getApps(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final apps = snapshot.data!;
                return ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(app.thumbnail),
                        ),
                        title: Text(app.title),
                        subtitle: Text(
                          'Release Date: ${app.releaseDate}\nSize: ${app.size}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editApp(app),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: Text(
                                          'Are you sure you want to delete ${app.title}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                );

                                if (confirm == true) {
                                  await _adminService.deleteApp(app.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('App deleted successfully'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Right side - Add New App Form
          Expanded(
            flex: 1,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const Text(
                        'Add New App',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _downloadLinkController,
                        decoration: const InputDecoration(
                          labelText: 'Download Link',
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _releaseDateController,
                        decoration: const InputDecoration(
                          labelText: 'Release Date',
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            _releaseDateController.text =
                                date.toString().split(' ')[0];
                          }
                        },
                      ),
                      TextFormField(
                        controller: _sizeController,
                        decoration: const InputDecoration(labelText: 'Size'),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _thumbnailController,
                        decoration: const InputDecoration(
                          labelText: 'Thumbnail URL',
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _whatsNewController,
                        decoration: const InputDecoration(
                          labelText: "What's New",
                        ),
                        maxLines: 3,
                        validator:
                            (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addNewApp,
                        child: const Text('Add App'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _downloadLinkController.dispose();
    _releaseDateController.dispose();
    _sizeController.dispose();
    _thumbnailController.dispose();
    _whatsNewController.dispose();
    super.dispose();
  }
}
