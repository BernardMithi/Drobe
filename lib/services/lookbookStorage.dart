// lib/services/lookbookStorage.dart
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/lookbookItem.dart';
import 'package:uuid/uuid.dart';
import 'hiveServiceManager.dart';
import 'package:drobe/auth/authService.dart';

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
      final box = await HiveManager().getBox(lookbookBoxName);

      // Migrate existing lookbook items to include userId
      await _migrateLookbookItemsToIncludeUserId(box);

      _initialized = true;
      debugPrint('LookbookStorageService initialized successfully');

      // Log the number of lookbook items
      final items = await getAllItems();
      debugPrint('Loading all lookbook items. Total in box: ${items.length}');
    } catch (e) {
      debugPrint('Error initializing LookbookStorageService: $e');
    }
  }

  /// Migrate existing lookbook items to include userId
  static Future<void> _migrateLookbookItemsToIncludeUserId(Box box) async {
    try {
      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Cannot migrate lookbook items: No current user ID available');
        return;
      }

      // Get all lookbook items that don't have a userId
      final itemsToMigrate = <String, LookbookItem>{};

      for (final key in box.keys) {
        final item = box.get(key);
        if (item is LookbookItem && (item.userId == null || item.userId!.isEmpty)) {
          itemsToMigrate[key.toString()] = item;
        }
      }

      debugPrint('Found ${itemsToMigrate.length} lookbook items to migrate');

      // Update each lookbook item with the current user's ID
      for (final entry in itemsToMigrate.entries) {
        final key = entry.key;
        final item = entry.value;

        final updatedItem = item.copyWith(userId: currentUserId);
        await box.put(key, updatedItem);
        debugPrint('Migrated lookbook item ${item.id} to user $currentUserId');
      }

      debugPrint('Lookbook item migration completed');
    } catch (e) {
      debugPrint('Error migrating lookbook items: $e');
    }
  }

// Modify the saveItem method to set the userId
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

      // Get the current user ID and set it on the item
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available when saving lookbook item');
      } else {
        // Always set the userId to the current user
        item = item.copyWith(userId: currentUserId);
        debugPrint('Set userId $currentUserId for lookbook item ${item.id}');
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

      debugPrint('Successfully saved lookbook item with ID: ${item.id}, Name: ${item.name}, User: ${item.userId}');

      // Return the saved lookbook item with its ID
      return savedItem;
    } catch (e) {
      debugPrint('Error saving lookbook item: $e');
      rethrow;
    }
  }

// Modify the getAllItems method to filter by userId
  static Future<List<LookbookItem>> getAllItems() async {
    try {
      final box = await HiveManager().getBox(lookbookBoxName);
      final items = <LookbookItem>[];

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available, returning empty lookbook item list');
        return [];
      }

      debugPrint('Loading lookbook items for user: $currentUserId. Total in box: ${box.length}');

      for (final key in box.keys) {
        try {
          final item = box.get(key);
          if (item != null && item is LookbookItem) {
            // Only include items that belong to the current user
            if (item.userId == currentUserId) {
              // Ensure the item has an ID
              if (item.id == null || item.id!.isEmpty) {
                item.id = key.toString();
                await box.put(key, item);
                debugPrint('Fixed missing ID for lookbook item: ${item.name}');
              }

              items.add(item);
            }
          }
        } catch (e) {
          debugPrint('Error loading lookbook item with key $key: $e');
        }
      }

      debugPrint('Loaded ${items.length} lookbook items for user $currentUserId');
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
      final item = box.get(id) as LookbookItem?;

      if (item == null) {
        return null;
      }

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available when getting lookbook item');
        return null;
      }

      // Only return the item if it belongs to the current user or has no userId (legacy item)
      if (item.userId == null || item.userId!.isEmpty || item.userId == currentUserId) {
        // If the item has no userId, assign the current user's ID
        if (item.userId == null || item.userId!.isEmpty) {
          item.userId = currentUserId;
          await box.put(id, item);
          debugPrint('Assigned userId $currentUserId to lookbook item: ${item.name}');
        }

        return item;
      }

      debugPrint('Cannot access lookbook item: It belongs to another user');
      return null;
    } catch (e) {
      debugPrint('Error getting lookbook item with ID $id: $e');
      return null;
    }
  }

  /// Delete a lookbook item
  static Future<void> deleteItem(String id) async {
    try {
      final box = await HiveManager().getBox(lookbookBoxName);
      final item = box.get(id) as LookbookItem?;

      if (item == null) {
        debugPrint('Lookbook item with ID $id not found');
        return;
      }

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Cannot delete lookbook item: No current user ID available');
        return;
      }

      // Only delete the item if it belongs to the current user or has no userId (legacy item)
      if (item.userId == null || item.userId!.isEmpty || item.userId == currentUserId) {
        await box.delete(id);
        debugPrint('Deleted lookbook item with ID: $id');
      } else {
        debugPrint('Cannot delete lookbook item: It belongs to another user');
      }
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

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Cannot update lookbook item: No current user ID available');
        throw Exception('Cannot update lookbook item: No current user ID available');
      }

      // Check if the item exists before updating
      final existingItem = box.get(item.id) as LookbookItem?;

      if (existingItem == null) {
        debugPrint('WARNING: Lookbook item with ID ${item.id} not found in box. Creating new entry.');
        // This is a new item, so set the userId
        item = item.copyWith(userId: currentUserId);
      } else {
        // Verify the item belongs to the current user
        if (existingItem.userId != null && existingItem.userId!.isNotEmpty && existingItem.userId != currentUserId) {
          debugPrint('Cannot update lookbook item: It belongs to another user');
          throw Exception('Cannot update lookbook item: It belongs to another user');
        }

        // Preserve the userId if it exists, otherwise set it
        if (item.userId == null || item.userId!.isEmpty) {
          item = item.copyWith(userId: currentUserId);
        }
      }

      // Put the updated item with the same ID
      await box.put(item.id, item);

      // Verify the update worked by retrieving the item
      final updatedItem = box.get(item.id) as LookbookItem?;

      if (updatedItem == null) {
        debugPrint('ERROR: Failed to retrieve updated lookbook item with ID: ${item.id}');
        throw Exception('Failed to update lookbook item: ${item.name}');
      }

      debugPrint('Successfully updated lookbook item with ID: ${item.id}, Name: ${item.name}, User: ${item.userId}');

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

