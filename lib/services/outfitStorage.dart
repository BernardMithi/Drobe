// lib/services/outfitStorage.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/outfit.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:drobe/services/hiveServiceManager.dart';

class OutfitStorageService {
  static const String outfitsBoxName = 'outfits';
  static final uuid = Uuid();
  static bool _migrationCompleted = false;
  static bool _isInitialized = false;

  /// Initialize Hive and register adapters
  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('OutfitStorageService already initialized');
      return;
    }

    try {
      // Make sure HiveManager is initialized first
      await HiveManager().init();

      // Use HiveManager to get the box instead of opening it directly
      await HiveManager().getBox(outfitsBoxName);

      _isInitialized = true;
      debugPrint('OutfitStorageService initialized successfully');

      // Perform migration if needed
      if (!_migrationCompleted) {
        await _migrateDataIfNeeded();
        _migrationCompleted = true;
      }

      // Debug: Count outfits after initialization
      final outfits = await getAllOutfits();
      debugPrint('Found ${outfits.length} outfits after initialization');
    } catch (e) {
      debugPrint('Error initializing OutfitStorageService: $e');
    }
  }

  /// Migrate data from the old format to the new format if needed
  static Future<void> _migrateDataIfNeeded() async {
    try {
      // Use HiveManager to get the box
      final box = await HiveManager().getBox(outfitsBoxName);

      debugPrint('Checking for outfits to migrate. Box has ${box.length} items.');

      if (box.isNotEmpty) {
        // Get all keys and values
        final keys = box.keys.toList();

        for (final key in keys) {
          try {
            final dynamic value = box.get(key);

            // Check if this is an outfit
            if (value is Outfit) {
              final outfit = value;

              // Ensure it has an ID
              if (outfit.id == null || outfit.id!.isEmpty) {
                outfit.id = key.toString();
                if (key is String) {
                  // If the key is already a string, use it as is
                  outfit.id = key;
                } else {
                  // Otherwise generate a new UUID
                  outfit.id = uuid.v4();
                }

                // Save the outfit with its ID as the key
                await box.put(outfit.id, outfit);
                debugPrint('Migrated outfit: ${outfit.name} with ID: ${outfit.id}');
              }
            } else if (value != null) {
              debugPrint('Found non-outfit item with key $key: ${value.runtimeType}');
            }
          } catch (e) {
            debugPrint('Error processing item with key $key: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error during migration: $e');
    }
  }

  /// Save an outfit to storage
  static Future<Outfit> saveOutfit(Outfit outfit) async {
    try {
      // Make sure we're initialized
      if (!_isInitialized) {
        await init();
      }

      // Use HiveManager to get the box
      final box = await HiveManager().getBox(outfitsBoxName);

      // Generate an ID if one doesn't exist
      if (outfit.id == null || outfit.id!.isEmpty) {
        outfit.id = uuid.v4();
        debugPrint('Generated new ID for outfit: ${outfit.id}');
      }

      // Save using the ID as the key
      await box.put(outfit.id, outfit);
      debugPrint('Saved outfit with ID: ${outfit.id}, Name: ${outfit.name}');

      // Verify the save worked
      final savedOutfit = box.get(outfit.id);
      if (savedOutfit == null) {
        debugPrint('WARNING: Failed to verify outfit save for ID: ${outfit.id}');
      }

      return outfit;
    } catch (e) {
      debugPrint('Error saving outfit: $e');
      // If there's an error, try to reinitialize and save again
      _isInitialized = false;
      await init();

      // Try one more time
      final box = await HiveManager().getBox(outfitsBoxName);
      await box.put(outfit.id ?? uuid.v4(), outfit);

      return outfit;
    }
  }

  /// Get all saved outfits
  static Future<List<Outfit>> getAllOutfits() async {
    try {
      // Make sure we're initialized
      if (!_isInitialized) {
        await init();
      }

      // Use HiveManager to get the box
      final box = await HiveManager().getBox(outfitsBoxName);
      final outfits = <Outfit>[];

      debugPrint('Loading all outfits. Total in box: ${box.length}');

      // Get all keys
      final keys = box.keys.toList();

      for (final key in keys) {
        try {
          final dynamic value = box.get(key);

          if (value is Outfit) {
            final outfit = value;

            // Ensure the outfit has an ID
            if (outfit.id == null || outfit.id!.isEmpty) {
              outfit.id = key.toString();
              await box.put(key, outfit);
              debugPrint('Fixed missing ID for outfit: ${outfit.name}');
            }

            outfits.add(outfit);
            debugPrint('Loaded outfit - ID: ${outfit.id}, Name: ${outfit.name}');
          } else if (value != null) {
            debugPrint('Found non-outfit item with key $key: ${value.runtimeType}');
          }
        } catch (e) {
          debugPrint('Error loading outfit with key $key: $e');
        }
      }

      return outfits;
    } catch (e) {
      debugPrint('Error loading outfits: $e');
      return [];
    }
  }

  /// Get a specific outfit by ID
  static Future<Outfit?> getOutfit(String id) async {
    try {
      // Make sure we're initialized
      if (!_isInitialized) {
        await init();
      }

      // Use HiveManager to get the box
      final box = await HiveManager().getBox(outfitsBoxName);
      final dynamic value = box.get(id);

      if (value is Outfit) {
        return value;
      } else if (value != null) {
        debugPrint('Found non-outfit item with ID $id: ${value.runtimeType}');
      }

      return null;
    } catch (e) {
      debugPrint('Error getting outfit with ID $id: $e');
      return null;
    }
  }

  /// Delete an outfit
  static Future<void> deleteOutfit(String id) async {
    try {
      // Make sure we're initialized
      if (!_isInitialized) {
        await init();
      }

      // Use HiveManager to get the box
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

      // Make sure we're initialized
      if (!_isInitialized) {
        await init();
      }

      // Use HiveManager to get the box
      final box = await HiveManager().getBox(outfitsBoxName);

      // Debug: List all outfit IDs in the box
      debugPrint('All keys in box before update: ${box.keys.toList()}');
      debugPrint('Updating outfit - ID: ${outfit.id}, Name: ${outfit.name}');

      // Save the updated outfit
      await box.put(outfit.id, outfit);
      debugPrint('Successfully saved updated outfit - ID: ${outfit.id}, Name: ${outfit.name}');

      // Verify the update worked
      final dynamic updatedValue = box.get(outfit.id);
      if (updatedValue is Outfit) {
        debugPrint('Verified outfit in storage - ID: ${updatedValue.id}, Name: ${updatedValue.name}');
      } else if (updatedValue != null) {
        debugPrint('WARNING: Saved value is not an Outfit: ${updatedValue.runtimeType}');
      } else {
        debugPrint('ERROR: Could not verify outfit with ID ${outfit.id} after update');
        throw Exception('Failed to verify outfit update');
      }
    } catch (e) {
      debugPrint('Error updating outfit: $e');
      rethrow;
    }
  }
}

