// lib/services/outfit_storage_service.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/outfit.dart';
import 'package:uuid/uuid.dart';

class OutfitStorageService {
  static const String outfitsBoxName = 'outfits';
  static final uuid = Uuid();

  /// Initialize Hive and register adapters
  static Future<void> init() async {
    if (!Hive.isBoxOpen(outfitsBoxName)) {
      await Hive.openBox<Outfit>(outfitsBoxName);
    }

  }

  /// Save an outfit to storage
  static Future<void> saveOutfit(Outfit outfit) async {
    final box = await Hive.openBox<Outfit>(outfitsBoxName);

    // Generate an ID if one doesn't exist
    if (outfit.id == null || outfit.id!.isEmpty) {
      outfit.id = uuid.v4();
    }

    // Save using the ID as the key for easier retrieval later
    await box.put(outfit.id, outfit);
  }

  /// Get all saved outfits
  static Future<List<Outfit>> getAllOutfits() async {
    final box = await Hive.openBox<Outfit>(outfitsBoxName);
    return box.values.toList();
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
  }

  /// Update an existing outfit
  static Future<void> updateOutfit(Outfit outfit) async {
    if (outfit.id == null) {
      throw Exception("Cannot update outfit without an ID");
    }
    final box = await Hive.openBox<Outfit>(outfitsBoxName);
    await box.put(outfit.id, outfit);
  }
}