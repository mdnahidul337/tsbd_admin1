import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AppConfig {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final DatabaseReference _settingsRef = _database.ref().child(
    'settings',
  );
  static const String _maintenanceKey = 'maintenance_mode';
  static StreamController<bool>? _maintenanceModeController;

  static Future<void> initialize() async {
    _maintenanceModeController = StreamController<bool>.broadcast();

    // Set up listener for maintenance mode changes
    _settingsRef.child('maintenance').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final bool isMaintenanceMode = data['enabled'] ?? false;
        _maintenanceModeController?.add(isMaintenanceMode);

        // Update SharedPreferences
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_maintenanceKey, isMaintenanceMode);
        });
      }
    });
  }

  static Future<bool> checkMaintenanceMode() async {
    try {
      final snapshot = await _settingsRef.child('maintenance').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data['enabled'] ?? false;
      }
    } catch (e) {
      print('Error checking maintenance mode: $e');
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_maintenanceKey) ?? false;
    }
    return false;
  }

  static Stream<bool> getMaintenanceModeStream() {
    if (_maintenanceModeController == null) {
      throw StateError('AppConfig not initialized. Call initialize() first.');
    }
    return _maintenanceModeController!.stream;
  }

  static void dispose() {
    _maintenanceModeController?.close();
    _maintenanceModeController = null;
  }
}
