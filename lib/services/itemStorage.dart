import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/item.dart';
import 'package:uuid/uuid.dart';
import 'hiveServiceManager.dart';
import 'package:drobe/auth/authService.dart';

class ItemStorageService {
  static const String itemsBoxName = 'itemsBox';
  static final uuid = Uuid();
  static bool _initialized = false;

  /// Initialize the service
  static Future<void> init() async {
    if (_initialized) {
      debugPrint('ItemStorageService already initialized, skipping');
      return;
    }

    try {
      debugPrint('Initializing ItemStorageService...');

      // Make sure HiveManager is initialized
      await HiveManager().init();

      // Register the Item adapter if it's not already registered
      if (!Hive.isAdapterRegistered(0)) {
        try {
          Hive.registerAdapter(ItemAdapter());
          debugPrint('Registered ItemAdapter with typeId 0');
        } catch (e) {
          debugPrint('Error registering ItemAdapter: $e');
          // Continue even if registration fails - it might be already registered
        }
      }

      // Open the items box
      final box = await HiveManager().getBox(itemsBoxName);

      // Migrate existing items to include userId
      await _migrateItemsToIncludeUserId(box);

      _initialized = true;
      debugPrint('ItemStorageService initialized successfully');

      // Log the number of items
      final items = await getAllItems();
      debugPrint('Loading all items. Total in box: ${items.length}');
    } catch (e) {
      debugPrint('Error initializing ItemStorageService: $e');
    }
  }

  /// Migrate existing items to include userId
  static Future<void> _migrateItemsToIncludeUserId(Box box) async {
    try {
      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Cannot migrate items: No current user ID available');
        return;
      }

      debugPrint('Starting item migration for user $currentUserId');

      // Get all items that don't have a userId
      int migratedCount = 0;

      for (final key in box.keys) {
        try {
          final item = box.get(key);
          if (item is Item && (item.userId == null || item.userId!.isEmpty)) {
            // Create a copy with the user ID
            final updatedItem = item.copyWith(userId: currentUserId);

            // Save the updated item
            await box.put(key, updatedItem);
            migratedCount++;

            debugPrint('Migrated item ${item.id} to user $currentUserId');
          }
        } catch (e) {
          debugPrint('Error migrating item with key $key: $e');
        }
      }

      debugPrint('Item migration completed. Migrated $migratedCount items.');
    } catch (e) {
      debugPrint('Error migrating items: $e');
    }
  }

  /// Save an item
  static Future<Item> saveItem(Item item) async {
    try {
      // Make sure we're initialized
      if (!_initialized) {
        await init();
      }

      final box = await HiveManager().getBox(itemsBoxName);

      // Generate an ID if one doesn't exist
      if (item.id.isEmpty) {
        final generatedId = uuid.v4();
        item = item.copyWith(id: generatedId);
        debugPrint('Generated new ID for item: ${item.id}');
      }

      // Get the current user ID and set it on the item
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available when saving item');
        throw Exception('Cannot save item: No current user ID available');
      }

      // Always set the userId to the current user
      item = item.copyWith(userId: currentUserId);
      debugPrint('Set userId $currentUserId for item ${item.id}');

      // Save the item
      await box.put(item.id, item);
      debugPrint('Saved item with ID: ${item.id}, Name: ${item.name}, User: ${item.userId}');

      return item;
    } catch (e) {
      debugPrint('Error saving item: $e');
      rethrow;
    }
  }

  /// Get all items for the current user
  static Future<List<Item>> getAllItems({String? category}) async {
    try {
      // Make sure we're initialized
      if (!_initialized) {
        await init();
      }

      final box = await HiveManager().getBox(itemsBoxName);
      final items = <Item>[];

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available, returning empty item list');
        return [];
      }

      debugPrint('Loading items for user: $currentUserId. Total in box: ${box.length}');

      // Log all items in the box for debugging
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is Item) {
          debugPrint('Found item: ID=${value.id}, Name=${value.name}, UserID=${value.userId}');
        }
      }

      for (final key in box.keys) {
        try {
          final value = box.get(key);
          if (value is Item) {
            // Only include items that belong to the current user
            if (value.userId == currentUserId) {
              items.add(value);
            }
          }
        } catch (e) {
          debugPrint('Error loading item with key $key: $e');
        }
      }

      // Filter by category if provided
      if (category != null && category.isNotEmpty) {
        final filteredItems = items.where((item) =>
        item.category.toLowerCase() == category.toLowerCase()
        ).toList();

        debugPrint('Loaded ${filteredItems.length} items for user $currentUserId in category $category');
        return filteredItems;
      }

      debugPrint('Loaded ${items.length} items for user $currentUserId');
      return items;
    } catch (e) {
      debugPrint('Error getting all items: $e');
      return [];
    }
  }

  /// Get a specific item by ID
  static Future<Item?> getItem(String id) async {
    try {
      // Make sure we're initialized
      if (!_initialized) {
        await init();
      }

      final box = await HiveManager().getBox(itemsBoxName);
      final item = box.get(id) as Item?;

      if (item == null) {
        return null;
      }

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available when getting item');
        return null;
      }

      // Only return the item if it belongs to the current user
      if (item.userId == currentUserId) {
        return item;
      }

      debugPrint('Cannot access item: It belongs to another user');
      return null;
    } catch (e) {
      debugPrint('Error getting item with ID $id: $e');
      return null;
    }
  }

  /// Delete an item
  static Future<void> deleteItem(String id) async {
    try {
      // Make sure we're initialized
      if (!_initialized) {
        await init();
      }

      final box = await HiveManager().getBox(itemsBoxName);
      final item = box.get(id) as Item?;

      if (item == null) {
        debugPrint('Item with ID $id not found');
        return;
      }

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Cannot delete item: No current user ID available');
        return;
      }

      // Only delete the item if it belongs to the current user
      if (item.userId == currentUserId) {
        await box.delete(id);
        debugPrint('Deleted item with ID: $id');
      } else {
        debugPrint('Cannot delete item: It belongs to another user');
      }
    } catch (e) {
      debugPrint('Error deleting item with ID $id: $e');
    }
  }

  /// Update an existing item
  static Future<Item> updateItem(Item item) async {
    try {
      // Make sure we're initialized
      if (!_initialized) {
        await init();
      }

      // Validate the item ID
      if (item.id.isEmpty) {
        debugPrint('ERROR: No ID found for item "${item.name}" - cannot update');
        throw Exception('Cannot update item without an ID');
      }

      final box = await HiveManager().getBox(itemsBoxName);

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Cannot update item: No current user ID available');
        throw Exception('Cannot update item: No current user ID available');
      }

      // Check if the item exists before updating
      final existingItem = box.get(item.id) as Item?;

      if (existingItem == null) {
        debugPrint('WARNING: Item with ID ${item.id} not found in box. Creating new entry.');
        // This is a new item, so set the userId
        item = item.copyWith(userId: currentUserId);
      } else {
        // Verify the item belongs to the current user
        if (existingItem.userId != currentUserId) {
          debugPrint('Cannot update item: It belongs to another user');
          throw Exception('Cannot update item: It belongs to another user');
        }

        // Preserve the userId
        item = item.copyWith(userId: currentUserId);
      }

      // Put the updated item with the same ID
      await box.put(item.id, item);
      debugPrint('Successfully updated item with ID: ${item.id}, Name: ${item.name}, User: ${item.userId}');

      return item;
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }
}

