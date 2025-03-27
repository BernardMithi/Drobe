// lib/services/outfitStorage.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/outfit.dart';
import 'package:uuid/uuid.dart';
import 'hiveServiceManager.dart';

class OutfitStorageService {
  static const String outfitsBoxName = OUTFITS_BOX_NAME;
  static final uuid = Uuid();
  static bool _initialized = false;

  /// Initialize the service
  static Future<void> init() async {
    if (_initialized) {
      debugPrint('OutfitStorageService already initialized, skipping');
      return;
    }

    try {
      debugPrint('Initializing OutfitStorageService...');

      // Make sure HiveManager is initialized
      await HiveManager().init();

      // Open the outfits box
      await HiveManager().getBox(outfitsBoxName);

      _initialized = true;
      debugPrint('OutfitStorageService initialized successfully');

      // Log the number of outfits
      final outfits = await getAllOutfits();
      debugPrint('Loading all outfits. Total in box: ${outfits.length}');
    } catch (e) {
      debugPrint('Error initializing OutfitStorageService: $e');
    }
  }

  /// Save an outfit to storage
  static Future<void> saveOutfit(Outfit outfit) async {
    try {
      final box = await HiveManager().getBox(outfitsBoxName);

      // Generate an ID if one doesn't exist
      if (outfit.id == null || outfit.id!.isEmpty) {
        outfit.id = uuid.v4();
        debugPrint('Generated new ID for outfit: ${outfit.id}');
      }

      // Save using the ID as the key
      await box.put(outfit.id, outfit);
      debugPrint('Saved outfit with ID: ${outfit.id}, Name: ${outfit.name}');
    } catch (e) {
      debugPrint('Error saving outfit: $e');
      rethrow;
    }
  }

  /// Get all saved outfits
  static Future<List<Outfit>> getAllOutfits() async {
    try {
      final box = await HiveManager().getBox(outfitsBoxName);
      final outfits = <Outfit>[];

      debugPrint('Loading all outfits. Total in box: ${box.length}');

      for (final key in box.keys) {
        try {
          final outfit = box.get(key);
          if (outfit != null && outfit is Outfit) {
            // Ensure the outfit has an ID
            if (outfit.id == null || outfit.id!.isEmpty) {
              outfit.id = key.toString();
              await box.put(key, outfit);
              debugPrint('Fixed missing ID for outfit: ${outfit.name}');
            }
            outfits.add(outfit);
          }
        } catch (e) {
          debugPrint('Error loading outfit with key $key: $e');
        }
      }

      return outfits;
    } catch (e) {
      debugPrint('Error getting all outfits: $e');
      return [];
    }
  }

  /// Get a specific outfit by ID
  static Future<Outfit?> getOutfit(String id) async {
    try {
      final box = await HiveManager().getBox(outfitsBoxName);
      return box.get(id) as Outfit?;
    } catch (e) {
      debugPrint('Error getting outfit with ID $id: $e');
      return null;
    }
  }

  /// Delete an outfit
  static Future<void> deleteOutfit(String id) async {
    try {
      final box = await HiveManager().getBox(outfitsBoxName);
      await box.delete(id);
      debugPrint('Deleted outfit with ID: $id');
    } catch (e) {
      debugPrint('Error deleting outfit with ID $id: $e');
    }
  }

  /// Update an existing outfit
  static Future<void> updateOutfit(Outfit outfit) async {
    try {
      // Validate the outfit ID
      if (outfit.id == null || outfit.id!.isEmpty) {
        debugPrint('ERROR: No ID found for outfit "${outfit.name}" - cannot update');
        throw Exception('Cannot update outfit without an ID');
      }

      // Simply save the outfit - this will overwrite the existing one
      await saveOutfit(outfit);

    } catch (e) {
      debugPrint('Error updating outfit: $e');
      rethrow;
    }
  }
}
