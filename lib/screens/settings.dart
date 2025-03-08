import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tsbd_app/utils/app_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:tsbd_app/services/language_service.dart';
import 'package:tsbd_app/utils/download_manager.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onDarkModeChanged;
  final Function(bool) onAutoReloadChanged;
  final Function(bool) onNotificationsChanged;
  final Function(String) onDownloadLocationChanged;
  final Function(String) onLanguageChanged;
  final Function(String) onLayoutChanged;

  const SettingsScreen({
    super.key,
    required this.onDarkModeChanged,
    required this.onAutoReloadChanged,
    required this.onNotificationsChanged,
    required this.onDownloadLocationChanged,
    required this.onLanguageChanged,
    required this.onLayoutChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _autoReload = true;
  String _downloadLocation = 'Downloads';
  String _language = 'English';
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  String _layout = 'grid';
  String _appVersion = '';
  bool _useInternalStorage = true;
  final DownloadManager _downloadManager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _loadStoragePreference();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('darkMode') ?? false;
        _autoReload = prefs.getBool('autoReload') ?? true;
        _downloadLocation = prefs.getString('downloadLocation') ?? 'Downloads';
        _language = prefs.getString('language') ?? 'English';
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _layout = prefs.getString('layout') ?? 'grid';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load settings'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      debugPrint('Error loading app version: $e');
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  Future<void> _loadStoragePreference() async {
    try {
      final storageLocation =
          await _downloadManager.getPreferredStorageLocation();
      setState(() {
        _useInternalStorage = storageLocation == StorageLocation.internal;
      });
    } catch (e) {
      debugPrint('Error loading storage preference: $e');
    }
  }

  Future<void> _toggleStorageLocation(bool useInternal) async {
    try {
      final location =
          useInternal ? StorageLocation.internal : StorageLocation.external;
      await _downloadManager.setPreferredStorageLocation(location);
      setState(() {
        _useInternalStorage = useInternal;
      });

      // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useInternal
                  ? 'Downloads will be saved to app storage'
                  : 'Downloads will be saved to external storage',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error setting storage preference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to change storage location'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', _isDarkMode);
      await prefs.setBool('autoReload', _autoReload);
      await prefs.setString('downloadLocation', _downloadLocation);
      await prefs.setString('language', _language);
      await prefs.setBool('notifications', _notificationsEnabled);
      await prefs.setString('layout', _layout);
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save settings'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDownloadLocation() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/Downloads');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        setState(() {
          _downloadLocation = downloadDir.path;
        });
        await _saveSettings();
        widget.onDownloadLocationChanged(_downloadLocation);
      }
    } catch (e) {
      debugPrint('Error picking directory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to select directory'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to clear cache'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Get server version from Firestore
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('appConfig')
              .doc('settings')
              .get();

      if (!docSnapshot.exists) {
        throw Exception('Settings document not found');
      }

      final serverVersion = docSnapshot.data()?['version'] as String?;
      final updateMessage = docSnapshot.data()?['updateMessage'] as String?;
      final updateLink = docSnapshot.data()?['updateLink'] as String?;

      if (serverVersion == null ||
          updateMessage == null ||
          updateLink == null) {
        throw Exception('Missing update information');
      }

      // Compare versions
      if (_compareVersions(serverVersion, currentVersion) > 0) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('New Version Available!'),
                  content: Text(updateMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Later'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _downloadAndInstallUpdate(updateLink);
                      },
                      child: const Text('Download Update'),
                    ),
                  ],
                ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are using the latest version')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndInstallUpdate(String updateLink) async {
    try {
      final url = Uri.parse(updateLink);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch update URL';
      }
    } catch (e) {
      debugPrint('Error downloading update: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download update: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'settings')),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
            tooltip: t(context, 'about'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.surfaceContainerLowest.withOpacity(0.5),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProfileSection(context),
            const SizedBox(height: 24),
            _buildAnimatedSection(
              context,
              t(context, 'appearance'),
              Icons.palette,
              [
                _buildSettingTile(
                  context,
                  title: t(context, 'dark_mode'),
                  subtitle: t(context, 'enable_dark_theme'),
                  leading: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      _saveSettings();
                      widget.onDarkModeChanged(value);
                    },
                  ),
                ),
                _buildDivider(),
                _buildSettingTile(
                  context,
                  title: t(context, 'home_screen_layout'),
                  subtitle: t(context, 'choose_display'),
                  leading: Icon(
                    _layout == 'grid' ? Icons.grid_view : Icons.view_list,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'grid',
                        icon: const Icon(Icons.grid_view),
                        label: Text(t(context, 'grid')),
                      ),
                      ButtonSegment(
                        value: 'list',
                        icon: const Icon(Icons.view_list),
                        label: Text(t(context, 'list')),
                      ),
                    ],
                    selected: {_layout},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _layout = newSelection.first;
                      });
                      _saveSettings();
                      widget.onLayoutChanged(_layout);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAnimatedSection(
              context,
              t(context, 'general'),
              Icons.settings,
              [
                _buildSettingTile(
                  context,
                  title: t(context, 'auto_reload'),
                  subtitle: t(context, 'auto_refresh'),
                  leading: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: _autoReload,
                    onChanged: (value) {
                      setState(() {
                        _autoReload = value;
                      });
                      _saveSettings();
                      widget.onAutoReloadChanged(value);
                    },
                  ),
                ),
                _buildDivider(),
                _buildSettingTile(
                  context,
                  title: t(context, 'notifications'),
                  subtitle: t(context, 'enable_notifications'),
                  leading: Icon(
                    Icons.notifications,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _saveSettings();
                      widget.onNotificationsChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAnimatedSection(
              context,
              t(context, 'storage'),
              Icons.storage,
              [
                _buildSettingTile(
                  context,
                  title: t(context, 'download_location'),
                  subtitle: _downloadLocation,
                  leading: Icon(
                    Icons.folder,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onTap: _pickDownloadLocation,
                ),
                _buildDivider(),
                _buildSettingTile(
                  context,
                  title: 'App Storage',
                  subtitle: 'Store downloads inside the app',
                  leading: Icon(
                    Icons.save_alt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: Switch(
                    value: _useInternalStorage,
                    onChanged: _toggleStorageLocation,
                  ),
                ),
                _buildDivider(),
                _buildSettingTile(
                  context,
                  title: t(context, 'clear_cache'),
                  subtitle: t(context, 'clear_cache_desc'),
                  leading: Icon(
                    Icons.cleaning_services,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: _clearCache,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAnimatedSection(
              context,
              t(context, 'language'),
              Icons.language,
              [
                _buildSettingTile(
                  context,
                  title: t(context, 'language'),
                  subtitle: _language,
                  leading: Icon(
                    Icons.translate,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  trailing: DropdownButton<String>(
                    value: _language,
                    items: [
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(value: 'বাংলা', child: Text('বাংলা')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _language = value;
                        });
                        _saveSettings();
                        widget.onLanguageChanged(value);
                      }
                    },
                    underline: const SizedBox(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAnimatedSection(
              context,
              t(context, 'updates'),
              Icons.system_update,
              [
                _buildSettingTile(
                  context,
                  title: t(context, 'check_updates'),
                  subtitle: t(context, 'check_new_version'),
                  leading: Icon(
                    Icons.update,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onTap: _checkForUpdates,
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '${t(context, 'version')} $_appVersion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.tonal(
                onPressed: () => _clearCache(),
                child: Text(t(context, 'reset_app')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'welcome'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      t(context, 'customize_app'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        height: 1,
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: leading,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(t(context, 'app_name')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t(context, 'version')}: $_appVersion'),
                const SizedBox(height: 8),
                Text(
                  'TSBD App Store is your one-stop destination for downloading and managing Android applications.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t(context, 'close')),
              ),
            ],
          ),
    );
  }
}
