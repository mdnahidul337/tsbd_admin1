import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_data.dart';
import '../models/app_settings.dart';

class AdminService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final String _maintenanceKey = 'maintenance_mode';

  // Database references
  late final DatabaseReference _appsRef;
  late final DatabaseReference _settingsRef;

  AdminService() {
    _appsRef = _database.ref().child('apps');
    _settingsRef = _database.ref().child('settings');
  }

  // Add new app
  Future<void> addApp(AppData app) async {
    await _appsRef.child(app.id).set(app.toMap());
  }

  // Update existing app
  Future<void> updateApp(AppData app) async {
    await _appsRef.child(app.id).update(app.toMap());
  }

  // Delete app
  Future<void> deleteApp(String appId) async {
    await _appsRef.child(appId).remove();
  }

  // Get all apps
  Stream<List<AppData>> getApps() {
    return _appsRef.onValue.map((event) {
      final Map<dynamic, dynamic>? values = event.snapshot.value as Map?;

      if (values == null) return [];

      return values.entries.map((entry) {
        return AppData.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
          entry.key.toString(),
        );
      }).toList();
    });
  }

  // Get single app
  Future<AppData?> getApp(String appId) async {
    final snapshot = await _appsRef.child(appId).get();
    if (snapshot.exists) {
      return AppData.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
        appId,
      );
    }
    return null;
  }

  // Settings operations
  Future<void> updateSettings(AppSettings settings) async {
    await _settingsRef.update(settings.toMap());

    // Also store maintenance mode in SharedPreferences for offline access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_maintenanceKey, settings.maintenanceMode);
  }

  Future<AppSettings> getSettings() async {
    try {
      final snapshot = await _settingsRef.get();
      if (snapshot.exists) {
        return AppSettings.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
        );
      }
      return AppSettings(currentVersion: '1.0.0');
    } catch (e) {
      print('Error getting settings: $e');
      // Fallback to default settings
      return AppSettings(currentVersion: '1.0.0');
    }
  }

  Stream<AppSettings> getSettingsStream() {
    return _settingsRef.onValue.map((event) {
      if (!event.snapshot.exists) {
        return AppSettings(currentVersion: '1.0.0');
      }
      return AppSettings.fromMap(
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  // Specific settings operations
  Future<void> setMaintenanceMode(bool enabled) async {
    final settings = await getSettings();
    await updateSettings(settings.copyWith(maintenanceMode: enabled));
  }

  Future<void> setUpdateInfo({
    required String version,
    required bool updateRequired,
    required String message,
    required String link,
    required bool forceUpdate,
  }) async {
    final settings = await getSettings();
    await updateSettings(
      settings.copyWith(
        currentVersion: version,
        updateRequired: updateRequired,
        updateMessage: message,
        updateLink: link,
        forceUpdate: forceUpdate,
      ),
    );
  }

  Future<bool> getMaintenanceMode() async {
    try {
      final settings = await getSettings();
      return settings.maintenanceMode;
    } catch (e) {
      print('Error getting maintenance mode: $e');
      // Fallback to SharedPreferences if Firebase is not available
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_maintenanceKey) ?? false;
    }
  }

  // Batch update apps
  Future<void> batchUpdateApps(List<AppData> apps) async {
    final Map<String, dynamic> updates = {};
    for (var app in apps) {
      updates['/apps/${app.id}'] = app.toMap();
    }
    await _database.ref().update(updates);
  }

  // Get app statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final snapshot = await _appsRef.get();
    final Map<dynamic, dynamic>? values = snapshot.value as Map?;

    int totalApps = values?.length ?? 0;
    int activeApps = 0;
    int totalDownloads = 0;

    if (values != null) {
      for (var app in values.values) {
        final appData = Map<String, dynamic>.from(app as Map);
        if (appData['isActive'] == true) activeApps++;
        totalDownloads += (appData['downloads'] ?? 0) as int;
      }
    }

    return {
      'totalApps': totalApps,
      'activeApps': activeApps,
      'totalDownloads': totalDownloads,
    };
  }

  // Listen to maintenance mode changes
  Stream<bool> maintenanceModeStream() {
    return _settingsRef.child('maintenance').onValue.map((event) {
      if (!event.snapshot.exists) return false;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data['enabled'] ?? false;
    });
  }
}
