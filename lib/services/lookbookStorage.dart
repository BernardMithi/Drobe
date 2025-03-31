// lib/services/lookbookStorage.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/lookbookItem.dart';
import 'package:uuid/uuid.dart';
import 'hiveServiceManager.dart';

class LookbookStorageService {
  static const String lookbookBoxName = 'lookbookItems';
  static final uuid = Uuid();
  static bool _initialized = false;

  /// Initialize the service
  static Future<void> init() async {
    if (_initialized) {
      debugPrint('LookbookStorageService already initialized, skipping');
      return;
    }

    try {
      debugPrint('Initializing LookbookStorageService...');

      // Make sure HiveManager is initialized
      await HiveManager().init();

      // Register the LookbookItem adapter if it's not already registered
      if (!Hive.isAdapterRegistered(2)) {
        try {
          Hive.registerAdapter(LookbookItemAdapter());
          debugPrint('Registered LookbookItemAdapter with typeId 2');
        } catch (e) {
          debugPrint('Error registering LookbookItemAdapter: $e');
          // Continue even if registration fails - it might be already registered
        }
      }

      // Open the lookbook box
      await HiveManager().getBox(lookbookBoxName);

      _initialized = true;
      debugPrint('LookbookStorageService initialized successfully');

      // Log the number of lookbook items
      final items = await getAllItems();
      debugPrint('Loading all lookbook items. Total in box: ${items.length}');
    } catch (e) {
      debugPrint('Error initializing LookbookStorageService: $e');
    }
  }

  /// Save a lookbook item to storage
  static Future<LookbookItem> saveItem(LookbookItem item) async {
    try {
      final box = await HiveManager().getBox(lookbookBoxName);

      // Generate an ID if one doesn't exist
      if (item.id == null || item.id!.isEmpty) {
        final generatedId = uuid.v4();
        item = item.copyWith(id: generatedId);
        debugPrint('Generated new ID for lookbook item: ${item.id}');
      } else {
        // If ID exists, check if we're overwriting an existing item
        if (box.containsKey(item.id)) {
          debugPrint('Overwriting existing lookbook item with ID: ${item.id}');
        }
      }

      // Verify the ID is set before saving
      if (item.id == null || item.id!.isEmpty) {
        debugPrint('ERROR: Lookbook item ID is still null or empty after generation attempt!');
        throw Exception('Failed to generate a valid ID for lookbook item');
      }

      // Save using the ID as the key
      await box.put(item.id, item);

      // Verify the save worked by retrieving the item
      final savedItem = box.get(item.id) as LookbookItem?;

      if (savedItem == null) {
        debugPrint('ERROR: Failed to retrieve saved lookbook item with ID: ${item.id}');
        throw Exception('Failed to save lookbook item: ${item.name}');
      }

      debugPrint('Successfully saved lookbook item with ID: ${item.id}, Name: ${item.name}');

      // Return the saved lookbook item with its ID
      return savedItem;
    } catch (e) {
      debugPrint('Error saving lookbook item: $e');
      rethrow;
    }
  }

  /// Get all saved lookbook items
  static Future<List<LookbookItem>> getAllItems() async {
    try {
      final box = await HiveManager().getBox(lookbookBoxName);
      final items = <LookbookItem>[];

      debugPrint('Loading all lookbook items. Total in box: ${box.length}');

      for (final key in box.keys) {
        try {
          final item = box.get(key);
          if (item != null && item is LookbookItem) {
            // Ensure the item has an ID
            if (item.id == null || item.id!.isEmpty) {
              item.id = key.toString();
              await box.put(key, item);
              debugPrint('Fixed missing ID for lookbook item: ${item.name}');
            }
            items.add(item);
          }
        } catch (e) {
          debugPrint('Error loading lookbook item with key $key: $e');
        }
      }

      return items;
    } catch (e) {
      debugPrint('Error getting all lookbook items: $e');
      return [];
    }
  }

  /// Get a specific lookbook item by ID
  static Future<LookbookItem?> getItem(String id) async {
    try {
      final box = await HiveManager().getBox(lookbookBoxName);
      return box.get(id) as LookbookItem?;
    } catch (e) {
      debugPrint('Error getting lookbook item with ID $id: $e');
      return null;
    }
  }

  /// Delete a lookbook item
  static Future<void> deleteItem(String id) async {
    try {
      final box = await HiveManager().getBox(lookbookBoxName);
      await box.delete(id);
      debugPrint('Deleted lookbook item with ID: $id');
    } catch (e) {
      debugPrint('Error deleting lookbook item with ID $id: $e');
    }
  }

  /// Update an existing lookbook item
  static Future<LookbookItem> updateItem(LookbookItem item) async {
    try {
      // Validate the item ID
      if (item.id == null || item.id!.isEmpty) {
        debugPrint('ERROR: No ID found for lookbook item "${item.name}" - cannot update');
        throw Exception('Cannot update lookbook item without an ID');
      }

      final box = await HiveManager().getBox(lookbookBoxName);

      // Check if the item exists before updating
      if (!box.containsKey(item.id)) {
        debugPrint('WARNING: Lookbook item with ID ${item.id} not found in box. Creating new entry.');
      }

      // Put the updated item with the same ID
      await box.put(item.id, item);

      // Verify the update worked by retrieving the item
      final updatedItem = box.get(item.id) as LookbookItem?;

      if (updatedItem == null) {
        debugPrint('ERROR: Failed to retrieve updated lookbook item with ID: ${item.id}');
        throw Exception('Failed to update lookbook item: ${item.name}');
      }

      debugPrint('Successfully updated lookbook item with ID: ${item.id}, Name: ${item.name}');

      // Return the updated lookbook item
      return updatedItem;
    } catch (e) {
      debugPrint('Error updating lookbook item: $e');
      rethrow;
    }
  }

  /// Get lookbook items by tag
  static Future<List<LookbookItem>> getItemsByTag(String tag) async {
    try {
      final allItems = await getAllItems();
      return allItems.where((item) => item.tags.contains(tag.toLowerCase())).toList();
    } catch (e) {
      debugPrint('Error getting lookbook items by tag $tag: $e');
      return [];
    }
  }

  /// Get all unique tags
  static Future<List<String>> getAllTags() async {
    try {
      final allItems = await getAllItems();
      final Set<String> tags = {};

      for (final item in allItems) {
        tags.addAll(item.tags);
      }

      return tags.toList()..sort();
    } catch (e) {
      debugPrint('Error getting all tags: $e');
      return [];
    }
  }
}

