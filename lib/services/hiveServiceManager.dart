// lib/services/hiveServiceManager.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/models/outfit.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Define constant box names
const String ITEMS_BOX_NAME = 'itemsBox';
const String OUTFITS_BOX_NAME = 'outfits';

class HiveManager {
  static final HiveManager _instance = HiveManager._internal();
  factory HiveManager() => _instance;
  HiveManager._internal();

  bool _initialized = false;
  final Map<String, Box> _boxes = {};

  // Initialize Hive once at app startup
  Future<void> init() async {
    if (_initialized) {
      debugPrint('HiveManager already initialized, skipping');
      return;
    }

    try {
      debugPrint('Initializing HiveManager...');

      // Initialize Hive
      await Hive.initFlutter();

      // Register all adapters in the correct order
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ItemAdapter());
        debugPrint('Registered ItemAdapter with typeId 0');
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(OutfitAdapter());
        debugPrint('Registered OutfitAdapter with typeId 1');
      }

      _initialized = true;
      debugPrint('HiveManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing HiveManager: $e');
      rethrow;
    }
  }

  // Get a box with safety checks
  Future<Box> getBox(String boxName) async {
    // Make sure Hive is initialized
    await init();

    try {
      // Return cached box if it exists and is open
      if (_boxes.containsKey(boxName) && _boxes[boxName]!.isOpen) {
        return _boxes[boxName]!;
      }

      // Open the box if it's not cached or not open
      Box box;
      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box(boxName);
      } else {
        box = await Hive.openBox(boxName);
      }

      _boxes[boxName] = box;
      return box;
    } catch (e) {
      debugPrint('Error opening box $boxName: $e');

      // If there was an error, try to recover by deleting and reopening the box
      await _recoverBox(boxName);

      // Try again after recovery
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box(boxName);
      } else {
        return await Hive.openBox(boxName);
      }
    }
  }

  // Recover a corrupted box
  Future<void> _recoverBox(String boxName) async {
    debugPrint('Attempting to recover corrupted box: $boxName');

    try {
      // Close the box if it's open
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }

      // Get the application documents directory
      final appDir = await getApplicationDocumentsDirectory();

      // Delete the box file
      final boxFile = File('${appDir.path}/$boxName.hive');
      if (await boxFile.exists()) {
        await boxFile.delete();
        debugPrint('Deleted corrupted box file: ${boxFile.path}');
      }

      // Delete the box lock file
      final lockFile = File('${appDir.path}/$boxName.lock');
      if (await lockFile.exists()) {
        await lockFile.delete();
        debugPrint('Deleted box lock file: ${lockFile.path}');
      }

      // Remove from cache
      _boxes.remove(boxName);

    } catch (e) {
      debugPrint('Error during box recovery: $e');
    }
  }

  // Close all boxes - useful for cleanup
  Future<void> closeBoxes() async {
    for (var boxName in _boxes.keys) {
      final box = _boxes[boxName];
      if (box != null && box.isOpen) {
        await box.close();
      }
    }
    _boxes.clear();
  }

  // Force clear the box's contents (use carefully)
  Future<void> clearBox(String boxName) async {
    try {
      final box = await getBox(boxName);
      await box.clear();
      debugPrint('Cleared box: $boxName');
    } catch (e) {
      debugPrint('Error clearing box $boxName: $e');
    }
  }

  // Safely clear all Hive data
  Future<void> clearAllData() async {
    debugPrint('Clearing all Hive data...');

    try {
      // Close all open boxes first
      await closeBoxes();

      // Get the application documents directory
      final appDir = await getApplicationDocumentsDirectory();

      // Find and delete all .hive and .lock files
      final files = await appDir.list().toList();
      for (final entity in files) {
        if (entity is File &&
            (entity.path.endsWith('.hive') || entity.path.endsWith('.lock'))) {
          await entity.delete();
          debugPrint('Deleted Hive file: ${entity.path}');
        }
      }

      // Reset initialization flag to force re-initialization
      _initialized = false;

      debugPrint('All Hive data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing Hive data: $e');
    }
  }

  // Get typed item from box safely
  T? getTypedItem<T>(dynamic boxItem) {
    if (boxItem is T) {
      return boxItem;
    }
    return null;
  }
}
