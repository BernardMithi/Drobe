// lib/services/hive_manager.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drobe/models/item.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Define constant box names
const String ITEMS_BOX_NAME = 'itemsBox';

class HiveManager {
  static final HiveManager _instance = HiveManager._internal();
  factory HiveManager() => _instance;
  HiveManager._internal();

  bool _initialized = false;
  final Map<String, Box> _boxes = {};

  // Initialize Hive once at app startup
  Future<void> init() async {
    if (_initialized) return;

    // Initialize Hive
    await Hive.initFlutter();

    // Register all your adapters
    if (!Hive.isAdapterRegistered(0)) {  // ItemAdapter's typeId
      Hive.registerAdapter(ItemAdapter());
    }

    _initialized = true;
  }

  // Get a box with safety checks
  Future<Box> getBox(String boxName) async {
    // Make sure Hive is initialized
    await init();

    // Return cached box if it exists
    if (_boxes.containsKey(boxName)) {
      return _boxes[boxName]!;
    }

    // Open the box if it's not cached
    Box box;
    if (Hive.isBoxOpen(boxName)) {
      box = Hive.box(boxName);
    } else {
      box = await Hive.openBox(boxName);
    }

    _boxes[boxName] = box;
    return box;
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
    final box = await getBox(boxName);
    await box.clear();
  }

  // Get typed item from box safely
  Item? getTypedItem(dynamic boxItem) {
    if (boxItem is Item) {
      return boxItem;
    }
    return null;
  }
}