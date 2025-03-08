import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FirebaseUtils {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  static Future<List<Map<String, dynamic>>> loadGamesData() async {
    try {
      final snapshot = await _database.child('games').get();
      if (snapshot.exists) {
        final data = snapshot.value;
        debugPrint('Raw Firebase data: $data');

        if (data is List) {
          // Handle array structure
          return data.asMap().entries.map((entry) {
            final gameData = Map<String, dynamic>.from(entry.value as Map);
            gameData['id'] = entry.key.toString();
            return gameData;
          }).toList();
        } else if (data is Map) {
          // Handle map structure
          return data.entries.map((entry) {
            final gameData = Map<String, dynamic>.from(entry.value as Map);
            gameData['id'] = entry.key.toString();
            return gameData;
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error loading games data: $e');
      return [];
    }
  }

  static Future<void> listGames() async {
    try {
      final snapshot = await _database.child('games').get();
      if (snapshot.exists) {
        final data = snapshot.value;
        debugPrint('=== Database Contents ===');
        debugPrint(
          'Total games: ${data is List ? data.length : (data as Map).length}',
        );

        if (data is List) {
          for (var i = 0; i < data.length; i++) {
            final game = data[i];
            debugPrint('\nGame ${i + 1}:');
            debugPrint('ID: $i');
            debugPrint('Title: ${game['title']}');
            debugPrint('Thumbnail: ${game['thumbnail']}');
            debugPrint('Release Date: ${game['releaseDate']}');
            debugPrint('Size: ${game['size']}');
            debugPrint('Download Link: ${game['downloadLink']}');
            debugPrint('What\'s New: ${game['whatsNew']}');
          }
        } else if (data is Map) {
          data.forEach((key, value) {
            final game = value as Map;
            debugPrint('\nGame ID: $key');
            debugPrint('Title: ${game['title']}');
            debugPrint('Thumbnail: ${game['thumbnail']}');
            debugPrint('Release Date: ${game['releaseDate']}');
            debugPrint('Size: ${game['size']}');
            debugPrint('Download Link: ${game['downloadLink']}');
            debugPrint('What\'s New: ${game['whatsNew']}');
          });
        }
        debugPrint('\n=== End of Database Contents ===');
      } else {
        debugPrint('No games found in database');
      }
    } catch (e) {
      debugPrint('Error listing games: $e');
    }
  }

  static Future<void> addGame({
    required String title,
    required String thumbnail,
    required String releaseDate,
    required String downloadLink,
    required String whatsNew,
    required String size,
  }) async {
    try {
      final newGameRef = _database.child('games').push();
      await newGameRef.set({
        'title': title,
        'thumbnail': thumbnail,
        'releaseDate': releaseDate,
        'downloadLink': downloadLink,
        'whatsNew': whatsNew,
        'size': size,
      });
      debugPrint('Game added successfully');
    } catch (e) {
      debugPrint('Error adding game: $e');
      rethrow;
    }
  }

  static Future<void> updateGame({
    required String gameId,
    required Map<String, dynamic> gameData,
  }) async {
    try {
      await _database.child('games').child(gameId).update(gameData);
      debugPrint('Game updated successfully');
    } catch (e) {
      debugPrint('Error updating game: $e');
      rethrow;
    }
  }

  static Future<void> deleteGame(String gameId) async {
    try {
      await _database.child('games').child(gameId).remove();
      debugPrint('Game deleted successfully');
    } catch (e) {
      debugPrint('Error deleting game: $e');
      rethrow;
    }
  }
}
