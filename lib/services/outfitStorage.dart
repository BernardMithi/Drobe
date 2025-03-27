// lib/services/outfit_storage_service.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/outfit.dart';
import 'package:uuid/uuid.dart';

class OutfitStorageService {
  static const String outfitsBoxName = 'outfits';
  static const String legacyOutfitsBoxName = 'outfits';
  static final uuid = Uuid();
  static bool _migrationCompleted = false;

  /// Initialize Hive and register adapters
  static Future<void> init() async {
    if (!Hive.isBoxOpen(outfitsBoxName)) {
      await Hive.openBox<Outfit>(outfitsBoxName);
    }

    // Perform migration if needed
    if (!_migrationCompleted) {
      await _migrateDataIfNeeded();
      _migrationCompleted = true;
    }
  }

  /// Migrate data from the old format to the new format if needed
  static Future<void> _migrateDataIfNeeded() async {
    try {
      // Check if we have data in the legacy box
      final legacyBox = await Hive.openBox<Outfit>(legacyOutfitsBoxName);

      if (legacyBox.isNotEmpty) {
        print('Found ${legacyBox.length} outfits in legacy format. Migrating...');

        // Get all outfits from the legacy box
        final legacyOutfits = legacyBox.values.toList();

        // Save each outfit to ensure it has a proper ID
        for (final outfit in legacyOutfits) {
          if (outfit.id == null || outfit.id!.isEmpty) {
            outfit.id = uuid.v4();
          }

          // Save the outfit with its ID as the key
          await legacyBox.put(outfit.id, outfit);
          print('Migrated outfit with ID: ${outfit.id}, Name: ${outfit.name}');
        }
      }
    } catch (e) {
      print('Error during migration: $e');
    }
  }

  /// Save an outfit to storage
  static Future<void> saveOutfit(Outfit outfit) async {
    final box = await Hive.openBox<Outfit>(outfitsBoxName);

    // Generate an ID if one doesn't exist
    if (outfit.id == null || outfit.id!.isEmpty) {
      outfit.id = uuid.v4();
      print('Generated new ID for outfit: ${outfit.id}');
    }

    // Check if an outfit with this ID already exists
    final existingOutfit = box.get(outfit.id);
    if (existingOutfit != null) {
      print('WARNING: Outfit with ID ${outfit.id} already exists. Deleting first.');
      await box.delete(outfit.id);
    }

    // Save using the ID as the key
    await box.put(outfit.id, outfit);
    print('Saved outfit with ID: ${outfit.id}, Name: ${outfit.name}');
  }

  /// Get all saved outfits
  static Future<List<Outfit>> getAllOutfits() async {
    final box = await Hive.openBox<Outfit>(outfitsBoxName);
    final outfits = <Outfit>[];

    print('Loading all outfits. Total in box: ${box.length}');

    for (final key in box.keys) {
      try {
        final outfit = box.get(key);
        if (outfit != null) {
          // Ensure the outfit has an ID
          if (outfit.id == null || outfit.id!.isEmpty) {
            outfit.id = key.toString();
            await box.put(key, outfit);
            print('Fixed missing ID for outfit: ${outfit.name}');
          }
          outfits.add(outfit);
          print('Loaded outfit - ID: ${outfit.id}, Name: ${outfit.name}');
        }
      } catch (e) {
        print('Error loading outfit with key $key: $e');
      }
    }

    // Check for duplicates
    final names = <String>[];
    final duplicates = <String>[];
    for (final outfit in outfits) {
      if (names.contains(outfit.name)) {
        duplicates.add(outfit.name);
      } else {
        names.add(outfit.name);
      }
    }

    if (duplicates.isNotEmpty) {
      print('WARNING: Found duplicate outfit names: $duplicates');
    }

    return outfits;
  }

  /// Get a specific outfit by ID
  static Future<Outfit?> getOutfit(String id) async {
    final box = await Hive.openBox<Outfit>(outfitsBoxName);
    return box.get(id);
  }

  /// Delete an outfit
  static Future<void> deleteOutfit(String id) async {
    final box = await Hive.openBox<Outfit>(outfitsBoxName);
    await box.delete(id);
    print('Deleted outfit with ID: $id');
  }

  /// Update an existing outfit
  static Future<void> updateOutfit(Outfit outfit) async {
    // Validate the outfit ID
    if (outfit.id == null || outfit.id!.isEmpty) {
      print('ERROR: No ID found for outfit "${outfit.name}" - cannot update');
      throw Exception('Cannot update outfit without an ID');
    }

    final box = await Hive.openBox<Outfit>(outfitsBoxName);

    // Debug: List all outfit IDs in the box
    print('All outfit IDs in box before update: ${box.keys.toList()}');
    print('Updating outfit - ID: ${outfit.id}, Name: ${outfit.name}');

    try {
      // CRITICAL: First check if the outfit exists
      final existingOutfit = box.get(outfit.id);

      if (existingOutfit != null) {
        print('Found existing outfit with ID ${outfit.id}, Name: ${existingOutfit.name}');

        // Delete the existing outfit first to avoid any caching issues
        await box.delete(outfit.id);
        print('Deleted existing outfit with ID: ${outfit.id}');
      } else {
        print('No existing outfit found with ID: ${outfit.id}');
      }

      // Now save the updated outfit
      await box.put(outfit.id, outfit);
      print('Successfully saved updated outfit - ID: ${outfit.id}, Name: ${outfit.name}');

      // Verify the update worked
      final updatedOutfit = box.get(outfit.id);
      if (updatedOutfit != null) {
        print('Verified outfit in storage - ID: ${updatedOutfit.id}, Name: ${updatedOutfit.name}');
      } else {
        print('ERROR: Could not verify outfit with ID ${outfit.id} after update');
        throw Exception('Failed to verify outfit update');
      }
    } catch (e) {
      print('Error updating outfit: $e');
      rethrow;
    }
  }
}

