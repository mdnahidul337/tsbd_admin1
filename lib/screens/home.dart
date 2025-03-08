import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tsbd_app/screens/downloader.dart';
import 'package:tsbd_app/screens/info.dart';
import 'package:tsbd_app/screens/downloads.dart';
import 'package:tsbd_app/screens/settings.dart';
import 'package:tsbd_app/screens/maintenance_mode.dart';
import 'package:tsbd_app/utils/firebase_utils.dart';
import 'package:tsbd_app/utils/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsbd_app/utils/download_manager.dart';
import 'package:tsbd_app/widgets/banner_ad_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show exit;

class ImageUrlHelper {
  static String convertToDirectUrl(String url) {
    if (url.isEmpty) return url;

    // Remove Google Drive and Dropbox handling
    // Only allow URLs from ddownload.com and modsfire.com
    if (url.contains('ddownload.com') || url.contains('modsfire.com')) {
      return url;
    }

    debugPrint('Invalid URL: $url');
    return url;
  }

  static List<String> getAlternativeUrls(String url) {
    List<String> urls = [url];

    try {
      // Original URL
      urls.add(url);

      // Convert to direct URL
      String directUrl = convertToDirectUrl(url);
      if (directUrl != url) {
        urls.add(directUrl);
      }

      // For Google Drive, add alternative formats
      if (url.contains('drive.google.com')) {
        if (url.contains('/file/d/')) {
          final fileId = url.split('/d/')[1].split('/')[0];
          urls.add('https://drive.google.com/uc?export=view&id=$fileId');
          urls.add('https://drive.google.com/uc?export=download&id=$fileId');
        }
      }

      // For Dropbox, add alternative formats
      if (url.contains('dropbox.com')) {
        urls.add(
          url.replaceAll('www.dropbox.com', 'dl.dropboxusercontent.com'),
        );
        urls.add(
          url
              .replaceAll('www.dropbox.com', 'dl.dropboxusercontent.com')
              .replaceAll('?dl=0', '')
              .replaceAll('?dl=1', ''),
        );
      }

      // Remove duplicates
      urls = urls.toSet().toList();

      debugPrint('Generated alternative URLs: $urls');
      return urls;
    } catch (e) {
      debugPrint('Error generating alternative URLs: $e');
      return [url];
    }
  }
}

class GameFile {
  final String title;
  final String thumbnail;
  final String releaseDate;
  final String downloadLink;
  final String whatsNew;
  final String size;
  final String? id;

  GameFile({
    required this.title,
    required this.thumbnail,
    required this.releaseDate,
    required this.downloadLink,
    required this.whatsNew,
    required this.size,
    this.id,
  });

  factory GameFile.fromMap(Map<dynamic, dynamic> map) {
    debugPrint('Converting map to GameFile: $map');
    return GameFile(
      id: map['id']?.toString(),
      title: map['title']?.toString() ?? '',
      thumbnail: map['thumbnail']?.toString() ?? '',
      releaseDate: map['releaseDate']?.toString() ?? '',
      downloadLink: map['downloadLink']?.toString() ?? '',
      whatsNew: map['whatsNew']?.toString() ?? '',
      size: map['size']?.toString() ?? '',
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(bool) onDarkModeChanged;
  final Function(String) onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.onDarkModeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GameFile> _games = [];
  List<GameFile> _filteredGames = [];
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _maintenanceMode = false;
  bool _isDarkMode = false;
  bool _autoReload = true;
  bool _notificationsEnabled = true;
  String _downloadLocation = 'Downloads';
  String _language = 'English';
  String _layout = 'grid';
  final DownloadManager _downloadManager = DownloadManager();
  static const int _newGameThresholdDays = 30;

  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen initState called');
    _loadGames();
    _setupMaintenanceMode();
    _loadSettings();
    _checkForMandatoryUpdates();
    FirebaseUtils.listGames().then((_) {
      debugPrint('Database listing completed');
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _autoReload = prefs.getBool('autoReload') ?? true;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _downloadLocation = prefs.getString('downloadLocation') ?? 'Downloads';
      _language = prefs.getString('language') ?? 'English';
      _layout = prefs.getString('layout') ?? 'grid';
    });
  }

  void _handleDarkModeChanged(bool value) {
    setState(() {
      _isDarkMode = value;
    });
    widget.onDarkModeChanged(value);
  }

  void _handleAutoReloadChanged(bool value) {
    setState(() {
      _autoReload = value;
    });
    if (value) {
      _loadGames();
    }
  }

  void _handleNotificationsChanged(bool value) {
    setState(() {
      _notificationsEnabled = value;
    });
  }

  void _handleDownloadLocationChanged(String value) {
    setState(() {
      _downloadLocation = value;
    });
  }

  void _handleLanguageChanged(String value) {
    setState(() {
      _language = value;
    });
    widget.onLanguageChanged(value);
  }

  void _handleLayoutChanged(String value) {
    setState(() {
      _layout = value;
    });
  }

  void _setupMaintenanceMode() {
    debugPrint('Setting up maintenance mode listener...');
    AppConfig.getMaintenanceModeStream().listen(
      (isMaintenanceMode) {
        debugPrint('Maintenance mode state changed to: $isMaintenanceMode');
        setState(() {
          _maintenanceMode = isMaintenanceMode;
        });
      },
      onError: (error) {
        debugPrint('Error in maintenance mode stream: $error');
      },
    );
  }

  Future<void> _loadGames() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final gamesData = await FirebaseUtils.loadGamesData();
      debugPrint('Loaded ${gamesData.length} games from Firebase');

      final games =
          gamesData.map((data) {
            debugPrint('Processing game: ${data['title']}');
            debugPrint('Image URL: ${data['thumbnail']}');
            return GameFile.fromMap(data);
          }).toList();

      // Sort games by release date (newest first)
      games.sort((a, b) {
        // Parse dates in format "DD/MM/YYYY" or similar
        DateTime? dateA = _parseReleaseDate(a.releaseDate);
        DateTime? dateB = _parseReleaseDate(b.releaseDate);

        // If dates can't be parsed, keep original order
        if (dateA == null || dateB == null) {
          return 0;
        }

        // Sort in descending order (newest first)
        return dateB.compareTo(dateA);
      });

      setState(() {
        _games = games;
        _filteredGames = games;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading games: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to parse release dates in various formats
  DateTime? _parseReleaseDate(String dateStr) {
    try {
      // Try to parse common date formats

      // Format: DD/MM/YYYY
      final regexDMY = RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})');
      final matchDMY = regexDMY.firstMatch(dateStr);
      if (matchDMY != null) {
        final day = int.parse(matchDMY.group(1)!);
        final month = int.parse(matchDMY.group(2)!);
        var year = int.parse(matchDMY.group(3)!);
        // Handle 2-digit years
        if (year < 100) {
          year += 2000;
        }
        return DateTime(year, month, day);
      }

      // Format: Month YYYY (e.g., "January 2023" or "Jan 2023")
      final regexMonthYear = RegExp(r'([A-Za-z]+)\s+(\d{4})');
      final matchMonthYear = regexMonthYear.firstMatch(dateStr);
      if (matchMonthYear != null) {
        final monthStr = matchMonthYear.group(1)!.toLowerCase();
        final year = int.parse(matchMonthYear.group(2)!);

        final months = {
          'january': 1,
          'jan': 1,
          'february': 2,
          'feb': 2,
          'march': 3,
          'mar': 3,
          'april': 4,
          'apr': 4,
          'may': 5,
          'june': 6,
          'jun': 6,
          'july': 7,
          'jul': 7,
          'august': 8,
          'aug': 8,
          'september': 9,
          'sep': 9,
          'sept': 9,
          'october': 10,
          'oct': 10,
          'november': 11,
          'nov': 11,
          'december': 12,
          'dec': 12,
        };

        final month = months[monthStr] ?? 1;
        return DateTime(year, month, 1);
      }

      // Format: YYYY-MM-DD
      final regexYMD = RegExp(r'(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})');
      final matchYMD = regexYMD.firstMatch(dateStr);
      if (matchYMD != null) {
        final year = int.parse(matchYMD.group(1)!);
        final month = int.parse(matchYMD.group(2)!);
        final day = int.parse(matchYMD.group(3)!);
        return DateTime(year, month, day);
      }

      // Format: Just the year (YYYY)
      final regexYear = RegExp(r'(\d{4})');
      final matchYear = regexYear.firstMatch(dateStr);
      if (matchYear != null) {
        final year = int.parse(matchYear.group(1)!);
        return DateTime(year, 1, 1);
      }

      // If no format matches, return null
      return null;
    } catch (e) {
      debugPrint('Error parsing date "$dateStr": $e');
      return null;
    }
  }

  void _filterGames(String query) {
    setState(() {
      _filteredGames =
          _games.where((game) {
            return game.title.toLowerCase().contains(query.toLowerCase());
          }).toList();
    });
  }

  Future<void> _checkForMandatoryUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('Current app version: $currentVersion');

      // Get server version from Firestore
      final docSnapshot =
          await FirebaseFirestore.instance
              .collection('appConfig')
              .doc('settings')
              .get();

      if (!docSnapshot.exists) {
        debugPrint('Settings document not found in Firestore');
        return;
      }

      final serverVersion = docSnapshot.data()?['version'] as String?;
      final updateMessage = docSnapshot.data()?['updateMessage'] as String?;
      final updateLink = docSnapshot.data()?['updateLink'] as String?;
      final forceUpdate = docSnapshot.data()?['forceUpdate'] as bool? ?? false;

      if (serverVersion == null ||
          updateMessage == null ||
          updateLink == null) {
        debugPrint('Missing update information in Firestore');
        return;
      }

      debugPrint('Server version: $serverVersion, Force update: $forceUpdate');

      // Compare versions
      if (_compareVersions(serverVersion, currentVersion) > 0 && forceUpdate) {
        // Show non-dismissible update dialog
        if (mounted) {
          _showForceUpdateDialog(updateMessage, updateLink);
        }
      }
    } catch (e) {
      debugPrint('Error checking for mandatory updates: $e');
    }
  }

  void _showForceUpdateDialog(String updateMessage, String updateLink) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button to close the dialog
      builder: (BuildContext context) {
        return WillPopScope(
          // Prevent back button from dismissing the dialog
          onWillPop: () async => false,
          child: AlertDialog(
            title: Text('Update Required'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new version of the app is available and required to continue.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(updateMessage),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You cannot use the app until you update.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
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
              FilledButton.icon(
                onPressed: () => _downloadAndInstallUpdate(updateLink),
                icon: Icon(Icons.system_update),
                label: Text('Update Now'),
                style: FilledButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Close the app
                  exit(0);
                },
                icon: Icon(Icons.close),
                label: Text('Exit App'),
              ),
            ],
          ),
        );
      },
    );
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
            content: Text('Failed to open update link: $e'),
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

  bool _isNewGame(String releaseDate) {
    final DateTime? parsedDate = _parseReleaseDate(releaseDate);
    if (parsedDate == null) return false;

    final DateTime now = DateTime.now();
    final Duration difference = now.difference(parsedDate);
    return difference.inDays <= _newGameThresholdDays;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('HomeScreen build called, maintenance mode: $_maintenanceMode');
    if (_maintenanceMode) {
      debugPrint('Showing maintenance screen');
      return const MaintenanceModeScreen();
    }
    debugPrint('Showing normal app screen');
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search games...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: _filterGames,
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                    : _selectedIndex == 0
                    ? _layout == 'grid'
                        ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: _filteredGames.length,
                          itemBuilder: (context, index) {
                            final game = _filteredGames[index];
                            return _buildGameCard(game);
                          },
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredGames.length,
                          itemBuilder: (context, index) {
                            final game = _filteredGames[index];
                            return _buildGameListItem(game);
                          },
                        )
                    : _selectedIndex == 1
                    ? const DownloadsScreen()
                    : _selectedIndex == 2
                    ? const InfoScreen()
                    : SettingsScreen(
                      onDarkModeChanged: _handleDarkModeChanged,
                      onAutoReloadChanged: _handleAutoReloadChanged,
                      onNotificationsChanged: _handleNotificationsChanged,
                      onDownloadLocationChanged: _handleDownloadLocationChanged,
                      onLanguageChanged: _handleLanguageChanged,
                      onLayoutChanged: _handleLayoutChanged,
                    ),
          ),
          const BannerAdWidget(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(GameFile game) {
    final bool isNew = _isNewGame(game.releaseDate);
    return Card(
      elevation: 4,
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DownloaderScreen(game: game),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'game-${game.id ?? game.title}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: _buildImageWithFallback(game.thumbnail),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.new_releases,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'NEW',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        game.size,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: Text(
                      game.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.releaseDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DownloaderScreen(game: game),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameListItem(GameFile game) {
    final bool isNew = _isNewGame(game.releaseDate);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DownloaderScreen(game: game),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'game-${game.id ?? game.title}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: _buildImageWithFallback(game.thumbnail),
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.new_releases,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'NEW',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 120, // Match image height
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              game.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              game.size,
                              style: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Released: ${game.releaseDate}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => DownloaderScreen(game: game),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWithFallback(String url) {
    final directUrl = ImageUrlHelper.convertToDirectUrl(url);
    debugPrint('Loading image from URL: $directUrl');

    return CachedNetworkImage(
      imageUrl: directUrl,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        debugPrint('Error loading image: $url');
        debugPrint('Error details: $error');
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
          ),
        );
      },
      memCacheWidth: 300,
      memCacheHeight: 300,
      maxWidthDiskCache: 300,
      maxHeightDiskCache: 300,
    );
  }
}
