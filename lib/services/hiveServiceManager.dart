import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/models/outfit.dart';
import 'package:drobe/models/lookbookItem.dart';

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

  // Initialize Hive
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('HiveManager already initialized');
      return;
    }

    try {
      debugPrint('Initializing HiveManager...');

      // Initialize Hive
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDir.path);
      await Hive.initFlutter();

      // Register adapters
      _registerAdapters();

      _isInitialized = true;
      debugPrint('HiveManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing HiveManager: $e');
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

      // If not, open it
      final box = await Hive.openBox(boxName);
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
    final box = await getBox(boxName);
    await box.clear();
    debugPrint('Cleared box: $boxName');
  }

  // Clear all boxes
  Future<void> clearAllData() async {
    try {
      await Hive.deleteFromDisk();
      _boxes.clear();
      _isInitialized = false;
      debugPrint('Cleared all Hive data');
    } catch (e) {
      debugPrint('Error clearing Hive data: $e');
      rethrow;
    }
  }
}

