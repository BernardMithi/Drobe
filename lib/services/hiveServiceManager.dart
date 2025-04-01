import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/models/outfit.dart';
import 'package:drobe/models/lookbookItem.dart';
import 'package:drobe/auth/authService.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HiveManager {
  // Singleton pattern
  static final HiveManager _instance = HiveManager._internal();
  factory HiveManager() => _instance;
  HiveManager._internal();

  // State
  bool _isInitialized = false;
  final Map<String, Box> _boxes = {};

  // Getters
  bool get isInitialized => _isInitialized;

  // Initialize Hive with timeout
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('HiveManager already initialized');
      return;
    }

    try {
      debugPrint('Initializing HiveManager...');

      // Initialize Hive with a timeout
      await _initializeWithTimeout();

      _isInitialized = true;
      debugPrint('HiveManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing HiveManager: $e');
      // Don't rethrow, just log the error and continue
      _isInitialized = true; // Mark as initialized anyway to prevent further attempts
    }
  }

  // Initialize with timeout to prevent hanging
  Future<void> _initializeWithTimeout() async {
    try {
      // Initialize Hive with a timeout
      await Future.wait([
        _doInitialize(),
      ]).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('HiveManager initialization timed out, continuing anyway');
        return [null];
      });
    } catch (e) {
      debugPrint('Error in _initializeWithTimeout: $e');
      // Continue anyway
    }
  }

  // Actual initialization logic
  Future<void> _doInitialize() async {
    try {
      // Initialize Hive
      //final appDocumentDir = await getApplicationDocumentsDirectory();
      //Hive.init(appDocumentDir.path);
      await Hive.initFlutter();

      // Register adapters
      _registerAdapters();

      debugPrint('Basic Hive initialization completed');
    } catch (e) {
      debugPrint('Error in _doInitialize: $e');
      rethrow;
    }
  }

  // Register all adapters
  void _registerAdapters() {
    try {
      // Register Item adapter if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ItemAdapter());
        debugPrint('Registered ItemAdapter with typeId 0');
      }

      // Register Outfit adapter if not already registered
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(OutfitAdapter());
        debugPrint('Registered OutfitAdapter with typeId 1');
      }

      // Register LookbookItem adapter if not already registered
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(LookbookItemAdapter());
        debugPrint('Registered LookbookItemAdapter with typeId 2');
      }
    } catch (e) {
      debugPrint('Error registering adapters: $e');
      // Continue even if registration fails - adapters might be already registered
    }
  }

  // Get a box, opening it if necessary
  Future<Box> getBox(String boxName) async {
    if (!_isInitialized) {
      await init();
    }

    // First check if we already have the box in our map
    if (_boxes.containsKey(boxName) && _boxes[boxName]!.isOpen) {
      return _boxes[boxName]!;
    }

    try {
      // Check if the box is already open by Hive
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        _boxes[boxName] = box;
        debugPrint('Retrieved already open box: $boxName');
        return box;
      }

      // If not, open it with a timeout
      final box = await Hive.openBox(boxName).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Opening box $boxName timed out, creating empty box');
          throw TimeoutException('Box opening timed out');
        },
      );

      _boxes[boxName] = box;
      debugPrint('Opened box: $boxName');
      return box;
    } catch (e) {
      debugPrint('Error opening box $boxName: $e');

      try {
        // Try to recover by deleting the box and reopening it
        await Hive.deleteBoxFromDisk(boxName);
        final box = await Hive.openBox(boxName);
        _boxes[boxName] = box;
        debugPrint('Recovered box: $boxName');
        return box;
      } catch (recoveryError) {
        debugPrint('Failed to recover box $boxName: $recoveryError');
        // If recovery fails, create an empty box as a last resort
        final box = await Hive.openBox('temp_$boxName');
        _boxes[boxName] = box;
        debugPrint('Created temporary box for: $boxName');
        return box;
      }
    }
  }

  // Close a specific box
  Future<void> closeBox(String boxName) async {
    if (_boxes.containsKey(boxName) && _boxes[boxName]!.isOpen) {
      await _boxes[boxName]!.close();
      _boxes.remove(boxName);
      debugPrint('Closed box: $boxName');
    }
  }

  // Close all boxes
  Future<void> closeAllBoxes() async {
    for (final boxName in _boxes.keys.toList()) {
      if (_boxes[boxName]!.isOpen) {
        await _boxes[boxName]!.close();
        debugPrint('Closed box: $boxName');
      }
    }
    _boxes.clear();
  }

  // Clear a specific box
  Future<void> clearBox(String boxName) async {
    try {
      final box = await getBox(boxName);
      await box.clear();
      debugPrint('Cleared box: $boxName');
    } catch (e) {
      debugPrint('Error clearing box $boxName: $e');
      // Try to delete and recreate the box if clearing fails
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await getBox(boxName); // This will create a new empty box
        debugPrint('Deleted and recreated box: $boxName');
      } catch (deleteError) {
        debugPrint('Error deleting box $boxName: $deleteError');
        // Continue anyway
      }
    }
  }

  // IMPROVED: Clear all boxes with more robust implementation
  Future<void> clearAllData({bool clearUserAuth = false}) async {
    debugPrint('Starting clearAllData operation...');

    try {
      // Close all open boxes first
      await closeAllBoxes();

      // List of all box names used in the app
      final List<String> boxNames = [
        'itemsBox',
        'outfitsBox',
        'lookbookItemsBox',
        'laundryItemsBox',
        'userPreferencesBox',
      ];

      // Add auth box if requested
      if (clearUserAuth) {
        boxNames.add('usersBox');
        boxNames.add('authBox'); // Add any other auth-related boxes
      }

      debugPrint('Attempting to clear boxes: $boxNames');

      // Method 1: Try to clear each box individually
      for (final boxName in boxNames) {
        try {
          debugPrint('Clearing box: $boxName');
          await clearBox(boxName);
        } catch (e) {
          debugPrint('Error clearing box $boxName: $e');
          // Continue with other boxes
        }
      }

      // Method 2: As a fallback, try to delete all Hive data
      try {
        debugPrint('Attempting to delete all Hive data from disk...');
        await Hive.deleteFromDisk();
        debugPrint('Successfully deleted all Hive data from disk');

        // Reinitialize Hive after deleting everything
        await Hive.initFlutter();
        _registerAdapters();
        _isInitialized = false; // Force reinitialization on next use

      } catch (e) {
        debugPrint('Error deleting all Hive data: $e');

        // Method 3: Last resort - manually delete Hive directory
        try {
          final directory = await getApplicationDocumentsDirectory();
          final hivePath = '${directory.path}/hive';
          final hiveDir = Directory(hivePath);

          if (await hiveDir.exists()) {
            debugPrint('Manually deleting Hive directory: $hivePath');
            await hiveDir.delete(recursive: true);
            debugPrint('Successfully deleted Hive directory');

            // Reinitialize Hive after manual deletion
            await Hive.initFlutter();
            _registerAdapters();
          }
        } catch (dirError) {
          debugPrint('Error manually deleting Hive directory: $dirError');
        }
      }

      // Clear our internal box cache
      _boxes.clear();

      debugPrint('clearAllData operation completed');
    } catch (e) {
      debugPrint('Unexpected error in clearAllData: $e');
      rethrow;
    }
  }

  // Add a method to ensure a user ID exists before performing operations
  Future<String?> ensureUserIdAvailable() async {
    try {
      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('Warning: No current user ID available');
        return null;
      }

      return currentUserId;
    } catch (e) {
      debugPrint('Error ensuring user ID is available: $e');
      return null;
    }
  }

  // Get all items for the current user and category
  Future<List<Item>> getUserItems({String? category}) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      final box = await getBox('itemsBox');

      // Get the current user ID
      final currentUserId = await ensureUserIdAvailable();

      if (currentUserId == null || currentUserId!.isEmpty) {
        debugPrint('Warning: No current user ID available, returning empty item list');
        return [];
      }

      // Get all items
      final allItems = box.values.whereType<Item>().toList();
      debugPrint('Found ${allItems.length} total items in box');

      // Filter by user ID - ONLY include items that explicitly match the current user ID
      var items = allItems.where((item) =>
      item.userId == currentUserId
      ).toList();

      debugPrint('Found ${items.length} items for user $currentUserId');

      // Filter by category if provided
      if (category != null && category.isNotEmpty) {
        items = items.where((item) =>
        item.category.toLowerCase() == category.toLowerCase()
        ).toList();

        debugPrint('Found ${items.length} items in category $category');
      }

      return items;
    } catch (e) {
      debugPrint('Error getting user items: $e');
      return [];
    }
  }

  // Save an item
  Future<void> saveItem(Item item) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      final box = await getBox('itemsBox');

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('Cannot save item: No current user ID available');
      }

      // Set the userId to the current user
      final itemWithUserId = item.copyWith(userId: currentUserId);

      // Save the item
      await box.add(itemWithUserId);

      debugPrint('Saved item with ID: ${itemWithUserId.id}, Name: ${itemWithUserId.name}, User: $currentUserId');
    } catch (e) {
      debugPrint('Error saving item: $e');
      rethrow;
    }
  }

  // Update an item
  Future<void> updateItem(Item item) async {
    try {
      final box = await getBox('itemsBox');

      // Log the update operation
      debugPrint('Updating item with ID: ${item.id}');

      // Find the item by ID and update it
      final Map<dynamic, dynamic> boxMap = box.toMap();
      dynamic keyToUpdate;

      for (var entry in boxMap.entries) {
        if (entry.value is Item && (entry.value as Item).id == item.id) {
          keyToUpdate = entry.key;
          break;
        }
      }

      if (keyToUpdate != null) {
        await box.put(keyToUpdate, item);
        debugPrint('Item updated successfully');
      } else {
        // If item not found, add it
        await box.add(item);
        debugPrint('Item not found for update, added as new item');
      }
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  // Enhanced updateItem method with robust error handling and logging
  // Renamed to updateItemWithFields to avoid conflict
  Future<bool> updateItemWithFields(String boxName, String itemId, Map<String, dynamic> updates) async {
    try {
      debugPrint('HiveServiceManager: Updating item with ID: $itemId');
      debugPrint('HiveServiceManager: Updates: $updates');

      final box = await getBox(boxName);

      // Find the item by ID
      dynamic foundItem;
      dynamic foundKey;

      for (var key in box.keys) {
        final item = box.get(key);
        if (item != null && item.id == itemId) {
          foundItem = item;
          foundKey = key;
          break;
        }
      }

      if (foundItem == null) {
        debugPrint('HiveServiceManager: ERROR - Item with ID $itemId not found in box $boxName');
        return false;
      }

      debugPrint('HiveServiceManager: Found item at key: $foundKey');

      // Apply all updates to the item
      updates.forEach((key, value) {
        if (value != null) {
          try {
            foundItem[key] = value;
            debugPrint('HiveServiceManager: Updated $key to $value');
          } catch (e) {
            debugPrint('HiveServiceManager: Error updating field $key: $e');
          }
        }
      });

      // Save the updated item back to the box
      await box.put(foundKey, foundItem);
      debugPrint('HiveServiceManager: Successfully saved updated item to box');

      return true;
    } catch (e, stackTrace) {
      debugPrint('HiveServiceManager: Error updating item: $e');
      debugPrint('HiveServiceManager: Stack trace: $stackTrace');
      return false;
    }
  }

  // Delete an item
  Future<void> deleteItem(String itemId) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      final box = await getBox('itemsBox');

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      final currentUserId = userData['id'];

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('Cannot delete item: No current user ID available');
      }

      // Find the key for this item
      dynamic key;
      try {
        key = box.keys.firstWhere(
              (k) {
            final value = box.get(k);
            return value is Item && value.id == itemId;
          },
          orElse: () => null,
        );
      } catch (e) {
        debugPrint('Error finding key for item $itemId: $e');
        throw Exception('Item not found with ID: $itemId');
      }

      if (key != null) {
        // Verify the item belongs to the current user
        final existingItem = box.get(key) as Item;
        if (existingItem.userId != null && existingItem.userId != currentUserId) {
          throw Exception('Cannot delete item: It belongs to another user');
        }

        await box.delete(key);
        debugPrint('Deleted item with ID: $itemId');
      } else {
        throw Exception('Item not found with ID: $itemId');
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  Future<void> initHive() async {
    await Hive.initFlutter();
  }
}

